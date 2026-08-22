<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Commission\CalculateCommissionRequest;
use App\Services\CommissionService;
use Illuminate\Http\JsonResponse;
use App\Models\SalesmanCommission;

class CommissionController extends Controller
{
    protected CommissionService $commissionService;

    public function __construct(CommissionService $commissionService)
    {
        $this->commissionService = $commissionService;
    }

    // هەژمارکردنی کۆمسیۆن بۆ مانگێک
    public function calculate(CalculateCommissionRequest $request): JsonResponse
    {
        $commission = $this->commissionService->calculateCommission($request->validated(), $request->user());

        return response()->json([
            'message' => 'کۆمسیۆن بەسەرکەوتوویی هەژمار کرا',
            'data'    => $commission->load('details.order')
        ], 201);
    }

    // هێنانی لیستی کۆمسیۆنەکان
    public function index(): JsonResponse
    {
        // دەکرێت لێرەدا فلتەر دابنێین بەپێی مەندوب
        $commissions = SalesmanCommission::with('salesman')->orderByDesc('id')->paginate(20);

        return response()->json([
            'data' => $commissions
        ], 200);
    }
}
