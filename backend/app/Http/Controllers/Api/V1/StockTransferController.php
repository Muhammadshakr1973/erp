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

    // لیستی گواستنەوەکان
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $query = StockTransfer::with(['fromWarehouse', 'toWarehouse', 'creator', 'items.product'])->orderBy('id', 'desc');

        if ($user && $user->warehouse_id) {
            $query->where(function ($q) use ($user) {
                $q->where('from_warehouse_id', $user->warehouse_id)
                  ->orWhere('to_warehouse_id', $user->warehouse_id);
            });
        }

        $transfers = $query->get();

        return response()->json([
            'message' => 'لیستی گواستنەوەکان',
            'data'    => $transfers
        ], 200);
    }

    // پیشاندانی وردەکاری گواستنەوە
    public function show(Request $request, $id): JsonResponse
    {
        $transfer = StockTransfer::with(['fromWarehouse', 'toWarehouse', 'creator', 'items.product'])->findOrFail($id);
        $user = $request->user();

        if ($user && $user->warehouse_id && $transfer->from_warehouse_id !== $user->warehouse_id && $transfer->to_warehouse_id !== $user->warehouse_id) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ بینینی زانیاری ئەم گواستنەوەیە.',
                'error'   => 'Forbidden.'
            ], 403);
        }

        return response()->json([
            'message' => 'وردەکاری گواستنەوە',
            'data'    => $transfer
        ], 200);
    }

    // دروستکردنی گواستنەوە
    public function store(StoreStockTransferRequest $request): JsonResponse
    {
        $user = $request->user();
        $validated = $request->validated();

        if ($user && $user->warehouse_id && (int)$validated['from_warehouse_id'] !== (int)$user->warehouse_id) {
            return response()->json([
                'message' => 'تۆ ناتوانیت داواکاری گواستنەوە لە کۆگایەکی ترەوە تۆمار بکەیت.',
                'error'   => 'Forbidden.'
            ], 403);
        }

        $transfer = $this->transferService->createTransfer($validated, $user);

        return response()->json([
            'message' => 'داواکاری گواستنەوە بەسەرکەوتوویی دروستکرا',
            'data'    => $transfer->load('items')
        ], 201);
    }

    // پەسەندکردن و جێبەجێکردنی گواستنەوەکە
    public function complete(Request $request, $id): JsonResponse
    {
        $transfer = StockTransfer::with('items')->findOrFail($id);
        $user = $request->user();

        if ($user && $user->warehouse_id && (int)$transfer->to_warehouse_id !== (int)$user->warehouse_id && (int)$transfer->from_warehouse_id !== (int)$user->warehouse_id) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ پەسەندکردنی ئەم گواستنەوەیە.',
                'error'   => 'Forbidden.'
            ], 403);
        }

        $completedTransfer = $this->transferService->completeTransfer($transfer, $user);

        return response()->json([
            'message' => 'کاڵاکان بەسەرکەوتوویی گوازرانەوە بۆ کۆگای وەرگر',
            'data'    => $completedTransfer
        ], 200);
    }
}
