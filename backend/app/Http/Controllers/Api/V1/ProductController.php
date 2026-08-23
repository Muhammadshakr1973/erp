<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\JsonResponse;

class ProductController extends Controller
{
    public function index(): JsonResponse
    {
        $products = Product::with(['category', 'stocks'])->get();
        return response()->json([
            'message' => 'لیستی کاڵاکان',
            'data' => $products
        ]);
    }
}
