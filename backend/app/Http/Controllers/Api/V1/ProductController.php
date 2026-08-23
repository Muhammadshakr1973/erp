<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
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
            'unit' => 'nullable|string|max:255',
            'units_per_carton' => 'nullable|integer|min:1',
            'cost_price' => 'nullable|numeric|min:0',
            'price_n1' => 'nullable|numeric|min:0',
            'price_n2' => 'nullable|numeric|min:0',
            'price_n3' => 'nullable|numeric|min:0',
            'is_active' => 'boolean'
        ]);

        $product = Product::create($validated);

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
            'unit' => 'nullable|string|max:255',
            'units_per_carton' => 'nullable|integer|min:1',
            'cost_price' => 'nullable|numeric|min:0',
            'price_n1' => 'nullable|numeric|min:0',
            'price_n2' => 'nullable|numeric|min:0',
            'price_n3' => 'nullable|numeric|min:0',
            'is_active' => 'boolean'
        ]);

        $product->update($validated);

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
