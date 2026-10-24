<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\PurchaseRequirement;
use App\Models\PurchaseOrder;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class PurchaseRequirementController extends Controller
{
    /**
     * لیستی داواکارییەکانی کڕین بە دۆخی کراوە
     */
    public function index(): JsonResponse
    {
        $requirements = PurchaseRequirement::with(['product', 'warehouse', 'supplier', 'salesOrder', 'creator'])
            ->where('status', 'OPEN')
            ->orderBy('id', 'desc')
            ->get();

        return response()->json([
            'message' => 'لیستی داواکارییەکانی کڕینی کراوە',
            'data'    => $requirements
        ]);
    }

    /**
     * گرووپکردنی داواکارییەکان بەپێی کۆمپانیا/دابینکەر
     */
    public function group(): JsonResponse
    {
        $grouped = PurchaseRequirement::with(['product', 'supplier', 'warehouse'])
            ->where('status', 'OPEN')
            ->get()
            ->groupBy('supplier_id');

        $result = [];
        foreach ($grouped as $supplierId => $items) {
            $supplier = $items->first()->supplier;
            $result[] = [
                'supplier_id'   => $supplierId,
                'supplier_name' => $supplier ? $supplier->name : 'بێ دابینکەر',
                'items_count'   => $items->count(),
                'requirements'  => $items
            ];
        }

        return response()->json([
            'message' => 'داواکارییەکانی کڕین بەپێی دابینکەر',
            'data'    => $result
        ]);
    }

    /**
     * دروستکردنی داواکاری کڕین بە دەستی بۆ هەر کاڵایەک
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'product_id'        => 'required|integer|exists:products,id',
            'warehouse_id'      => 'required|integer|exists:warehouses,id',
            'supplier_id'       => 'nullable|integer|exists:suppliers,id',
            'required_quantity' => 'required|integer|min:1',
            'notes'             => 'nullable|string',
        ]);

        $product = Product::findOrFail($validated['product_id']);
        $supplierId = $validated['supplier_id'] ?? $product->supplier_id;

        $stock = \App\Models\WarehouseStock::where('warehouse_id', $validated['warehouse_id'])
            ->where('product_id', $product->id)
            ->first();
        $currentStock = $stock ? $stock->quantity : 0;

        $req = PurchaseRequirement::create([
            'product_id'         => $product->id,
            'warehouse_id'       => $validated['warehouse_id'],
            'supplier_id'        => $supplierId,
            'required_quantity'  => $validated['required_quantity'],
            'current_stock'      => $currentStock,
            'suggested_quantity' => $validated['required_quantity'],
            'is_urgent'          => false,
            'status'             => 'OPEN',
            'created_by'         => $request->user()->id,
        ]);

        return response()->json([
            'message' => 'کاڵا بە سەرکەوتوویی زیادکرا بۆ پێداویستییەکانی کڕین',
            'data'    => $req->load(['product', 'warehouse', 'supplier', 'creator'])
        ], 201);
    }

    /**
     * دەستکاریکردنی داواکاری کڕین (گۆڕینی دابینکەر یان بڕی پێویست)
     */
    public function update(Request $request, $id): JsonResponse
    {
        $req = PurchaseRequirement::findOrFail($id);
        $validated = $request->validate([
            'supplier_id'                     => 'nullable|integer|exists:suppliers,id',
            'required_quantity'               => 'nullable|integer|min:1',
            'warehouse_id'                    => 'nullable|integer|exists:warehouses,id',
            'update_product_default_supplier' => 'nullable|boolean',
        ]);

        if (array_key_exists('supplier_id', $validated)) {
            $req->supplier_id = $validated['supplier_id'];
            if (!empty($validated['update_product_default_supplier']) && $validated['supplier_id']) {
                $req->product()->update(['supplier_id' => $validated['supplier_id']]);
            }
        }

        if (isset($validated['required_quantity'])) {
            $req->required_quantity = $validated['required_quantity'];
            $req->suggested_quantity = $validated['required_quantity'];
        }

        if (isset($validated['warehouse_id'])) {
            $req->warehouse_id = $validated['warehouse_id'];
        }

        $req->save();

        return response()->json([
            'message' => 'داواکارییەکە بە سەرکەوتوویی نوێکرایەوە',
            'data'    => $req->fresh(['product', 'warehouse', 'supplier', 'salesOrder', 'creator'])
        ]);
    }

    /**
     * سڕینەوەی داواکاری کڕین
     */
    public function destroy($id): JsonResponse
    {
        $req = PurchaseRequirement::findOrFail($id);
        $req->update(['status' => 'CLOSED']);
        $req->delete();

        return response()->json([
            'message' => 'داواکارییەکە بە سەرکەوتوویی سڕایەوە'
        ]);
    }

    /**
     * گۆڕینی داواکاری کڕین بۆ پسوڵەی کڕین (PO)
     * پشتگیری گۆڕینی دابینکەر، کڕینی بڕی زیاتر و زیادکردنی کاڵای نوێ دەکات
     */
    public function convert(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'requirement_ids'       => 'nullable|array',
            'requirement_ids.*'     => 'integer|exists:purchase_requirements,id',
            'items'                 => 'nullable|array',
            'items.*.requirement_id'=> 'nullable|integer|exists:purchase_requirements,id',
            'items.*.product_id'    => 'required_with:items|integer|exists:products,id',
            'items.*.quantity'      => 'required_with:items|integer|min:1',
            'items.*.supplier_id'   => 'nullable|integer|exists:suppliers,id',
            'items.*.warehouse_id'  => 'nullable|integer|exists:warehouses,id',
            'items.*.unit_cost'     => 'nullable|numeric|min:0',
            'extra_items'           => 'nullable|array',
            'extra_items.*.product_id'   => 'required|integer|exists:products,id',
            'extra_items.*.quantity'     => 'required|integer|min:1',
            'extra_items.*.supplier_id'  => 'nullable|integer|exists:suppliers,id',
            'extra_items.*.warehouse_id' => 'nullable|integer|exists:warehouses,id',
            'extra_items.*.unit_cost'    => 'nullable|numeric|min:0',
            'default_supplier_id'   => 'nullable|integer|exists:suppliers,id',
            'default_warehouse_id'  => 'nullable|integer|exists:warehouses,id',
            'notes'                 => 'nullable|string',
        ]);

        $user = $request->user();

        try {
            $createdOrders = DB::transaction(function () use ($validated, $user) {
                // هێنانی سەرجەم داواکارییەکان کە بەشدارن
                $reqIds = [];
                if (!empty($validated['requirement_ids'])) {
                    $reqIds = array_merge($reqIds, $validated['requirement_ids']);
                }
                if (!empty($validated['items'])) {
                    foreach ($validated['items'] as $it) {
                        if (!empty($it['requirement_id'])) {
                            $reqIds[] = (int) $it['requirement_id'];
                        }
                    }
                }
                $reqIds = array_unique(array_filter($reqIds));

                $requirements = collect();
                if (!empty($reqIds)) {
                    $requirements = PurchaseRequirement::whereIn('id', $reqIds)
                        ->lockForUpdate()
                        ->get()
                        ->keyBy('id');

                    foreach ($requirements as $req) {
                        if ($req->status !== 'OPEN') {
                            throw ValidationException::withMessages([
                                'requirement_ids' => "داواکاری کڕینی ژمارە #{$req->id} پێشتر گۆڕدراوە یان داخراوە."
                            ]);
                        }
                    }
                }

                // دروستکردنی لیستی یەکگرتووی کاڵاکان بۆ کڕین
                $itemsToProcess = [];

                if (!empty($validated['items'])) {
                    foreach ($validated['items'] as $itemData) {
                        $pId = (int) $itemData['product_id'];
                        $reqId = !empty($itemData['requirement_id']) ? (int) $itemData['requirement_id'] : null;
                        $linkedReq = $reqId ? $requirements->get($reqId) : null;

                        $product = Product::find($pId);
                        $supplierId = $itemData['supplier_id'] 
                            ?? ($linkedReq ? $linkedReq->supplier_id : null)
                            ?? $validated['default_supplier_id'] 
                            ?? ($product ? $product->supplier_id : null);

                        $warehouseId = $itemData['warehouse_id']
                            ?? ($linkedReq ? $linkedReq->warehouse_id : null)
                            ?? $validated['default_warehouse_id']
                            ?? 1;

                        $qty = (int) $itemData['quantity'];
                        $unitCost = isset($itemData['unit_cost']) && $itemData['unit_cost'] !== null
                            ? (float) $itemData['unit_cost']
                            : ($product ? (float) $product->cost_price : 0);

                        $itemsToProcess[] = [
                            'requirement_id' => $reqId,
                            'product_id'     => $pId,
                            'supplier_id'    => $supplierId,
                            'warehouse_id'   => $warehouseId,
                            'quantity'       => $qty,
                            'unit_cost'      => $unitCost,
                            'product'        => $product,
                        ];
                    }
                } elseif (!empty($requirements)) {
                    // شێوازی کلاسیك: لە ڕێگەی requirement_ids
                    foreach ($requirements as $req) {
                        $product = Product::find($req->product_id);
                        $supplierId = $req->supplier_id 
                            ?? $validated['default_supplier_id'] 
                            ?? ($product ? $product->supplier_id : null);

                        $itemsToProcess[] = [
                            'requirement_id' => $req->id,
                            'product_id'     => $req->product_id,
                            'supplier_id'    => $supplierId,
                            'warehouse_id'   => $req->warehouse_id,
                            'quantity'       => $req->required_quantity,
                            'unit_cost'      => $product ? (float) $product->cost_price : 0,
                            'product'        => $product,
                        ];
                    }
                }

                // زیادکردنی کاڵا ئیزافییەکان (Extra items)
                if (!empty($validated['extra_items'])) {
                    foreach ($validated['extra_items'] as $extraItem) {
                        $pId = (int) $extraItem['product_id'];
                        $product = Product::find($pId);

                        $supplierId = $extraItem['supplier_id']
                            ?? $validated['default_supplier_id']
                            ?? ($product ? $product->supplier_id : null);

                        $warehouseId = $extraItem['warehouse_id']
                            ?? $validated['default_warehouse_id']
                            ?? 1;

                        $qty = (int) $extraItem['quantity'];
                        $unitCost = isset($extraItem['unit_cost']) && $extraItem['unit_cost'] !== null
                            ? (float) $extraItem['unit_cost']
                            : ($product ? (float) $product->cost_price : 0);

                        $itemsToProcess[] = [
                            'requirement_id' => null,
                            'product_id'     => $pId,
                            'supplier_id'    => $supplierId,
                            'warehouse_id'   => $warehouseId,
                            'quantity'       => $qty,
                            'unit_cost'      => $unitCost,
                            'product'        => $product,
                        ];
                    }
                }

                if (empty($itemsToProcess)) {
                    throw ValidationException::withMessages([
                        'requirement_ids' => 'هیچ کاڵایەک دیاری نەکراوە بۆ کڕین.'
                    ]);
                }

                // دڵنیابوونەوە لەوەی هەموو کاڵاکان دابینکەریان هەیە
                foreach ($itemsToProcess as $item) {
                    if (!$item['supplier_id']) {
                        $pName = $item['product'] ? $item['product']->name : "کاڵای ژمارە {$item['product_id']}";
                        throw ValidationException::withMessages([
                            'supplier_id' => "تکایە دابینکەر (کۆمپانیا) بۆ کاڵای '{$pName}' دیاریبکە پێش دروستکردنی پسوڵەی کڕین."
                        ]);
                    }
                }

                // ٣. گرووپکردنی کاڵاکان بەپێی دابینکەر و کۆگا
                $groups = collect($itemsToProcess)->groupBy(function ($item) {
                    return $item['supplier_id'] . '-' . $item['warehouse_id'];
                });

                $orders = [];

                foreach ($groups as $key => $groupItems) {
                    $first = $groupItems->first();
                    $supplierId = $first['supplier_id'];
                    $warehouseId = $first['warehouse_id'];

                    // دروستکردنی پسوڵەی کڕین
                    $orderNumber = 'PO-' . strtoupper(Str::random(8));
                    $purchaseOrder = PurchaseOrder::create([
                        'order_number' => $orderNumber,
                        'supplier_id'  => $supplierId,
                        'warehouse_id' => $warehouseId,
                        'status'       => 'DRAFT',
                        'notes'        => $validated['notes'] ?? 'دروستکراو لە بەشی پێویست بۆ کڕین',
                        'created_by'   => $user->id,
                        'total_amount' => 0,
                    ]);

                    $totalAmount = 0;

                    // کۆکردنەوەی بڕەکان بەپێی کاڵا بۆ یەکخستن
                    $aggregatedByProduct = [];
                    foreach ($groupItems as $item) {
                        $pId = $item['product_id'];
                        if (!isset($aggregatedByProduct[$pId])) {
                            $aggregatedByProduct[$pId] = [
                                'quantity'  => 0,
                                'unit_cost' => $item['unit_cost'],
                            ];
                        }
                        $aggregatedByProduct[$pId]['quantity'] += $item['quantity'];
                    }

                    foreach ($aggregatedByProduct as $productId => $agg) {
                        $qty = $agg['quantity'];
                        $unitCost = $agg['unit_cost'];
                        $lineTotal = $qty * $unitCost;
                        $totalAmount += $lineTotal;

                        $purchaseOrder->items()->create([
                            'product_id' => $productId,
                            'quantity'   => $qty,
                            'unit_cost'  => $unitCost,
                            'total_cost' => $lineTotal,
                        ]);
                    }

                    // ئەپدەیتکردنی داواکارییە پەیوەندیدارەکان
                    foreach ($groupItems as $item) {
                        if (!empty($item['requirement_id'])) {
                            $req = $requirements->get($item['requirement_id']);
                            if ($req) {
                                $req->update([
                                    'status'            => 'ORDERED',
                                    'purchase_order_id' => $purchaseOrder->id,
                                    'supplier_id'       => $supplierId,
                                ]);

                                app(\App\Services\AuditService::class)->log([
                                    'action'      => 'CONVERTED_TO_PO',
                                    'entity_type' => 'PurchaseRequirement',
                                    'entity_id'   => $req->id,
                                    'table_name'  => 'purchase_requirements',
                                    'old_values'  => ['status' => 'OPEN'],
                                    'new_values'  => [
                                        'status'            => 'ORDERED',
                                        'purchase_order_id' => $purchaseOrder->id,
                                        'order_number'      => $orderNumber,
                                        'product_id'        => $req->product_id,
                                        'quantity'          => $item['quantity'],
                                    ],
                                    'description' => "داواکاری کڕینی #{$req->id} گۆڕدرا بۆ پسوڵەی کڕینی {$orderNumber}",
                                    'user'        => $user,
                                ]);
                            }
                        }
                    }

                    $purchaseOrder->update(['total_amount' => $totalAmount]);
                    $orders[] = $purchaseOrder->load('items.product', 'supplier', 'warehouse');
                }

                return $orders;
            });

            return response()->json([
                'message' => 'پسوڵەی کڕین بە سەرکەوتوویی دروستکرا',
                'data'    => $createdOrders
            ], 200);

        } catch (ValidationException $ve) {
            return response()->json([
                'message' => 'هەڵەی هاوتاکردنەوەی داواکاری',
                'errors'  => $ve->errors()
            ], 422);
        } catch (\Exception $e) {
            return response()->json([
                'message' => 'هەڵەیەک ڕوویدا لە کاتی گۆڕینی داواکاری بۆ پسوڵەی کڕین',
                'error'   => $e->getMessage()
            ], 500);
        }
    }
}
