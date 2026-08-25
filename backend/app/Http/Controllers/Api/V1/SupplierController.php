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
        ]);

        if (auth()->check()) {
            $validated['created_by'] = auth()->id();
        }

        $supplier = Supplier::create($validated);

        return response()->json([
            'message' => 'سەپڵایەر بە سەرکەوتوویی زیادکرا',
            'data' => $supplier
        ], 201);
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
        $supplier = Supplier::findOrFail($id);

        $validated = $request->validate([
            'amount' => 'required|numeric|min:1',
            'payment_method' => 'nullable|string|in:cash,bank,transfer',
            'notes' => 'nullable|string',
        ]);

        return DB::transaction(function () use ($supplier, $validated, $request) {
            $user = auth()->user() ?? User::first();
            $userId = $user ? $user->id : 1;

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
                'amount' => $validated['amount'],
                'balance_after' => $newBalance,
                'reference_type' => 'supplier_payment',
                'reference_id' => $payment->id,
                'description' => $validated['notes'] ?? 'تۆمارکردنی پارەدانی قەرز',
                'created_by' => $userId,
            ]);

            return response()->json([
                'message' => 'پارەدان بە سەرکەوتوویی تۆمارکرا',
                'data' => $supplier->append('debt')
            ]);
        });
    }
}
