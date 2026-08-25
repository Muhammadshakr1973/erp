<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Supplier;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class SupplierController extends Controller
{
    public function index(): JsonResponse
    {
        $suppliers = DB::table('suppliers')->whereNull('deleted_at')->get();
        return response()->json([
            'message' => 'لیستی سەپڵایەرەکان',
            'data' => $suppliers
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255|unique:suppliers,name',
            'phone' => 'nullable|string|max:20',
            'address' => 'nullable|string|max:255',
            'contact_person' => 'nullable|string|max:255',
        ]);

        if (auth()->check()) {
            $validated['created_by'] = auth()->id();
        }

        $supplier = Supplier::create($validated);

        return response()->json([
            'message' => 'سەپڵایەر بە سەرکەوتوویی زیادکرا',
            'data' => $supplier
        ], 201);
    }
}
