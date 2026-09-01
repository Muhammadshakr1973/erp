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
     * گۆڕینی داواکاری کڕین بۆ پسوڵەی کڕین (PO)
     */
    public function convert(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'requirement_ids' => 'required|array|min:1',
            'requirement_ids.*' => 'required|integer|exists:purchase_requirements,id',
            'notes' => 'nullable|string',
        ]);

        $user = $request->user();

        try {
            $createdOrders = DB::transaction(function () use ($validated, $user) {
                // ١. قفڵکردنی داواکارییەکان بە شێوەی pessimistic بۆ ڕێگری لە کێبڕکێی هاوکات
                $requirements = PurchaseRequirement::whereIn('id', $validated['requirement_ids'])
                    ->lockForUpdate()
                    ->get();

                // ٢. پشکنینی ئەوەی کە ئایا هەموو داواکارییەکان کراوەن و پێشتر نەگۆڕدراون
                foreach ($requirements as $req) {
                    if ($req->status !== 'OPEN') {
                        throw ValidationException::withMessages([
                            'requirement_ids' => "داواکاری کڕینی ژمارە #{$req->id} پێشتر گۆڕدراوە یان داخراوە."
                        ]);
                    }
                }

                // ٣. گرووپکردنی داواکارییەکان بەپێی دابینکەر و کۆگا چونکە هەر دابینکەر/کۆگایەک پسوڵەیەکی کڕینی جیاوازی بۆ دەکرێت
                $groups = $requirements->groupBy(function ($item) {
                    return $item->supplier_id . '-' . $item->warehouse_id;
                });

                $orders = [];

                foreach ($groups as $key => $groupReqs) {
                    $first = $groupReqs->first();
                    $supplierId = $first->supplier_id;
                    $warehouseId = $first->warehouse_id;

                    if (!$supplierId) {
                        throw ValidationException::withMessages([
                            'requirement_ids' => "ناتوانرێت داواکارییەک بەبێ دابینکەر بگۆڕدرێت بۆ پسوڵەی کڕین."
                        ]);
                    }

                    // دروستکردنی پسوڵەی کڕین
                    $orderNumber = 'PO-' . strtoupper(Str::random(8));
                    $purchaseOrder = PurchaseOrder::create([
                        'order_number' => $orderNumber,
                        'supplier_id'  => $supplierId,
                        'warehouse_id' => $warehouseId,
                        'status'       => 'DRAFT',
                        'notes'        => $validated['notes'] ?? 'کۆنڤێرتکراو لە داواکارییەکانی کڕینەوە',
                        'created_by'   => $user->id,
                        'total_amount' => 0,
                    ]);

                    $totalAmount = 0;

                    // Aggregate quantities by product_id to prevent unique constraint violation
                    $productQuantities = [];
                    foreach ($groupReqs as $req) {
                        $pId = $req->product_id;
                        $productQuantities[$pId] = ($productQuantities[$pId] ?? 0) + $req->required_quantity;
                    }

                    foreach ($productQuantities as $productId => $qty) {
                        $product = Product::find($productId);
                        $unitCost = $product ? $product->cost_price : 0;
                        $lineTotal = $qty * $unitCost;
                        $totalAmount += $lineTotal;

                        $purchaseOrder->items()->create([
                            'product_id' => $productId,
                            'quantity'   => $qty,
                            'unit_cost'  => $unitCost,
                            'total_cost' => $lineTotal,
                        ]);
                    }

                    foreach ($groupReqs as $req) {
                        // ئەپدەیتی دۆخی داواکارییەکە بۆ ORDERED
                        $req->update([
                            'status' => 'ORDERED',
                            'purchase_order_id' => $purchaseOrder->id
                        ]);

                        // تۆمارکردنی لۆگ لە داتابەیس بۆ چاودێری گۆڕانکارییەکە (Audit Trail)
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
                                'quantity'          => $req->required_quantity,
                            ],
                            'description' => "داواکاری کڕینی #{$req->id} گۆڕدرا بۆ پسوڵەی کڕینی {$orderNumber}",
                            'user'        => $user,
                        ]);
                    }

                    // نوێکردنەوەی کۆی گشتی پسوڵەی کڕین
                    $purchaseOrder->update(['total_amount' => $totalAmount]);
                    $orders[] = $purchaseOrder->load('items.product', 'supplier', 'warehouse');
                }

                return $orders;
            });

            return response()->json([
                'message' => 'داواکارییەکان بە سەرکەوتوویی گۆڕدران بۆ پسوڵەی کڕین',
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
