<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Warehouse;
use App\Models\WarehouseStock;
use App\Models\StockTransaction;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class WarehouseController extends Controller
{
    public function index(): JsonResponse
    {
        $warehouses = Warehouse::where('is_active', true)->get();

        if ($warehouses->isEmpty()) {
            $mainWarehouse = Warehouse::create([
                'name' => 'کۆگای سەرەکی',
                'is_main' => true,
                'is_active' => true,
            ]);
            $warehouses = collect([$mainWarehouse]);
        }

        return response()->json([
            'message' => 'لیستی کۆگاکان',
            'data' => $warehouses
        ]);
    }

    public function adjustStock(Request $request, $warehouseId, $productId): JsonResponse
    {
        $validated = $request->validate([
            'quantity_change' => 'required|integer',
            'type' => 'required|string|in:ADJUSTMENT,RETURN,PURCHASE,DELIVERY',
            'notes' => 'nullable|string|max:255',
        ]);

        // Idempotency check: 15-second submission window for identical manual adjustments
        $existing = StockTransaction::where('warehouse_id', $warehouseId)
            ->where('product_id', $productId)
            ->where('type', strtoupper($validated['type']))
            ->where('quantity_change', $validated['quantity_change'])
            ->where('notes', $validated['notes'] ?? null)
            ->where('created_at', '>=', now()->subSeconds(15))
            ->first();

        if ($existing) {
            return response()->json([
                'message' => 'ئەم گۆڕانکارییە پێشتر تۆمارکراوە (Idempotency Hit)',
                'data' => $existing
            ], 200);
        }

        $stock = WarehouseStock::where('warehouse_id', $warehouseId)
            ->where('product_id', $productId)
            ->first();

        if (!$stock) {
            $stock = WarehouseStock::create([
                'warehouse_id' => $warehouseId,
                'product_id' => $productId,
                'quantity' => 0,
                'reserved_quantity' => 0
            ]);
        }

        try {
            $transaction = $stock->adjustStock(
                $validated['quantity_change'],
                $validated['type'],
                $request->user()->id,
                'manual_adjustment',
                null,
                $validated['notes'] ?? 'Manual stock adjustment'
            );

            return response()->json([
                'message' => 'ستۆک بە سەرکەوتوویی دەستکاری کرا',
                'data' => $transaction
            ], 200);
        } catch (\Exception $e) {
            return response()->json([
                'message' => $e->getMessage()
            ], 400);
        }
    }

    public function reconcileStock($warehouseId, $productId): JsonResponse
    {
        $stock = WarehouseStock::where('warehouse_id', $warehouseId)
            ->where('product_id', $productId)
            ->firstOrFail();

        $result = $stock->reconcile();

        return response()->json([
            'message' => 'ئەنجامی سەرلەنوێ هاوتاکردنەوەی ستۆک',
            'data' => $result
        ]);
    }
}
