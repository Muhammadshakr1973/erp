<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use App\Models\Warehouse;
use App\Models\WarehouseStock;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class ProductController extends Controller
{
    public function index(): JsonResponse
    {
        $products = Product::with(['category', 'stocks'])->orderBy('id', 'desc')->get();
        return response()->json([
            'message' => 'لیستی کاڵاکان',
            'data' => $products
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'sku' => 'nullable|string|max:255',
            'barcode' => 'nullable|string|max:255',
            'category_id' => 'nullable|exists:categories,id',
            'supplier_id' => 'nullable|exists:suppliers,id',
            'unit' => 'nullable|string|max:255',
            'units_per_carton' => 'nullable|integer|min:1',
            'cost_price' => 'nullable|numeric|min:0',
            'price_n1' => 'nullable|numeric|min:0',
            'price_n2' => 'nullable|numeric|min:0',
            'price_n3' => 'nullable|numeric|min:0',
            'image_path' => 'nullable|string',
            'is_active' => 'boolean'
        ]);

        $product = Product::create($validated);
        
        $initial_stock = $request->input('initial_stock', 0);
        $warehouse = Warehouse::firstOrCreate(['name' => 'کۆگای سەرەکی'], ['is_main' => true, 'is_active' => true]);
        WarehouseStock::create([
            'product_id' => $product->id,
            'warehouse_id' => $warehouse->id,
            'quantity' => $initial_stock
        ]);

        return response()->json([
            'message' => 'کاڵاکە بە سەرکەوتوویی زیادکرا',
            'data' => $product->load(['category', 'stocks'])
        ], 201);
    }

    public function update(Request $request, Product $product): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'sku' => 'nullable|string|max:255',
            'barcode' => 'nullable|string|max:255',
            'category_id' => 'nullable|exists:categories,id',
            'supplier_id' => 'nullable|exists:suppliers,id',
            'unit' => 'nullable|string|max:255',
            'units_per_carton' => 'nullable|integer|min:1',
            'cost_price' => 'nullable|numeric|min:0',
            'price_n1' => 'nullable|numeric|min:0',
            'price_n2' => 'nullable|numeric|min:0',
            'price_n3' => 'nullable|numeric|min:0',
            'image_path' => 'nullable|string',
            'is_active' => 'boolean'
        ]);

        $product->update($validated);

        if ($request->has('initial_stock')) {
            $initial_stock = $request->input('initial_stock');
            $warehouse = Warehouse::firstOrCreate(['name' => 'کۆگای سەرەکی'], ['is_main' => true, 'is_active' => true]);
            $stock = WarehouseStock::firstOrNew([
                'product_id' => $product->id,
                'warehouse_id' => $warehouse->id
            ]);
            $stock->quantity = $initial_stock;
            $stock->save();
        }

        return response()->json([
            'message' => 'کاڵاکە بە سەرکەوتوویی نوێکرایەوە',
            'data' => $product->load(['category', 'stocks'])
        ]);
    }

    public function destroy(Product $product): JsonResponse
    {
        $product->delete();
        return response()->json([
            'message' => 'کاڵاکە سڕدرایەوە'
        ]);
    }
}
