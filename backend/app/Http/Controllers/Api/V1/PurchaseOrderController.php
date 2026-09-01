<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Purchase\StorePurchaseOrderRequest;
use App\Models\PurchaseOrder;
use App\Services\PurchaseOrderService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PurchaseOrderController extends Controller
{
    protected PurchaseOrderService $purchaseService;

    public function __construct(PurchaseOrderService $purchaseService)
    {
        $this->purchaseService = $purchaseService;
    }

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $query = PurchaseOrder::with(['supplier', 'warehouse', 'items.product'])->orderBy('id', 'desc');

        if ($user && $user->warehouse_id) {
            $query->where('warehouse_id', $user->warehouse_id);
        }

        $orders = $query->get();
        return response()->json([
            'message' => 'لیستی پسوڵەکانی کڕین',
            'data'    => $orders
        ]);
    }

    public function show(Request $request, $id): JsonResponse
    {
        $order = PurchaseOrder::with(['supplier', 'warehouse', 'items.product'])->findOrFail($id);
        $user = $request->user();

        if ($user && $user->warehouse_id && (int)$order->warehouse_id !== (int)$user->warehouse_id) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ بینینی ئەم پسوڵەی کڕینە لەم کۆگایەدا.',
                'error'   => 'Forbidden.'
            ], 403);
        }

        return response()->json([
            'message' => 'وردەکاری پسوڵەی کڕین',
            'data'    => $order
        ]);
    }

    // دروستکردنی پسوڵەی کڕین
    public function store(StorePurchaseOrderRequest $request): JsonResponse
    {
        $user = $request->user();
        $validated = $request->validated();

        if ($user && $user->warehouse_id && (int)$validated['warehouse_id'] !== (int)$user->warehouse_id) {
            return response()->json([
                'message' => 'تۆ ناتوانیت داواکاری کڕین بۆ کۆگایەکی تر تۆمار بکەیت.',
                'error'   => 'Forbidden.'
            ], 403);
        }

        $order = $this->purchaseService->createOrder($validated, $user);

        return response()->json([
            'message' => 'پسوڵەی کڕین بەسەرکەوتوویی دروستکرا',
            'data'    => $order->load('items')
        ], 201);
    }

    // وەرگرتنی کاڵاکان لە کۆگا و داخستنی پسوڵەکە
    public function receive(Request $request, $id): JsonResponse
    {
        $order = PurchaseOrder::with('items')->findOrFail($id);
        $user = $request->user();

        if ($user && $user->warehouse_id && (int)$order->warehouse_id !== (int)$user->warehouse_id) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ وەرگرتنی ئەم پسوڵەی کڕینە لەم کۆگایەدا.',
                'error'   => 'Forbidden.'
            ], 403);
        }

        $request->validate([
            'items' => 'nullable|array',
            'items.*.product_id' => 'nullable|integer',
            'items.*.item_id' => 'nullable|integer',
            'items.*.quantity' => 'required_with:items|integer|min:1',
        ]);

        $itemsPayload = $request->input('items');

        $completedOrder = $this->purchaseService->receiveOrder($order, $user, $itemsPayload);

        return response()->json([
            'message' => 'کاڵاکان بەسەرکەوتوویی وەرگیران و ستۆک زیاد کرا',
            'data'    => $completedOrder->fresh(['items.product', 'supplier', 'warehouse'])
        ], 200);
    }

    public function cancel(Request $request, $id): JsonResponse
    {
        $order = PurchaseOrder::findOrFail($id);
        $user = $request->user();

        if ($user && $user->warehouse_id && (int)$order->warehouse_id !== (int)$user->warehouse_id) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ هەڵوەشاندنەوەی ئەم پسوڵەی کڕینە.',
                'error'   => 'Forbidden.'
            ], 403);
        }

        $cancelledOrder = $this->purchaseService->cancelOrder($order, $user);

        return response()->json([
            'message' => 'پسوڵەی کڕین بەسەرکەوتوویی هەڵوەشێنرایەوە',
            'data'    => $cancelledOrder
        ], 200);
    }
}
