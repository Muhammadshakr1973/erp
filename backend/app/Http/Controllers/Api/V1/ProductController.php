<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Warehouse;
use App\Models\WarehouseStock;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ProductController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $query = Product::with(['category', 'supplier', 'stocks'])->orderBy('id', 'desc');

        if ($user && $user->role?->name === 'salesman' && $user->isCashVan()) {
            $vanWarehouseId = $user->warehouse_id;
            if ($vanWarehouseId) {
                $query->where(function ($q) use ($vanWarehouseId) {
                    $q->whereHas('stocks', function ($sq) use ($vanWarehouseId) {
                        $sq->where('warehouse_id', $vanWarehouseId);
                    })->orWhere(function ($pq) use ($vanWarehouseId) {
                        $pq->where('is_parent', true)
                            ->whereHas('variants.stocks', function ($vsq) use ($vanWarehouseId) {
                                $vsq->where('warehouse_id', $vanWarehouseId);
                            });
                    });
                });
            } else {
                $query->whereRaw('1 = 0');
            }
        } elseif ($request->has('warehouse_id')) {
            $warehouseId = (int) $request->query('warehouse_id');
            if ($request->boolean('in_stock_only')) {
                $query->where(function ($q) use ($warehouseId) {
                    $q->whereHas('stocks', function ($sq) use ($warehouseId) {
                        $sq->where('warehouse_id', $warehouseId)->where('quantity', '>', 0);
                    })->orWhere(function ($pq) use ($warehouseId) {
                        $pq->where('is_parent', true)
                            ->whereHas('variants.stocks', function ($vsq) use ($warehouseId) {
                                $vsq->where('warehouse_id', $warehouseId)->where('quantity', '>', 0);
                            });
                    });
                });
            } elseif ($request->boolean('van_only')) {
                $query->where(function ($q) use ($warehouseId) {
                    $q->whereHas('stocks', function ($sq) use ($warehouseId) {
                        $sq->where('warehouse_id', $warehouseId);
                    })->orWhere(function ($pq) use ($warehouseId) {
                        $pq->where('is_parent', true)
                            ->whereHas('variants.stocks', function ($vsq) use ($warehouseId) {
                                $vsq->where('warehouse_id', $warehouseId);
                            });
                    });
                });
            }
        }

        $products = $query->get();
        if ($user && in_array($user->role?->name, ['salesman', 'driver'])) {
            $products->makeHidden(['cost_price']);
        }
        return response()->json([
            'message' => 'لیستی کاڵاکان',
            'data' => $products
        ]);
    }

    public function show(Request $request, Product $product): JsonResponse
    {
        $user = $request->user();
        if ($user && $user->role?->name === 'salesman' && $user->isCashVan()) {
            $vanWarehouseId = $user->warehouse_id;
            $hasStock = false;
            if ($vanWarehouseId) {
                if ($product->is_parent) {
                    $hasStock = $product->variants()
                        ->whereHas('stocks', fn ($q) => $q->where('warehouse_id', $vanWarehouseId))
                        ->exists();
                } else {
                    $hasStock = $product->stocks()->where('warehouse_id', $vanWarehouseId)->exists();
                }
            }
            if (!$hasStock) {
                return response()->json([
                    'message' => 'ئەم کاڵایە لە کۆگای ئۆتۆمبێلەکەتدا بوونی نییە.',
                    'error' => 'Not Found'
                ], 404);
            }
        }

        $productData = $product->load(['category', 'supplier', 'stocks']);
        if ($user && in_array($user->role?->name, ['salesman', 'driver'])) {
            $productData->makeHidden(['cost_price']);
        }

        return response()->json([
            'message' => 'زانیاریی کاڵا',
            'data' => $productData
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $isParent = $request->boolean('is_parent');

        if (empty($request->sku)) {
            $prefix = $isParent ? 'GRP-' : 'SKU-';
            $request->merge(['sku' => $prefix . strtoupper(bin2hex(random_bytes(4)))]);
        }
        if ($isParent || ($request->has('barcode') && empty($request->barcode))) {
            $request->merge(['barcode' => null]);
        }
        if (empty($request->unit)) {
            $request->merge(['unit' => 'دانە']);
        }

        $rules = [
            'name' => 'required|string|max:255',
            'sku' => 'required|string|max:255|unique:products,sku',
            'barcode' => 'nullable|string|max:255|unique:products,barcode',
            'category_id' => 'nullable|exists:categories,id',
            'supplier_id' => 'nullable|exists:suppliers,id',
            'unit' => 'nullable|string|max:255',
            'units_per_carton' => 'nullable|integer|min:1',
            'cost_price' => 'nullable|numeric|min:0',
            'price_n1' => 'nullable|numeric|min:0',
            'price_n2' => 'nullable|numeric|min:0',
            'price_n3' => 'nullable|numeric|min:0',
            'image_path' => 'nullable|string',
            'is_active' => 'boolean',
            'is_parent' => 'boolean',
            'parent_id' => 'nullable|exists:products,id',
            'variant_name' => 'nullable|string|max:100',
            'use_parent_price' => 'boolean',
            'initial_stock' => 'nullable|numeric|min:0',
            'min_stock_level' => 'nullable|integer|min:0',
        ];

        if ($isParent) {
            $rules['variants'] = 'required|array|min:1';
            $rules['variants.*.existing_product_id'] = 'nullable|integer|exists:products,id';
            $rules['variants.*.variant_name'] = 'required|string|max:100';
            $rules['variants.*.sku'] = 'nullable|string|max:255';
            $rules['variants.*.barcode'] = 'nullable|string|max:255';
            $rules['variants.*.use_parent_price'] = 'boolean';
            $rules['variants.*.cost_price'] = 'nullable|numeric|min:0';
            $rules['variants.*.price_n1'] = 'nullable|numeric|min:0';
            $rules['variants.*.price_n2'] = 'nullable|numeric|min:0';
            $rules['variants.*.price_n3'] = 'nullable|numeric|min:0';
            $rules['variants.*.initial_stock'] = 'nullable|numeric|min:0';
            $rules['variants.*.min_stock_level'] = 'nullable|integer|min:0';
            $rules['variants.*.is_active'] = 'nullable|boolean';
        }

        $validated = $request->validate($rules);

        if ($isParent) {
            $variantsInput = $validated['variants'];
            $this->validateVariantList($variantsInput, null);

            $userId = $request->user()->id ?? 1;
            $parentData = collect($validated)->except([
                'initial_stock',
                'min_stock_level',
                'variants',
                'parent_id',
                'variant_name',
            ])->all();
            $parentData['is_parent'] = true;
            $parentData['parent_id'] = null;
            $parentData['variant_name'] = null;
            $parentData['barcode'] = null;
            $parentData['use_parent_price'] = true;

            [$parent, $savedVariants] = DB::transaction(function () use ($parentData, $variantsInput, $userId) {
                $parent = Product::create($parentData);
                $warehouse = Warehouse::firstOrCreate(
                    ['name' => 'کۆگای سەرەکی'],
                    ['is_main' => true, 'is_active' => true]
                );

                $savedVariants = [];
                foreach ($variantsInput as $v) {
                    $savedVariants[] = $this->upsertVariantForParent(
                        $parent,
                        $v,
                        $warehouse,
                        $userId
                    );
                }

                return [$parent, $savedVariants];
            });

            $parent->load(['category', 'supplier', 'stocks']);
            foreach ($savedVariants as $variant) {
                $variant->load(['category', 'supplier', 'stocks']);
            }

            event(new \App\Events\ProductStockUpdated($parent, 'create'));
            foreach ($savedVariants as $variant) {
                event(new \App\Events\ProductStockUpdated($variant, 'update'));
            }

            return response()->json([
                'message' => 'کاڵاکە بە سەرکەوتوویی زیادکرا',
                'data' => $parent,
                'variants' => $savedVariants,
            ], 201);
        }

        $productData = collect($validated)->except(['initial_stock', 'min_stock_level', 'variants'])->all();
        $productData['is_parent'] = false;
        if (!empty($productData['parent_id']) && !empty($productData['variant_name'])) {
            $parentProduct = Product::find($productData['parent_id']);
            if ($parentProduct) {
                $productData['name'] = trim($parentProduct->name) . ' - ' . trim($productData['variant_name']);
                if (($productData['use_parent_price'] ?? true) === true) {
                    $productData['cost_price'] = $parentProduct->cost_price;
                    $productData['price_n1'] = $parentProduct->price_n1;
                    $productData['price_n2'] = $parentProduct->price_n2;
                    $productData['price_n3'] = $parentProduct->price_n3;
                }
            }
        }

        $product = Product::create($productData);

        $initial_stock = (float) $request->input('initial_stock', 0);
        $min_stock_level = (int) $request->input('min_stock_level', 0);
        $warehouse = Warehouse::firstOrCreate(['name' => 'کۆگای سەرەکی'], ['is_main' => true, 'is_active' => true]);

        $stock = WarehouseStock::create([
            'product_id' => $product->id,
            'warehouse_id' => $warehouse->id,
            'quantity' => 0,
            'reserved_quantity' => 0,
            'min_stock_level' => $min_stock_level
        ]);

        if ($initial_stock > 0) {
            $stock->adjustStock(
                $initial_stock,
                'ADJUSTMENT',
                $request->user()->id ?? 1,
                'product',
                $product->id,
                'ستۆکی سەرەتایی کاڵا'
            );
        }

        event(new \App\Events\ProductStockUpdated($product, 'create'));

        return response()->json([
            'message' => 'کاڵاکە بە سەرکەوتوویی زیادکرا',
            'data' => $product->load(['category', 'supplier', 'stocks'])
        ], 201);
    }

    public function update(Request $request, Product $product): JsonResponse
    {
        $wantsParent = $request->has('is_parent') ? $request->boolean('is_parent') : (bool) $product->is_parent;

        if (!$product->is_parent && $wantsParent) {
            if ($product->parent_id !== null) {
                throw ValidationException::withMessages([
                    'is_parent' => 'جۆرێکی لاوەکی ناتوانرێت بکرێتە کاڵای سەرەکی.',
                ]);
            }
            $hasStock = WarehouseStock::where('product_id', $product->id)->where('quantity', '>', 0)->exists();
            $hasSales = $product->salesItems()->exists();
            if ($hasStock || $hasSales) {
                throw ValidationException::withMessages([
                    'is_parent' => 'ئەم کاڵایە ستۆک یان فرۆشتنی هەیە؛ تکایە کاڵایەکی سەرەکی نوێ دروست بکە و ئەم کاڵایە وەک جۆر بلکێنە پێیەوە.',
                ]);
            }
        }

        if ($product->is_parent && !$wantsParent && $product->variants()->exists()) {
            throw ValidationException::withMessages([
                'is_parent' => 'سەرەتا جۆرەکانی ژێر ئەم کاڵایە جیا بکەرەوە یان بسڕەوە.',
            ]);
        }

        if (empty($request->sku)) {
            $prefix = $wantsParent ? 'GRP-' : 'SKU-';
            $request->merge(['sku' => $prefix . strtoupper(bin2hex(random_bytes(4)))]);
        }
        if ($wantsParent || ($request->has('barcode') && empty($request->barcode))) {
            $request->merge(['barcode' => null]);
        }
        if (empty($request->unit)) {
            $request->merge(['unit' => 'دانە']);
        }

        $rules = [
            'name' => 'required|string|max:255',
            'sku' => 'required|string|max:255|unique:products,sku,' . $product->id,
            'barcode' => 'nullable|string|max:255|unique:products,barcode,' . $product->id,
            'category_id' => 'nullable|exists:categories,id',
            'supplier_id' => 'nullable|exists:suppliers,id',
            'unit' => 'nullable|string|max:255',
            'units_per_carton' => 'nullable|integer|min:1',
            'cost_price' => 'nullable|numeric|min:0',
            'price_n1' => 'nullable|numeric|min:0',
            'price_n2' => 'nullable|numeric|min:0',
            'price_n3' => 'nullable|numeric|min:0',
            'image_path' => 'nullable|string',
            'is_active' => 'boolean',
            'is_parent' => 'boolean',
            'variant_name' => 'nullable|string|max:100',
            'use_parent_price' => 'boolean',
            'initial_stock' => 'nullable|numeric|min:0',
            'min_stock_level' => 'nullable|integer|min:0',
        ];

        if ($wantsParent) {
            $rules['variants'] = 'nullable|array|min:1';
            $rules['variants.*.id'] = 'nullable|integer|exists:products,id';
            $rules['variants.*.existing_product_id'] = 'nullable|integer|exists:products,id';
            $rules['variants.*.variant_name'] = 'required|string|max:100';
            $rules['variants.*.sku'] = 'nullable|string|max:255';
            $rules['variants.*.barcode'] = 'nullable|string|max:255';
            $rules['variants.*.use_parent_price'] = 'boolean';
            $rules['variants.*.cost_price'] = 'nullable|numeric|min:0';
            $rules['variants.*.price_n1'] = 'nullable|numeric|min:0';
            $rules['variants.*.price_n2'] = 'nullable|numeric|min:0';
            $rules['variants.*.price_n3'] = 'nullable|numeric|min:0';
            $rules['variants.*.initial_stock'] = 'nullable|numeric|min:0';
            $rules['variants.*.min_stock_level'] = 'nullable|integer|min:0';
            $rules['variants.*.is_active'] = 'nullable|boolean';
            $rules['detached_variant_ids'] = 'nullable|array';
            $rules['detached_variant_ids.*'] = 'integer|exists:products,id';
        }

        $validated = $request->validate($rules);

        if ($wantsParent) {
            $variantsInput = $validated['variants'] ?? null;
            $detachedIds = $validated['detached_variant_ids'] ?? [];
            if ($variantsInput !== null) {
                $this->validateVariantList($variantsInput, $product->id);
            }

            $userId = $request->user()->id ?? 1;
            $parentData = collect($validated)->except([
                'initial_stock',
                'min_stock_level',
                'variants',
                'detached_variant_ids',
                'variant_name',
            ])->all();
            $parentData['is_parent'] = true;
            $parentData['parent_id'] = null;
            $parentData['variant_name'] = null;
            $parentData['barcode'] = null;
            $parentData['use_parent_price'] = true;

            [$savedVariants, $detachedVariants] = DB::transaction(function () use ($product, $parentData, $variantsInput, $detachedIds, $userId) {
                $product->update($parentData);

                $detachedVariants = [];
                if (!empty($detachedIds)) {
                    $toDetach = Product::where('parent_id', $product->id)
                        ->whereIn('id', $detachedIds)
                        ->get();
                    foreach ($toDetach as $child) {
                        $child->update([
                            'parent_id' => null,
                            'variant_name' => null,
                            'use_parent_price' => true,
                        ]);
                        $detachedVariants[] = $child;
                    }
                }

                $warehouse = Warehouse::firstOrCreate(
                    ['name' => 'کۆگای سەرەکی'],
                    ['is_main' => true, 'is_active' => true]
                );

                $savedVariants = [];
                if ($variantsInput !== null) {
                    foreach ($variantsInput as $v) {
                        $savedVariants[] = $this->upsertVariantForParent(
                            $product,
                            $v,
                            $warehouse,
                            $userId
                        );
                    }
                } else {
                    // Sync shared parent attributes & inherited prices to existing variants
                    $children = $product->variants()->get();
                    foreach ($children as $child) {
                        $vName = $child->variant_name ?: $child->name;
                        $updateFields = [
                            'name' => trim($product->name) . ' - ' . trim($vName),
                            'category_id' => $product->category_id,
                            'supplier_id' => $product->supplier_id,
                            'unit' => $product->unit,
                            'units_per_carton' => $product->units_per_carton,
                            'image_path' => $product->image_path,
                        ];
                        if (!$product->is_active) {
                            $updateFields['is_active'] = false;
                        }
                        if ($child->use_parent_price) {
                            $updateFields['cost_price'] = $product->cost_price;
                            $updateFields['price_n1'] = $product->price_n1;
                            $updateFields['price_n2'] = $product->price_n2;
                            $updateFields['price_n3'] = $product->price_n3;
                        }
                        $child->update($updateFields);
                        $savedVariants[] = $child;
                    }
                }

                return [$savedVariants, $detachedVariants];
            });

            $product->load(['category', 'supplier', 'stocks']);
            foreach ($savedVariants as $variant) {
                $variant->load(['category', 'supplier', 'stocks']);
            }
            foreach ($detachedVariants as $detached) {
                $detached->load(['category', 'supplier', 'stocks']);
            }

            event(new \App\Events\ProductStockUpdated($product, 'update'));
            foreach ($savedVariants as $variant) {
                event(new \App\Events\ProductStockUpdated($variant, 'update'));
            }
            foreach ($detachedVariants as $detached) {
                event(new \App\Events\ProductStockUpdated($detached, 'update'));
            }

            return response()->json([
                'message' => 'کاڵاکە بە سەرکەوتوویی نوێکرایەوە',
                'data' => $product,
                'variants' => $savedVariants,
                'detached_variants' => $detachedVariants,
            ]);
        }

        $productData = collect($validated)->except(['initial_stock', 'min_stock_level', 'variants', 'detached_variant_ids'])->all();
        $productData['is_parent'] = false;

        // If editing a child variant, keep formatted name and optional parent price inheritance
        if ($product->parent_id !== null) {
            $parentProduct = $product->parent;
            if ($parentProduct) {
                $vName = trim((string) ($productData['variant_name'] ?? $product->variant_name ?? ''));
                if ($vName !== '') {
                    $productData['variant_name'] = $vName;
                    $productData['name'] = trim($parentProduct->name) . ' - ' . $vName;
                }
                $useParentPrice = array_key_exists('use_parent_price', $productData)
                    ? (bool) $productData['use_parent_price']
                    : (bool) $product->use_parent_price;
                if ($useParentPrice) {
                    $productData['cost_price'] = $parentProduct->cost_price;
                    $productData['price_n1'] = $parentProduct->price_n1;
                    $productData['price_n2'] = $parentProduct->price_n2;
                    $productData['price_n3'] = $parentProduct->price_n3;
                }
            }
        }

        $product->update($productData);

        if ($request->has('min_stock_level')) {
            $min_stock_level = (int)$request->input('min_stock_level');
            $stocks = WarehouseStock::where('product_id', $product->id)->get();
            if ($stocks->isNotEmpty()) {
                foreach ($stocks as $st) {
                    $st->update(['min_stock_level' => $min_stock_level]);
                }
            } else {
                $warehouse = Warehouse::firstOrCreate(['name' => 'کۆگای سەرەکی'], ['is_main' => true, 'is_active' => true]);
                WarehouseStock::create([
                    'product_id' => $product->id,
                    'warehouse_id' => $warehouse->id,
                    'quantity' => 0,
                    'reserved_quantity' => 0,
                    'min_stock_level' => $min_stock_level
                ]);
            }
        }

        if ($request->has('initial_stock')) {
            $initial_stock = (float) $request->input('initial_stock');
            $warehouse = Warehouse::firstOrCreate(['name' => 'کۆگای سەرەکی'], ['is_main' => true, 'is_active' => true]);
            $stock = WarehouseStock::firstOrCreate([
                'product_id' => $product->id,
                'warehouse_id' => $warehouse->id
            ], [
                'quantity' => 0,
                'reserved_quantity' => 0
            ]);

            $diff = round($initial_stock - (float) $stock->quantity, 3);
            if ($diff != 0.0) {
                $stock->adjustStock(
                    $diff,
                    'ADJUSTMENT',
                    $request->user()->id ?? 1,
                    'product',
                    $product->id,
                    'نوێکردنەوەی بڕی دەستپێک'
                );
            }
        }

        event(new \App\Events\ProductStockUpdated($product, 'update'));

        return response()->json([
            'message' => 'کاڵاکە بە سەرکەوتوویی نوێکرایەوە',
            'data' => $product->load(['category', 'supplier', 'stocks'])
        ]);
    }

    public function detachVariant(Product $product): JsonResponse
    {
        if ($product->parent_id === null) {
            return response()->json([
                'message' => 'ئەم کاڵایە جۆری لاوەکی نییە.'
            ], 422);
        }

        $product->update([
            'parent_id' => null,
            'variant_name' => null,
            'use_parent_price' => true,
        ]);

        $product->load(['category', 'supplier', 'stocks']);
        event(new \App\Events\ProductStockUpdated($product, 'update'));

        return response()->json([
            'message' => 'جۆرەکە بە سەرکەوتوویی کرا بە کاڵای سەربەخۆ',
            'data' => $product,
        ]);
    }

    public function destroy(Product $product): JsonResponse
    {
        $productId = $product->id;
        $detachedVariants = [];

        DB::transaction(function () use ($product, &$detachedVariants) {
            if ($product->is_parent) {
                $children = $product->variants()->get();
                foreach ($children as $child) {
                    $child->update([
                        'parent_id' => null,
                        'variant_name' => null,
                        'use_parent_price' => true,
                    ]);
                    $detachedVariants[] = $child->load(['category', 'supplier', 'stocks']);
                }
            }
            $product->delete();
        });

        foreach ($detachedVariants as $detached) {
            event(new \App\Events\ProductStockUpdated($detached, 'update'));
        }
        event(new \App\Events\ProductStockUpdated(null, 'delete', $productId));

        return response()->json([
            'message' => 'کاڵاکە سڕدرایەوە',
            'detached_variants' => $detachedVariants,
        ]);
    }

    private function validateVariantList(array $variants, ?int $parentId): void
    {
        $seenBarcodes = [];
        $seenSkus = [];
        $seenExistingIds = [];

        foreach ($variants as $index => $v) {
            $id = !empty($v['id']) ? (int) $v['id'] : null;
            $existingId = !empty($v['existing_product_id']) ? (int) $v['existing_product_id'] : null;
            $targetId = $id ?? $existingId;

            if ($existingId !== null) {
                if (in_array($existingId, $seenExistingIds, true)) {
                    throw ValidationException::withMessages([
                        "variants.{$index}.existing_product_id" => 'هەمان کاڵای کۆن دووجار هەڵبژێردراوە.',
                    ]);
                }
                $seenExistingIds[] = $existingId;

                $existing = Product::find($existingId);
                if (!$existing || $existing->is_parent || ($existing->parent_id !== null && $existing->parent_id !== $parentId)) {
                    throw ValidationException::withMessages([
                        "variants.{$index}.existing_product_id" => 'ئەم کاڵایە ناتوانرێت وەک جۆر بلکێندرێت.',
                    ]);
                }
            }

            if ($id !== null && $parentId !== null) {
                $existingChild = Product::find($id);
                if (!$existingChild || (int) $existingChild->parent_id !== $parentId) {
                    throw ValidationException::withMessages([
                        "variants.{$index}.id" => 'ئەم جۆرە سەر بەم کاڵا سەرەکییە نییە.',
                    ]);
                }
            }

            $barcode = isset($v['barcode']) ? trim((string) $v['barcode']) : '';
            if ($barcode !== '') {
                $lowerBarcode = mb_strtolower($barcode);
                if (in_array($lowerBarcode, $seenBarcodes, true)) {
                    throw ValidationException::withMessages([
                        "variants.{$index}.barcode" => "بارکۆدی '{$barcode}' لەناو جۆرەکاندا دووبارەیە.",
                    ]);
                }
                $seenBarcodes[] = $lowerBarcode;

                $dupBarcode = Product::where('barcode', $barcode)
                    ->when($targetId, fn ($q) => $q->where('id', '!=', $targetId))
                    ->exists();
                if ($dupBarcode) {
                    throw ValidationException::withMessages([
                        "variants.{$index}.barcode" => "بارکۆدی '{$barcode}' پێشتر بۆ کاڵایەکی تر بەکارهاتووە.",
                    ]);
                }
            }

            $sku = isset($v['sku']) ? trim((string) $v['sku']) : '';
            if ($sku !== '') {
                $lowerSku = mb_strtolower($sku);
                if (in_array($lowerSku, $seenSkus, true)) {
                    throw ValidationException::withMessages([
                        "variants.{$index}.sku" => "کۆدی SKU '{$sku}' لەناو جۆرەکاندا دووبارەیە.",
                    ]);
                }
                $seenSkus[] = $lowerSku;

                $dupSku = Product::where('sku', $sku)
                    ->when($targetId, fn ($q) => $q->where('id', '!=', $targetId))
                    ->exists();
                if ($dupSku) {
                    throw ValidationException::withMessages([
                        "variants.{$index}.sku" => "کۆدی SKU '{$sku}' پێشتر بەکارهاتووە.",
                    ]);
                }
            }
        }
    }

    private function upsertVariantForParent(Product $parent, array $v, Warehouse $mainWarehouse, int $userId): Product
    {
        $variantName = trim((string) $v['variant_name']);
        $fullName = trim($parent->name) . ' - ' . $variantName;
        $useParentPrice = array_key_exists('use_parent_price', $v) ? (bool) $v['use_parent_price'] : true;

        $costPrice = $useParentPrice ? $parent->cost_price : ($v['cost_price'] ?? $parent->cost_price);
        $priceN1 = $useParentPrice ? $parent->price_n1 : ($v['price_n1'] ?? $parent->price_n1);
        $priceN2 = $useParentPrice ? $parent->price_n2 : ($v['price_n2'] ?? $parent->price_n2);
        $priceN3 = $useParentPrice ? $parent->price_n3 : ($v['price_n3'] ?? $parent->price_n3);

        $barcode = isset($v['barcode']) && trim((string) $v['barcode']) !== '' ? trim((string) $v['barcode']) : null;
        $sku = isset($v['sku']) && trim((string) $v['sku']) !== '' ? trim((string) $v['sku']) : null;

        $isActive = $parent->is_active
            ? (array_key_exists('is_active', $v) && $v['is_active'] !== null ? (bool) $v['is_active'] : true)
            : false;

        $targetId = !empty($v['id']) ? (int) $v['id'] : (!empty($v['existing_product_id']) ? (int) $v['existing_product_id'] : null);

        if ($targetId !== null) {
            $child = Product::findOrFail($targetId);
            $child->update([
                'parent_id' => $parent->id,
                'is_parent' => false,
                'name' => $fullName,
                'variant_name' => $variantName,
                'sku' => $sku ?: ($child->sku ?: ('SKU-' . strtoupper(bin2hex(random_bytes(4))))),
                'barcode' => $barcode,
                'category_id' => $parent->category_id,
                'supplier_id' => $parent->supplier_id,
                'unit' => $parent->unit,
                'units_per_carton' => $parent->units_per_carton,
                'cost_price' => $costPrice,
                'price_n1' => $priceN1,
                'price_n2' => $priceN2,
                'price_n3' => $priceN3,
                'use_parent_price' => $useParentPrice,
                'image_path' => $parent->image_path,
                'is_active' => $isActive,
            ]);

            if (array_key_exists('min_stock_level', $v) && $v['min_stock_level'] !== null) {
                $minLevel = (int) $v['min_stock_level'];
                $stocks = WarehouseStock::where('product_id', $child->id)->get();
                if ($stocks->isNotEmpty()) {
                    foreach ($stocks as $st) {
                        $st->update(['min_stock_level' => $minLevel]);
                    }
                } else {
                    WarehouseStock::create([
                        'product_id' => $child->id,
                        'warehouse_id' => $mainWarehouse->id,
                        'quantity' => 0,
                        'reserved_quantity' => 0,
                        'min_stock_level' => $minLevel,
                    ]);
                }
            }

            if (array_key_exists('initial_stock', $v) && $v['initial_stock'] !== null) {
                $targetQty = (float) $v['initial_stock'];
                $stock = WarehouseStock::firstOrCreate([
                    'product_id' => $child->id,
                    'warehouse_id' => $mainWarehouse->id,
                ], [
                    'quantity' => 0,
                    'reserved_quantity' => 0,
                    'min_stock_level' => (int) ($v['min_stock_level'] ?? 0),
                ]);
                $diff = round($targetQty - (float) $stock->quantity, 3);
                if ($diff != 0.0) {
                    $stock->adjustStock(
                        $diff,
                        'ADJUSTMENT',
                        $userId,
                        'product',
                        $child->id,
                        'نوێکردنەوەی بڕی ستۆکی جۆر'
                    );
                }
            }

            return $child;
        }

        $child = Product::create([
            'parent_id' => $parent->id,
            'is_parent' => false,
            'name' => $fullName,
            'variant_name' => $variantName,
            'sku' => $sku ?: ('SKU-' . strtoupper(bin2hex(random_bytes(4)))),
            'barcode' => $barcode,
            'category_id' => $parent->category_id,
            'supplier_id' => $parent->supplier_id,
            'unit' => $parent->unit,
            'units_per_carton' => $parent->units_per_carton,
            'cost_price' => $costPrice,
            'price_n1' => $priceN1,
            'price_n2' => $priceN2,
            'price_n3' => $priceN3,
            'use_parent_price' => $useParentPrice,
            'image_path' => $parent->image_path,
            'is_active' => $isActive,
        ]);

        $initialStock = (float) ($v['initial_stock'] ?? 0);
        $minStockLevel = (int) ($v['min_stock_level'] ?? 0);
        $stock = WarehouseStock::create([
            'product_id' => $child->id,
            'warehouse_id' => $mainWarehouse->id,
            'quantity' => 0,
            'reserved_quantity' => 0,
            'min_stock_level' => $minStockLevel,
        ]);

        if ($initialStock > 0) {
            $stock->adjustStock(
                $initialStock,
                'ADJUSTMENT',
                $userId,
                'product',
                $child->id,
                'ستۆکی سەرەتایی جۆری کاڵا'
            );
        }

        return $child;
    }
}
