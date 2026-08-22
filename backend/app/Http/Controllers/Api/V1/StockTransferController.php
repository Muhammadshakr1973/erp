<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Warehouse\StoreStockTransferRequest;
use App\Models\StockTransfer;
use App\Services\StockTransferService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class StockTransferController extends Controller
{
    protected StockTransferService $transferService;

    public function __construct(StockTransferService $transferService)
    {
        $this->transferService = $transferService;
    }

    // دروستکردنی گواستنەوە
    public function store(StoreStockTransferRequest $request): JsonResponse
    {
        $transfer = $this->transferService->createTransfer($request->validated(), $request->user());

        return response()->json([
            'message' => 'داواکاری گواستنەوە بەسەرکەوتوویی دروستکرا',
            'data'    => $transfer->load('items')
        ], 201);
    }

    // پەسەندکردن و جێبەجێکردنی گواستنەوەکە
    public function complete(Request $request, $id): JsonResponse
    {
        $transfer = StockTransfer::with('items')->findOrFail($id);

        $completedTransfer = $this->transferService->completeTransfer($transfer, $request->user());

        return response()->json([
            'message' => 'کاڵاکان بەسەرکەوتوویی گوازرانەوە بۆ کۆگای وەرگر',
            'data'    => $completedTransfer
        ], 200);
    }
}
