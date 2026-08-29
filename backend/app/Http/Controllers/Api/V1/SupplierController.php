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

    private function checkSupplierPaymentIdempotency(int $supplierId, int $amount): ?SupplierPayment
    {
        return SupplierPayment::where('supplier_id', $supplierId)
            ->where('amount', $amount)
            ->where('created_at', '>=', now()->subSeconds(90))
            ->orderBy('id', 'desc')
            ->first();
    }

    public function pay(Request $request, $id): JsonResponse
    {
        $validated = $request->validate([
            'amount' => 'required|numeric|min:1',
            'payment_method' => 'nullable|string|in:cash,bank,transfer',
            'notes' => 'nullable|string',
        ]);

        return DB::transaction(function () use ($id, $validated) {
            $supplier = Supplier::lockForUpdate()->findOrFail($id);
            $user = auth()->user() ?? User::first();
            $userId = $user ? $user->id : 1;

            // Check for duplicate payment request (Idempotency)
            $existingPayment = $this->checkSupplierPaymentIdempotency($supplier->id, $validated['amount']);
            if ($existingPayment) {
                return response()->json([
                    'message' => 'پارەدان بە سەرکەوتوویی تۆمارکرا (دووبارەبوونەوەی پاراستن)',
                    'data' => $supplier->append('debt')
                ], 200);
            }

            $payment = SupplierPayment::create([
                'supplier_id' => $supplier->id,
                'amount' => $validated['amount'],
                'payment_method' => $validated['payment_method'] ?? 'cash',
                'paid_at' => now()->toDateString(),
                'notes' => $validated['notes'] ?? null,
                'created_by' => $userId,
            ]);

            $lastLedger = SupplierLedger::where('supplier_id', $supplier->id)->orderByDesc('id')->first();
            $previousBalance = $lastLedger ? $lastLedger->balance_after : 0;
            $newBalance = $previousBalance - $validated['amount'];

            SupplierLedger::create([
                'supplier_id' => $supplier->id,
                'entry_type' => 'PAYMENT',
                'type' => 'debit',
                'debit' => $validated['amount'],
                'credit' => 0,
                'amount' => $validated['amount'],
                'balance_before' => $previousBalance,
                'balance_after' => $newBalance,
                'reference_type' => 'supplier_payment',
                'reference_id' => $payment->id,
                'description' => $validated['notes'] ?? 'تۆمارکردنی پارەدانی قەرز',
                'created_by' => $userId,
            ]);

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
            ]);
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

    public function reconcile($id): JsonResponse
    {
        $supplier = Supplier::findOrFail($id);
        $reconciliation = $supplier->reconcileBalance();

        return response()->json([
            'message' => 'سەپڵایەر لێکترازانی دارایی / Reconciliation report',
            'data' => $reconciliation
        ]);
    }
}
