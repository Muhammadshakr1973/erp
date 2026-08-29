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
        $products = Product::with(['category', 'supplier', 'stocks'])->orderBy('id', 'desc')->get();
        return response()->json([
            'message' => 'لیستی کاڵاکان',
            'data' => $products
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        if (empty($request->sku)) {
            $request->merge(['sku' => 'SKU-' . strtoupper(bin2hex(random_bytes(4)))]);
        }
        if ($request->has('barcode') && empty($request->barcode)) {
            $request->merge(['barcode' => null]);
        }

        $validated = $request->validate([
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
            'is_active' => 'boolean'
        ]);

        $product = Product::create($validated);
        
        $initial_stock = $request->input('initial_stock', 0);
        $warehouse = Warehouse::firstOrCreate(['name' => 'کۆگای سەرەکی'], ['is_main' => true, 'is_active' => true]);
        
        $stock = WarehouseStock::create([
            'product_id' => $product->id,
            'warehouse_id' => $warehouse->id,
            'quantity' => 0,
            'reserved_quantity' => 0
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

        return response()->json([
            'message' => 'کاڵاکە بە سەرکەوتوویی زیادکرا',
            'data' => $product->load(['category', 'supplier', 'stocks'])
        ], 201);
    }

    public function update(Request $request, Product $product): JsonResponse
    {
        if (empty($request->sku)) {
            $request->merge(['sku' => 'SKU-' . strtoupper(bin2hex(random_bytes(4)))]);
        }
        if ($request->has('barcode') && empty($request->barcode)) {
            $request->merge(['barcode' => null]);
        }

        $validated = $request->validate([
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
            'is_active' => 'boolean'
        ]);

        $product->update($validated);

        if ($request->has('initial_stock')) {
            $initial_stock = (int)$request->input('initial_stock');
            $warehouse = Warehouse::firstOrCreate(['name' => 'کۆگای سەرەکی'], ['is_main' => true, 'is_active' => true]);
            $stock = WarehouseStock::firstOrCreate([
                'product_id' => $product->id,
                'warehouse_id' => $warehouse->id
            ], [
                'quantity' => 0,
                'reserved_quantity' => 0
            ]);
            
            $diff = $initial_stock - $stock->quantity;
            if ($diff != 0) {
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

        return response()->json([
            'message' => 'کاڵاکە بە سەرکەوتوویی نوێکرایەوە',
            'data' => $product->load(['category', 'supplier', 'stocks'])
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
