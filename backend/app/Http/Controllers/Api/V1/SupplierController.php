<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Supplier;
use App\Models\SupplierPayment;
use App\Models\SupplierLedger;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class SupplierController extends Controller
{
    public function index(): JsonResponse
    {
        $suppliers = Supplier::all();
        return response()->json([
            'message' => 'لیستی سەپڵایەرەکان',
            'data' => $suppliers
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => [
                'required', 
                'string', 
                'max:255', 
                Rule::unique('suppliers')->whereNull('deleted_at')
            ],
            'phone' => 'nullable|string|max:20',
            'address' => 'nullable|string|max:255',
            'contact_person' => 'nullable|string|max:255',
            'initial_debt' => 'nullable|numeric|min:0',
        ]);

        if (auth()->check()) {
            $validated['created_by'] = auth()->id();
        }

        return DB::transaction(function () use ($validated) {
            $supplier = Supplier::create([
                'name' => $validated['name'],
                'phone' => $validated['phone'],
                'address' => $validated['address'],
                'contact_person' => $validated['contact_person'],
                'current_balance' => $validated['initial_debt'] ?? 0,
                'created_by' => $validated['created_by'] ?? 1,
            ]);

            if (!empty($validated['initial_debt']) && $validated['initial_debt'] > 0) {
                SupplierLedger::create([
                    'supplier_id' => $supplier->id,
                    'entry_type' => 'ADJUSTMENT',
                    'type' => 'credit',
                    'credit' => $validated['initial_debt'],
                    'debit' => 0,
                    'amount' => $validated['initial_debt'],
                    'balance_before' => 0,
                    'balance_after' => $validated['initial_debt'],
                    'reference_type' => 'supplier',
                    'reference_id' => $supplier->id,
                    'description' => 'قەرزی سەرەتا',
                    'created_by' => $validated['created_by'] ?? 1,
                ]);
            }

            return response()->json([
                'message' => 'سەپڵایەر بە سەرکەوتوویی زیادکرا',
                'data' => $supplier->append('debt')
            ], 201);
        });
    }

    
    public function show($id): JsonResponse
    {
        $supplier = Supplier::findOrFail($id);
        return response()->json([
            'message' => 'وردەکاری دابینکەر',
            'data' => $supplier
        ]);
    }

    public function update(Request $request, $id): JsonResponse
    {
        $supplier = Supplier::findOrFail($id);

        $validated = $request->validate([
            'name' => [
                'required', 
                'string', 
                'max:255', 
                Rule::unique('suppliers')->ignore($id)->whereNull('deleted_at')
            ],
            'phone' => 'nullable|string|max:20',
            'address' => 'nullable|string|max:255',
            'contact_person' => 'nullable|string|max:255',
        ]);

        $supplier->update($validated);

        return response()->json([
            'message' => 'سەپڵایەر بە سەرکەوتوویی نوێکرایەوە',
            'data' => $supplier
        ]);
    }

    public function destroy($id): JsonResponse
    {
        $supplier = Supplier::findOrFail($id);
        $supplier->delete();

        return response()->json([
            'message' => 'سەپڵایەر بە سەرکەوتوویی سڕدرایەوە'
        ]);
    }

    public function pay(Request $request, $id): JsonResponse
    {
        $validated = $request->validate([
            'amount' => 'required|integer|min:1',
            'payment_method' => 'nullable|string|in:cash,bank,transfer',
            'notes' => 'nullable|string',
            'purchase_order_id' => 'nullable|integer|exists:purchase_orders,id',
        ]);

        if (!empty($validated['purchase_order_id'])) {
            $po = \App\Models\PurchaseOrder::find($validated['purchase_order_id']);
            if (!$po || $po->supplier_id != $id) {
                throw \Illuminate\Validation\ValidationException::withMessages([
                    'purchase_order_id' => ['دیاریکراوی پسوڵەی دابینکەر نادروستە / Purchase order does not belong to supplier'],
                ]);
            }
        }

        return DB::transaction(function () use ($id, $validated) {
            $supplier = Supplier::lockForUpdate()->findOrFail($id);
            $user = auth()->user() ?? User::first();
            $userId = $user ? $user->id : 1;
            $previousBalance = (int) $supplier->current_balance;
            $paymentAmount = (int) $validated['amount'];

            // Overpayment Protection: cannot pay more than total outstanding supplier debt
            if ($paymentAmount > $previousBalance) {
                throw \Illuminate\Validation\ValidationException::withMessages([
                    'amount' => ['بڕی پارەدان زیاترە لە کۆی قەرزی دابینکەر / Payment amount exceeds supplier outstanding debt'],
                ]);
            }

            // If linked to a purchase order, enforce remaining order balance check
            if (!empty($validated['purchase_order_id'])) {
                $po = \App\Models\PurchaseOrder::lockForUpdate()->find($validated['purchase_order_id']);
                if (!$po || $po->supplier_id != $supplier->id) {
                    throw \Illuminate\Validation\ValidationException::withMessages([
                        'purchase_order_id' => ['دیاریکراوی پسوڵەی دابینکەر نادروستە / Purchase order does not belong to supplier'],
                    ]);
                }

                $totalPaidForPo = (int) SupplierPayment::where('purchase_order_id', $po->id)->sum('amount');
                $poTotal = (int) $po->total_amount;
                $poRemaining = max(0, $poTotal - $totalPaidForPo);

                if ($paymentAmount > $poRemaining) {
                    throw \Illuminate\Validation\ValidationException::withMessages([
                        'amount' => ['بڕی پارەدان زیاترە لە قەرزی ماوەی ئەم پسوڵەی کڕینە / Payment amount exceeds remaining purchase order balance'],
                    ]);
                }
            }

            $payment = SupplierPayment::create([
                'supplier_id' => $supplier->id,
                'purchase_order_id' => $validated['purchase_order_id'] ?? null,
                'amount' => $paymentAmount,
                'payment_method' => $validated['payment_method'] ?? 'cash',
                'paid_at' => now()->toDateString(),
                'notes' => $validated['notes'] ?? null,
                'created_by' => $userId,
            ]);

            $newBalance = $previousBalance - $paymentAmount;

            SupplierLedger::create([
                'supplier_id' => $supplier->id,
                'entry_type' => 'PAYMENT',
                'type' => 'debit',
                'debit' => $paymentAmount,
                'credit' => 0,
                'amount' => $paymentAmount,
                'balance_before' => $previousBalance,
                'balance_after' => $newBalance,
                'reference_type' => 'supplier_payment',
                'reference_id' => $payment->id,
                'description' => $validated['notes'] ?? 'تۆمارکردنی پارەدانی قەرز',
                'created_by' => $userId,
            ]);

            // نوێکردنەوەی بالانسی سەپڵایەر لە داتابەیسدا
            $supplier->update(['current_balance' => $newBalance]);

            // Write audit trail log
            app(\App\Services\AuditService::class)->log([
                'action'      => 'SUPPLIER_PAYMENT',
                'entity_type' => 'SupplierPayment',
                'entity_id'   => $payment->id,
                'table_name'  => 'supplier_payments',
                'old_values'  => [
                    'supplier_balance' => $previousBalance,
                ],
                'new_values'  => [
                    'supplier_id'      => $supplier->id,
                    'supplier_name'    => $supplier->name,
                    'amount'           => $payment->amount,
                    'payment_method'   => $payment->payment_method,
                    'supplier_balance' => $newBalance,
                ],
                'description' => "پارەدانی دابینکەر تۆمارکرا بە بڕی {$payment->amount} بۆ {$supplier->name}",
                'user'        => $user,
            ]);

            return response()->json([
                'message' => 'پارەدان بە سەرکەوتوویی تۆمارکرا',
                'data' => $supplier->append('debt')
            ], 200);
        });
    }

    public function ledger($id): JsonResponse
    {
        $supplier = Supplier::findOrFail($id);
        $ledger = SupplierLedger::where('supplier_id', $supplier->id)
            ->orderByDesc('id')
            ->get();

        return response()->json([
            'message' => 'مێژووی قەرز و پارەدانی سەپڵایەر',
            'data' => $ledger
        ]);
    }

    public function reconcile(Request $request, $id): JsonResponse
    {
        $supplier = Supplier::findOrFail($id);

        if ($request->boolean('fix') && auth()->user() && auth()->user()->isAdmin()) {
            DB::transaction(function () use ($supplier) {
                $supplier->lockForUpdate();
                $reconciliation = $supplier->reconcileBalance();
                if (!$reconciliation['is_consistent']) {
                    $supplier->update(['current_balance' => $reconciliation['recalculated_balance']]);
                }
            });
            $supplier->refresh();
        }

        $reconciliation = $supplier->reconcileBalance();

        return response()->json([
            'message' => 'سەپڵایەر لێکترازانی دارایی / Reconciliation report',
            'data' => $reconciliation
        ]);
    }
}
