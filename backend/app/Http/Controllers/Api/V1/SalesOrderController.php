<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\SalesOrder\StoreSalesOrderRequest;
use App\Services\SalesOrderService;
use Illuminate\Http\JsonResponse;

class SalesOrderController extends Controller
{
    protected SalesOrderService $salesOrderService;

    public function __construct(SalesOrderService $salesOrderService)
    {
        $this->salesOrderService = $salesOrderService;
    }

    public function index(): JsonResponse
    {
        $orders = \App\Models\SalesOrder::with(['customer', 'salesman'])->orderBy('id', 'desc')->get();
        return response()->json([
            'message' => 'لیستی پسوڵەکان',
            'data' => $orders
        ]);
    }

    public function store(StoreSalesOrderRequest $request): JsonResponse
    {
        // ناردنی داتاکان و بەکارهێنەرەکە بۆ لۆژیکی Service
        $order = $this->salesOrderService->createOrder($request->validated(), $request->user());

        // ناردنەوەی وەڵامێکی سەرکەوتوو بە کۆدی 201 (Created)
        return response()->json([
            'message' => 'پسوڵە بەسەرکەوتوویی دروستکرا',
            'data' => $order->load('items') // هێنانەوەی ئایتمەکانیش لەگەڵیدا
        ], 201);
    }

    public function show(int $id): JsonResponse
    {
        $order = \App\Models\SalesOrder::with(['customer', 'salesman', 'items.product', 'warehouse'])->findOrFail($id);
        return response()->json([
            'message' => 'وردەکاری پسوڵە',
            'data' => $order
        ]);
    }

    public function updateStatus(\Illuminate\Http\Request $request, int $id): JsonResponse
    {
        $request->validate([
            'status' => ['required', 'string', 'in:DRAFT,CONFIRMED,PACKING,READY,IN_DELIVERY,DELIVERED,CANCELLED'],
        ]);

        $status = $request->input('status');
        $user = $request->user();

        // Enforce status-based authorization
        if (in_array($status, ['DRAFT', 'CONFIRMED', 'CANCELLED'])) {
            if (!$user->hasPermission('orders.create')) {
                return response()->json([
                    'message' => 'تۆ ڕێگەپێدراو نیت بۆ گۆڕینی دۆخی پسوڵە بۆ ' . $status,
                    'error' => 'Forbidden. Missing permission: orders.create'
                ], 403);
            }
        } elseif (in_array($status, ['PACKING', 'READY'])) {
            if (!$user->hasPermission('stock.pack')) {
                return response()->json([
                    'message' => 'تۆ ڕێگەپێدراو نیت بۆ گۆڕینی دۆخی پسوڵە بۆ ' . $status,
                    'error' => 'Forbidden. Missing permission: stock.pack'
                ], 403);
            }
        } elseif (in_array($status, ['IN_DELIVERY', 'DELIVERED'])) {
            if (!$user->hasPermission('delivery.update')) {
                return response()->json([
                    'message' => 'تۆ ڕێگەپێدراو نیت بۆ گۆڕینی دۆخی پسوڵە بۆ ' . $status,
                    'error' => 'Forbidden. Missing permission: delivery.update'
                ], 403);
            }
        }

        $order = \App\Models\SalesOrder::findOrFail($id);
        $updatedOrder = $this->salesOrderService->transitionTo($order, $status, $user);

        return response()->json([
            'message' => 'دۆخی پسوڵە بە سەرکەوتوویی نوێکرایەوە',
            'data' => $updatedOrder->load('items')
        ]);
    }
}
