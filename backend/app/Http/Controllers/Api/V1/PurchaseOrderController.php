<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Purchase\StorePurchaseOrderRequest;
use App\Models\PurchaseOrder;
use App\Services\PurchaseOrderService;
use Illuminate\Http\JsonResponse;

class PurchaseOrderController extends Controller
{
    protected PurchaseOrderService $purchaseService;

    public function __construct(PurchaseOrderService $purchaseService)
    {
        $this->purchaseService = $purchaseService;
    }

    public function index(): JsonResponse
    {
        $orders = PurchaseOrder::with(['supplier', 'warehouse', 'items.product'])->orderBy('id', 'desc')->get();
        return response()->json([
            'message' => 'لیستی پسوڵەکانی کڕین',
            'data'    => $orders
        ]);
    }

    // دروستکردنی پسوڵەی کڕین
    public function store(StorePurchaseOrderRequest $request): JsonResponse
    {
        $order = $this->purchaseService->createOrder($request->validated(), $request->user());

        return response()->json([
            'message' => 'پسوڵەی کڕین بەسەرکەوتوویی دروستکرا',
            'data'    => $order->load('items')
        ], 201);
    }

    // وەرگرتنی کاڵاکان لە کۆگا و داخستنی پسوڵەکە
    public function receive($id): JsonResponse
    {
        $order = PurchaseOrder::with('items')->findOrFail($id);

        $completedOrder = $this->purchaseService->receiveOrder($order, request()->user());

        return response()->json([
            'message' => 'کاڵاکان بەسەرکەوتوویی وەرگیران و ستۆک زیاد کرا',
            'data'    => $completedOrder
        ], 200);
    }
}
