<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Category;
use Illuminate\Http\JsonResponse;

class CategoryController extends Controller
{
    public function store(IlluminateHttpRequest $request): JsonResponse
    {
        $validated = $request->validate(['name' => 'required|string|max:255|unique:categories,name']);
        $category = Category::create($validated);
        return response()->json([
            'message' => 'جۆرەکە زیادکرا',
            'data' => $category
        ], 201);
    }

    public function index(): JsonResponse
    {
        $categories = Category::orderBy('name')->get();
        return response()->json([
            'message' => 'لیستی جۆرەکان',
            'data' => $categories
        ]);
    }
}
