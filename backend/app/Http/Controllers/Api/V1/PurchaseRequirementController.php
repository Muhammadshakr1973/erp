<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\PurchaseRequirement;
use App\Models\PurchaseOrder;
use App\Models\Product;
use Illuminate\Auth\Access\AuthorizationException;
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
    public function index(Request $request): JsonResponse
    {
        $query = PurchaseRequirement::with(['product', 'warehouse', 'supplier', 'salesOrder', 'creator'])
            ->where('status', 'OPEN')
            ->orderBy('id', 'desc');

        if ($request->user() && $request->user()->warehouse_id) {
            $query->where('warehouse_id', $request->user()->warehouse_id);
        }
        $requirements = $query->get();

        return response()->json([
            'message' => 'لیستی داواکارییەکانی کڕینی کراوە',
            'data'    => $requirements
        ]);
    }

    /**
     * گرووپکردنی داواکارییەکان بەپێی کۆمپانیا/دابینکەر
     */
    public function group(Request $request): JsonResponse
    {
        $query = PurchaseRequirement::with(['product', 'supplier', 'warehouse'])
            ->where('status', 'OPEN');
        if ($request->user() && $request->user()->warehouse_id) {
            $query->where('warehouse_id', $request->user()->warehouse_id);
        }
        $grouped = $query->get()->groupBy('supplier_id');

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
            'requirement_ids' => 'sometimes|array',
            'requirement_ids.*' => 'required|integer|exists:purchase_requirements,id',
            'requirement_items' => 'sometimes|array',
            'requirement_items.*.id' => 'required|integer|distinct|exists:purchase_requirements,id',
            'requirement_items.*.quantity' => 'required|integer|min:1',
            'requirement_items.*.supplier_id' => 'required|integer|exists:suppliers,id',
            'additional_items' => 'sometimes|array',
            'additional_items.*.product_id' => 'required|integer|exists:products,id',
            'additional_items.*.supplier_id' => 'required|integer|exists:suppliers,id',
            'additional_items.*.warehouse_id' => 'required|integer|exists:warehouses,id',
            'additional_items.*.quantity' => 'required|integer|min:1',
            'notes' => 'nullable|string',
        ]);

        $user = $request->user();
        $requirementItems = collect($validated['requirement_items'] ?? [])
            ->keyBy('id');
        $requirementIds = array_unique(array_merge(
            $validated['requirement_ids'] ?? [],
            $requirementItems->keys()->all()
        ));
        $additionalItems = $validated['additional_items'] ?? [];

        if ($user && $user->warehouse_id) {
            foreach ($additionalItems as $item) {
                if ((int) $item['warehouse_id'] !== (int) $user->warehouse_id) {
                    return response()->json([
                        'message' => 'تۆ ناتوانیت داواکاری کڕین بۆ کۆگایەکی تر تۆمار بکەیت.',
                        'error'   => 'Forbidden.'
                    ], 403);
                }
            }
        }

        try {
            if (empty($requirementIds) && empty($additionalItems)) {
                throw ValidationException::withMessages([
                    'items' => 'لانیکەم یەک کاڵا هەڵبژێرە بۆ پسوڵەی کڕین.'
                ]);
            }

            $createdOrders = DB::transaction(function () use ($validated, $user, $requirementItems, $requirementIds, $additionalItems) {
                $requirements = PurchaseRequirement::whereIn('id', $requirementIds)
                    ->lockForUpdate()
                    ->get();

                if ($requirements->count() !== count($requirementIds)) {
                    throw ValidationException::withMessages([
                        'requirement_ids' => 'هەندێک داواکاریی کڕین نەدۆزرایەوە.'
                    ]);
                }

                foreach ($requirements as $req) {
                    if ($user && $user->warehouse_id &&
                        (int) $req->warehouse_id !== (int) $user->warehouse_id) {
                        throw new AuthorizationException(
                            'تۆ ناتوانیت داواکاری کڕین بۆ کۆگایەکی تر تۆمار بکەیت.'
                        );
                    }
                    if ($req->status !== 'OPEN') {
                        throw ValidationException::withMessages([
                            'requirement_ids' => "داواکاری کڕینی ژمارە #{$req->id} پێشتر گۆڕدراوە یان داخراوە."
                        ]);
                    }
                }

                $groups = [];
                foreach ($requirements as $req) {
                    $itemDetails = $requirementItems->get($req->id);
                    $quantity = $itemDetails['quantity'] ?? $req->required_quantity;
                    $supplierId = $itemDetails['supplier_id'] ?? $req->supplier_id;

                    if ($quantity < $req->required_quantity) {
                        throw ValidationException::withMessages([
                            'requirement_items' => "بڕی کاڵای داواکاری #{$req->id} نابێت لە بڕی پێویست کەمتر بێت."
                        ]);
                    }

                    if (!$supplierId) {
                        throw ValidationException::withMessages([
                            'requirement_items' => "دابینکەر بۆ داواکاری #{$req->id} دیاری بکە."
                        ]);
                    }

                    $key = $supplierId . '-' . $req->warehouse_id;
                    $groups[$key] ??= [
                        'supplier_id' => $supplierId,
                        'warehouse_id' => $req->warehouse_id,
                        'quantities' => [],
                        'requirements' => [],
                    ];
                    $groups[$key]['quantities'][$req->product_id] =
                        ($groups[$key]['quantities'][$req->product_id] ?? 0) + $quantity;
                    $groups[$key]['requirements'][] = ['model' => $req, 'quantity' => $quantity];
                }

                foreach ($additionalItems as $item) {
                    $key = $item['supplier_id'] . '-' . $item['warehouse_id'];
                    $groups[$key] ??= [
                        'supplier_id' => $item['supplier_id'],
                        'warehouse_id' => $item['warehouse_id'],
                        'quantities' => [],
                        'requirements' => [],
                    ];
                    $groups[$key]['quantities'][$item['product_id']] =
                        ($groups[$key]['quantities'][$item['product_id']] ?? 0) + $item['quantity'];
                }

                $productIds = [];
                foreach ($groups as $group) {
                    $productIds = array_merge($productIds, array_keys($group['quantities']));
                }
                $products = Product::whereIn('id', array_unique($productIds))->get()->keyBy('id');
                $orders = [];

                foreach ($groups as $group) {
                    $orderNumber = 'PO-' . strtoupper(Str::random(8));
                    $purchaseOrder = PurchaseOrder::create([
                        'order_number' => $orderNumber,
                        'supplier_id'  => $group['supplier_id'],
                        'warehouse_id' => $group['warehouse_id'],
                        'status'       => 'DRAFT',
                        'notes'        => $validated['notes'] ?? 'کۆنڤێرتکراو لە داواکارییەکانی کڕینەوە',
                        'created_by'   => $user->id,
                        'total_amount' => 0,
                    ]);

                    $totalAmount = 0;
                    foreach ($group['quantities'] as $productId => $quantity) {
                        $product = $products->get($productId);
                        if (!$product) {
                            throw ValidationException::withMessages([
                                'additional_items' => "کاڵای #{$productId} لە سیستەمدا بەردەست نییە."
                            ]);
                        }
                        $unitCost = $product->cost_price;
                        $lineTotal = $quantity * $unitCost;
                        $totalAmount += $lineTotal;

                        $purchaseOrder->items()->create([
                            'product_id' => $productId,
                            'quantity'   => $quantity,
                            'unit_cost'  => $unitCost,
                            'total_cost' => $lineTotal,
                        ]);
                    }

                    foreach ($group['requirements'] as $requirementData) {
                        $req = $requirementData['model'];
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
                                'quantity'          => $requirementData['quantity'],
                            ],
                            'description' => "داواکاری کڕینی #{$req->id} گۆڕدرا بۆ پسوڵەی کڕینی {$orderNumber}",
                            'user'        => $user,
                        ]);
                    }

                    $purchaseOrder->update(['total_amount' => $totalAmount]);
                    $orders[] = $purchaseOrder->load('items.product', 'supplier', 'warehouse');
                }

                return $orders;
            });

            return response()->json([
                'message' => 'داواکارییەکان بە سەرکەوتوویی گۆڕدران بۆ پسوڵەی کڕین',
                'data'    => $createdOrders
            ], 200);

        } catch (AuthorizationException $ae) {
            return response()->json([
                'message' => $ae->getMessage(),
                'error'   => 'Forbidden.'
            ], 403);
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
