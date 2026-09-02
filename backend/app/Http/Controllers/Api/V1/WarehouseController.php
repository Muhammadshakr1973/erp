<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Warehouse;
use App\Models\WarehouseStock;
use App\Models\StockTransaction;
use App\Models\SalesOrder;
use App\Models\SalesOrderItem;
use App\Services\SalesOrderService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class WarehouseController extends Controller
{
    protected SalesOrderService $salesOrderService;

    public function __construct(SalesOrderService $salesOrderService)
    {
        $this->salesOrderService = $salesOrderService;
    }

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $query = Warehouse::where('is_active', true);

        if ($user && $user->warehouse_id) {
            $query->where('id', $user->warehouse_id);
        }

        $warehouses = $query->get();

        if ($warehouses->isEmpty() && (!$user || !$user->warehouse_id)) {
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
        $user = $request->user();
        if ($user && $user->warehouse_id && $warehouseId != $user->warehouse_id) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ دەستکاری ستۆک لەم کۆگایەدا.'
            ], 403);
        }

        $validated = $request->validate([
            'quantity_change' => 'required|integer',
            'type' => 'nullable|string|in:ADJUSTMENT,adjustment',
            'notes' => 'nullable|string|max:255',
        ]);

        $type = 'ADJUSTMENT';

        $hasTrueIdempotency = $request->hasHeader('X-Idempotency-Key') || $request->hasHeader('Idempotency-Key');

        if (!$hasTrueIdempotency) {
            // Idempotency check: 15-second submission window for identical unkeyed manual adjustments
            $existingQuery = StockTransaction::where('warehouse_id', $warehouseId)
                ->where('product_id', $productId)
                ->where('type', $type)
                ->where('quantity_change', $validated['quantity_change'])
                ->where('created_at', '>=', now()->subSeconds(15)->toDateTimeString());

            if (isset($validated['notes']) && $validated['notes'] !== '') {
                $existingQuery->where('notes', $validated['notes']);
            } else {
                $existingQuery->where(function ($q) {
                    $q->whereNull('notes')->orWhere('notes', '')->orWhere('notes', 'Manual stock adjustment');
                });
            }

            $existing = $existingQuery->first();

            if ($existing) {
                return response()->json([
                    'message' => 'ئەم گۆڕانکارییە پێشتر تۆمارکراوە (Idempotency Hit)',
                    'data' => $existing
                ], 200);
            }
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
                $type,
                $user->id,
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

    public function reconcileStock(Request $request, $warehouseId, $productId): JsonResponse
    {
        $user = $request->user();
        if ($user && $user->warehouse_id && $warehouseId != $user->warehouse_id) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ سەرلەنوێ هاوتاکردنەوەی ستۆک لەم کۆگایەدا.'
            ], 403);
        }

        $stock = WarehouseStock::where('warehouse_id', $warehouseId)
            ->where('product_id', $productId)
            ->firstOrFail();

        $result = $stock->reconcile();

        return response()->json([
            'message' => 'ئەنجامی سەرلەنوێ هاوتاکردنەوەی ستۆک',
            'data' => $result
        ]);
    }

    public function ordersToPack(Request $request): JsonResponse
    {
        $user = $request->user();
        $query = SalesOrder::with(['customer', 'warehouse', 'items.product'])
            ->whereIn('status', [SalesOrder::STATUS_CONFIRMED, SalesOrder::STATUS_PACKING]);

        if ($user && $user->warehouse_id) {
            $query->where('warehouse_id', $user->warehouse_id);
        }

        $orders = $query->orderBy('id', 'desc')->get();

        return response()->json([
            'message' => 'لیستی پسوڵەکانی پاکەتکردن',
            'data' => $orders
        ]);
    }

    public function packItem(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'order_item_id' => 'required|integer|exists:sales_order_items,id',
            'packed' => 'required|boolean',
        ]);

        $item = SalesOrderItem::findOrFail($validated['order_item_id']);
        $order = $item->order;

        if (!$order) {
            return response()->json([
                'message' => 'پسوڵە نەدۆزرایەوە.'
            ], 404);
        }

        $user = $request->user();

        // Check if user is restricted to a warehouse
        if ($user && $user->warehouse_id && $order->warehouse_id !== $user->warehouse_id) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ دەستکاریکردنی ئەم پسوڵەیە چونکە سەر بە کۆگایەکی ترە.'
            ], 403);
        }

        // Check if status is CONFIRMED or PACKING
        if ($order->status !== SalesOrder::STATUS_PACKING) {
            return response()->json([
                'message' => 'تەنها پسوڵەی پشتڕاستکراوە یان لە حاڵەتی پاکەتکردن دەتوانرێت دەستکاری بکرێت.'
            ], 400);
        }

        $packed = $validated['packed'];

        // Idempotency: if already matching requested value, return early
        if ($item->is_packed === $packed) {
            return response()->json([
                'message' => 'کردارەکە پێشتر جێبەجێ کراوە',
                'data' => $order->load(['customer', 'warehouse', 'items.product'])
            ], 200);
        }

        try {
            DB::transaction(function () use ($item, $order, $packed, $user) {
                // If the order status was CONFIRMED, transition to PACKING
                if ($order->status === SalesOrder::STATUS_CONFIRMED) {
                    $this->salesOrderService->transitionTo($order, SalesOrder::STATUS_PACKING, $user);
                }

                if ($packed) {
                    // Check physical stock in correct warehouse
                    $warehouseStock = WarehouseStock::lockForUpdate()->where([
                        'warehouse_id' => $order->warehouse_id,
                        'product_id' => $item->product_id
                    ])->first();

                    if (!$warehouseStock || $warehouseStock->quantity < $item->quantity) {
                        $available = $warehouseStock ? $warehouseStock->quantity : 0;
                        throw ValidationException::withMessages([
                            'order_item_id' => "بڕی پێویست لە کۆگادا بەردەست نییە بۆ پاکەتکردن. بڕی داواکراو: {$item->quantity}، بڕی بەردەست لە کۆگا: {$available}"
                        ]);
                    }

                    $item->is_packed = true;
                    $item->packed_at = now();
                    $item->packed_by = $user->id;
                } else {
                    $item->is_packed = false;
                    $item->packed_at = null;
                    $item->packed_by = null;
                }

                $item->save();

                // Log audit trail
                app(\App\Services\AuditService::class)->log([
                    'action'      => 'PACK_ITEM',
                    'entity_type' => 'SalesOrderItem',
                    'entity_id'   => $item->id,
                    'table_name'  => 'sales_order_items',
                    'old_values'  => [
                        'is_packed' => !$packed,
                    ],
                    'new_values'  => [
                        'order_number' => $order->order_number,
                        'product_id'   => $item->product_id,
                        'is_packed'    => $item->is_packed,
                        'packed_by'    => $user->name,
                    ],
                    'description' => $packed ? "کاڵای پسوڵەی {$order->order_number} پاکەت کرا" : "کاڵای پسوڵەی {$order->order_number} لە پاکەتکردن لادرا",
                    'user'        => $user,
                ]);
            });

            return response()->json([
                'message' => $packed ? 'کاڵاکە بە سەرکەوتوویی پاکەت کرا' : 'کاڵاکە لە پاکەتکردن لادرا',
                'data' => $order->fresh(['customer', 'warehouse', 'items.product'])
            ]);
        } catch (ValidationException $ve) {
            return response()->json([
                'message' => $ve->getMessage(),
                'errors' => $ve->errors()
            ], 422);
        } catch (\Exception $e) {
            return response()->json([
                'message' => $e->getMessage()
            ], 400);
        }
    }

    public function markReady(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'order_id' => 'required|integer|exists:sales_orders,id',
        ]);

        $order = SalesOrder::findOrFail($validated['order_id']);
        $user = $request->user();

        // Check if user is restricted to a warehouse
        if ($user && $user->warehouse_id && $order->warehouse_id !== $user->warehouse_id) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ دەستکاریکردنی ئەم پسوڵەیە چونکە سەر بە کۆگایەکی ترە.'
            ], 403);
        }

        if ($order->status !== SalesOrder::STATUS_PACKING) {
            return response()->json([
                'message' => 'تەنها پسوڵەی لە حاڵەتی پاکەتکردن دەکرێت بە ئامادەکراو بنرێت.'
            ], 400);
        }

        try {
            $updatedOrder = $this->salesOrderService->transitionTo($order, SalesOrder::STATUS_READY, $user);

            return response()->json([
                'message' => 'پسوڵە بە سەرکەوتوویی بە ئامادەکراو تۆمارکرا',
                'data' => $updatedOrder->load(['customer', 'warehouse', 'items.product'])
            ]);
        } catch (ValidationException $ve) {
            return response()->json([
                'message' => $ve->getMessage(),
                'errors' => $ve->errors()
            ], 422);
        } catch (\Exception $e) {
            return response()->json([
                'message' => $e->getMessage()
            ], 400);
        }
    }

    public function stockList(Request $request): JsonResponse
    {
        $user = $request->user();
        $query = WarehouseStock::with(['warehouse', 'product']);

        if ($user && $user->warehouse_id) {
            $query->where('warehouse_id', $user->warehouse_id);
        } elseif ($request->has('warehouse_id')) {
            $query->where('warehouse_id', $request->query('warehouse_id'));
        }

        if ($request->has('product_id')) {
            $query->where('product_id', $request->query('product_id'));
        }

        $stocks = $query->get();

        return response()->json([
            'message' => 'لیستی ستۆکی کۆگاکان',
            'data' => $stocks
        ]);
    }

    public function transactions(Request $request): JsonResponse
    {
        $user = $request->user();
        $query = StockTransaction::with(['warehouse', 'product', 'creator']);

        if ($user && $user->warehouse_id) {
            $query->where('warehouse_id', $user->warehouse_id);
        } elseif ($request->has('warehouse_id')) {
            $query->where('warehouse_id', $request->query('warehouse_id'));
        }

        if ($request->has('product_id')) {
            $query->where('product_id', $request->query('product_id'));
        }

        if ($request->has('date_from')) {
            $query->where('created_at', '>=', $request->query('date_from'));
        }

        $transactions = $query->orderBy('id', 'desc')->get();

        return response()->json([
            'message' => 'مێژووی جوڵەی کۆگا',
            'data' => $transactions
        ]);
    }
}
