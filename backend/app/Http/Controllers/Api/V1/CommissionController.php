<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Commission\ApproveCommissionRequest;
use App\Http\Requests\Api\V1\Commission\CalculateCommissionRequest;
use App\Http\Requests\Api\V1\Commission\CancelCommissionRequest;
use App\Http\Requests\Api\V1\Commission\PayCommissionRequest;
use App\Models\SalesmanCommission;
use App\Services\CommissionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CommissionController extends Controller
{
    protected CommissionService $commissionService;

    public function __construct(CommissionService $commissionService)
    {
        $this->commissionService = $commissionService;
    }

    /**
     * هێنانی لیستی کۆمسیۆنەکان لەگەڵ فلتەرکردن و پەڕەبەندی
     */
    public function index(Request $request): JsonResponse
    {
        $commissions = $this->commissionService->getCommissions($request->all(), $request->user());

        return response()->json([
            'message' => 'لیستی کۆمسیۆنەکانی مەندوب',
            'data'    => $commissions,
        ], 200);
    }

    /**
     * نیشاندانی وردەکاری تەواوی یەک کۆمسیۆن
     */
    public function show($id, Request $request): JsonResponse
    {
        $commission = SalesmanCommission::with([
            'salesman:id,name,phone,commission_rate',
            'calculator:id,name',
            'approver:id,name',
            'payer:id,name',
            'canceller:id,name',
            'details.order.customer:id,name,phone',
        ])->findOrFail($id);

        $user = $request->user();
        if ($user && !$user->isAdmin() && !$user->isOwner() && $commission->salesman_id !== $user->id) {
            return response()->json([
                'message' => 'ڕێگەپێدراو نیت بۆ بینینی ئەم کۆمسیۆنە.',
            ], 403);
        }

        return response()->json([
            'data' => $commission,
        ], 200);
    }

    /**
     * پیشاندانی سەرەتایی (Preview) پسوڵە شایستەکان و کۆمسیۆنی خەمڵێنراو
     */
    public function preview(Request $request): JsonResponse
    {
        $request->validate([
            'salesman_id' => ['required', 'integer', 'exists:users,id'],
            'period_from' => ['required', 'date_format:Y-m-d'],
            'period_to'   => ['required', 'date_format:Y-m-d'],
        ]);

        $preview = $this->commissionService->previewEligibleOrders(
            $request->integer('salesman_id'),
            $request->string('period_from'),
            $request->string('period_to')
        );

        return response()->json([
            'message' => 'پێشبینینی پسوڵە شایستەکان و کۆمسیۆن',
            'data'    => $preview,
        ], 200);
    }

    /**
     * هەژمارکردنی فەرمی کۆمسیۆن
     */
    public function calculate(CalculateCommissionRequest $request): JsonResponse
    {
        $commission = $this->commissionService->calculateCommission($request->validated(), $request->user());

        return response()->json([
            'message' => 'کۆمسیۆن بەسەرکەوتوویی هەژمار کرا',
            'data'    => $commission,
        ], 201);
    }

    /**
     * پەسەندکردنی کۆمسیۆن (CALCULATED -> APPROVED)
     */
    public function approve($id, ApproveCommissionRequest $request): JsonResponse
    {
        $commission = $this->commissionService->approveCommission(
            (int) $id,
            $request->user(),
            $request->input('notes')
        );

        return response()->json([
            'message' => 'کۆمسیۆنەکە بەسەرکەوتوویی پەسەند کرا',
            'data'    => $commission,
        ], 200);
    }

    /**
     * تۆمارکردنی پارەدانی کۆمسیۆن (APPROVED -> PAID)
     */
    public function pay($id, PayCommissionRequest $request): JsonResponse
    {
        $commission = $this->commissionService->payCommission(
            (int) $id,
            $request->user(),
            $request->validated()
        );

        return response()->json([
            'message' => 'پارەی کۆمسیۆنەکە بەسەرکەوتوویی تۆمارکرا',
            'data'    => $commission,
        ], 200);
    }

    /**
     * هەڵوەشاندنەوە یان پاشگەزبوونەوە لە کۆمسیۆن (CANCEL)
     */
    public function cancel($id, CancelCommissionRequest $request): JsonResponse
    {
        $commission = $this->commissionService->cancelCommission(
            (int) $id,
            $request->user(),
            $request->input('reason')
        );

        return response()->json([
            'message' => 'کۆمسیۆنەکە بەسەرکەوتوویی هەڵوەشێنرایەوە و پسوڵەکان ئازادکران',
            'data'    => $commission,
        ], 200);
    }

    /**
     * پوختەی ئامارەکانی کۆمسیۆن
     */
    public function summary(Request $request): JsonResponse
    {
        $summary = $this->commissionService->getCommissionSummary($request->all());

        return response()->json([
            'message' => 'پوختەی ئاماری کۆمسیۆنەکان',
            'data'    => $summary,
        ], 200);
    }

    /**
     * هێنانی کۆمسیۆنەکانی مەندوبی چوونەژوورەوەبوو (بۆ مەندوبەکان)
     */
    public function myCommissions(Request $request): JsonResponse
    {
        $filters = $request->all();
        $filters['salesman_id'] = $request->user()->id;

        $commissions = $this->commissionService->getCommissions($filters, $request->user());

        return response()->json([
            'message' => 'لیستی کۆمسیۆنەکانم',
            'data'    => $commissions,
        ], 200);
    }
}
