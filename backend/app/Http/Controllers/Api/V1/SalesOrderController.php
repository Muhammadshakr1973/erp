<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\SalesOrder\StoreSalesOrderRequest;
use App\Http\Requests\Api\V1\SalesOrder\UpdateSalesOrderRequest;
use App\Services\SalesOrderService;
use Illuminate\Http\JsonResponse;

class SalesOrderController extends Controller
{
    protected SalesOrderService $salesOrderService;

    public function __construct(SalesOrderService $salesOrderService)
    {
        $this->salesOrderService = $salesOrderService;
    }

    public function index(\Illuminate\Http\Request $request): JsonResponse
    {
        $user = $request->user();
        $query = \App\Models\SalesOrder::with(['customer', 'salesman'])->orderBy('id', 'desc');

        if ($user->role?->name === 'salesman') {
            $query->where('salesman_id', $user->id);
        } elseif ($user->role?->name === 'driver') {
            // Drivers can only see orders assigned to their delivery trips
            $tripOrderIds = \DB::table('delivery_trip_orders')
                ->join('delivery_trips', 'delivery_trip_orders.delivery_trip_id', '=', 'delivery_trips.id')
                ->where('delivery_trips.driver_id', $user->id)
                ->pluck('sales_order_id')
                ->toArray();
            $query->whereIn('id', $tripOrderIds);
        } elseif ($user->role?->name === 'warehouse') {
            if ($user->warehouse_id) {
                $query->where('warehouse_id', $user->warehouse_id);
            }
        }

        $orders = $query->get();
        return response()->json([
            'message' => 'لیستی پسوڵەکان',
            'data' => $orders
        ]);
    }

    public function store(StoreSalesOrderRequest $request): JsonResponse
    {
        // Check if salesman is assigned to the customer they are making order for
        $user = $request->user();
        $customerId = $request->input('customer_id');
        if (!$user->hasCustomerAccess($customerId)) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ دروستکردنی پسوڵە بۆ ئەم کڕیارە بەهۆی نەبوونی دەسەڵاتی دەستڕاگەیشتن.',
                'error' => 'Forbidden.'
            ], 403);
        }

        // ناردنی داتاکان و بەکارهێنەرەکە بۆ لۆژیکی Service
        $order = $this->salesOrderService->createOrder($request->validated(), $user);

        // ناردنەوەی وەڵامێکی سەرکەوتوو بە کۆدی 201 (Created)
        return response()->json([
            'message' => 'پسوڵە بەسەرکەوتوویی دروستکرا',
            'data' => $order->load('items') // هێنانەوەی ئایتمەکانیش لەگەڵیدا
        ], 201);
    }

    public function update(UpdateSalesOrderRequest $request, int $id): JsonResponse
    {
        $user = $request->user();
        $order = \App\Models\SalesOrder::findOrFail($id);

        if ($user->role?->name === 'salesman' && $order->salesman_id !== $user->id) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ دەستکاری ئەم پسوڵەیە.',
                'error' => 'Forbidden.'
            ], 403);
        }

        $updatedOrder = $this->salesOrderService->updateOrder($order, $request->validated(), $user);

        return response()->json([
            'message' => 'پسوڵە بەسەرکەوتوویی نوێکرایەوە',
            'data' => $updatedOrder->load('items')
        ]);
    }

    public function show(\Illuminate\Http\Request $request, int $id): JsonResponse
    {
        $user = $request->user();
        $order = \App\Models\SalesOrder::with(['customer', 'salesman', 'items.product', 'warehouse'])->findOrFail($id);

        // IDOR Prevention Access Check
        if ($user->role?->name === 'salesman' && $order->salesman_id !== $user->id) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ بینینی ئەم پسوڵەیە.',
                'error' => 'Forbidden.'
            ], 403);
        }

        if ($user->role?->name === 'driver') {
            $onTrip = \DB::table('delivery_trip_orders')
                ->join('delivery_trips', 'delivery_trip_orders.delivery_trip_id', '=', 'delivery_trips.id')
                ->where('delivery_trip_orders.sales_order_id', $order->id)
                ->where('delivery_trips.driver_id', $user->id)
                ->exists();
            if (!$onTrip) {
                return response()->json([
                    'message' => 'تۆ ڕێگەپێدراو نیت بۆ بینینی ئەم پسوڵەیە.',
                    'error' => 'Forbidden.'
                ], 403);
            }
        }

        if ($user->role?->name === 'warehouse' && $user->warehouse_id && $order->warehouse_id !== $user->warehouse_id) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ بینینی ئەم پسوڵەیە چونکە سەر بە کۆگایەکی ترە.',
                'error' => 'Forbidden.'
            ], 403);
        }

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

        // IDOR prevention on updateStatus
        if ($user->role?->name === 'salesman' && $order->salesman_id !== $user->id) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ گۆڕینی دۆخی ئەم پسوڵەیە.',
                'error' => 'Forbidden.'
            ], 403);
        }

        if ($user->role?->name === 'warehouse' && $user->warehouse_id && $order->warehouse_id !== $user->warehouse_id) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ گۆڕینی دۆخی ئەم پسوڵەیە چونکە سەر بە کۆگایەکی ترە.',
                'error' => 'Forbidden.'
            ], 403);
        }

        $updatedOrder = $this->salesOrderService->transitionTo($order, $status, $user);

        return response()->json([
            'message' => 'دۆخی پسوڵە بە سەرکەوتوویی نوێکرایەوە',
            'data' => $updatedOrder->load('items')
        ]);
    }
}
