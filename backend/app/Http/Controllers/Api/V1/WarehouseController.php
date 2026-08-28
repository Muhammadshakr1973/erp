<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Warehouse;
use Illuminate\Http\JsonResponse;

class WarehouseController extends Controller
{
    public function index(): JsonResponse
    {
        $warehouses = Warehouse::where('is_active', true)->get();

        if ($warehouses->isEmpty()) {
            $mainWarehouse = Warehouse::create([
                'name' => 'کۆگای سەرەکی',
                'is_main' => true,
                'is_active' => true,
            ]);
            $warehouses = collect([$mainWarehouse]);
        }

        return response()->json([
            'message' => 'لیستی کۆگاکان',
            'data' => $warehouses
        ]);
    }
}
