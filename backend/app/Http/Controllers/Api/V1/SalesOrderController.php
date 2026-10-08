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
        $query = \App\Models\SalesOrder::with(['customer.route', 'salesman', 'items.product', 'warehouse'])->orderBy('id', 'desc');

        if ($user->role?->name === 'salesman') {
            $query->where('salesman_id', $user->id);
        } elseif ($user->role?->name === 'driver') {
            // Drivers can see orders assigned to their delivery trips OR orders with status = 'READY'
            $tripOrderIds = \DB::table('delivery_trip_orders')
                ->join('delivery_trips', 'delivery_trip_orders.delivery_trip_id', '=', 'delivery_trips.id')
                ->where('delivery_trips.driver_id', $user->id)
                ->pluck('sales_order_id')
                ->toArray();
            $query->where(function ($q) use ($tripOrderIds) {
                $q->whereIn('id', $tripOrderIds)
                  ->orWhere('status', \App\Models\SalesOrder::STATUS_READY);
            });
        } elseif ($user->role?->name === 'warehouse') {
            if ($user->warehouse_id) {
                $query->where('warehouse_id', $user->warehouse_id);
            }
        }

        if ($request->filled('customer_id')) {
            $query->where('customer_id', $request->input('customer_id'));
        }

        if ($request->filled('salesman_id') && $user->role?->name !== 'salesman') {
            $query->where('salesman_id', $request->input('salesman_id'));
        }

        if ($request->filled('status')) {
            $query->where('status', $request->input('status'));
        }

        if ($request->filled('start_date')) {
            $query->whereDate('created_at', '>=', $request->input('start_date'));
        }

        if ($request->filled('end_date')) {
            $query->whereDate('created_at', '<=', $request->input('end_date'));
        }

        if ($request->filled('search')) {
            $search = $request->input('search');
            $query->where(function ($q) use ($search) {
                $q->where('order_number', 'like', "%{$search}%")
                  ->orWhereHas('customer', function ($cq) use ($search) {
                      $cq->where('name', 'like', "%{$search}%");
                  });
            });
        }

        $orders = $query->get();
        return response()->json([
            'message' => 'لیستی پسوڵەکان',
            'data' => $orders
        ]);
    }

    public function store(StoreSalesOrderRequest $request): JsonResponse
    {
        try {
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

            // Check if the order already existed (cooperative dual-entry update)
            $statusCode = $order->wasRecentlyCreated ? 201 : 200;
            $message = $order->wasRecentlyCreated ? 'پسوڵە بەسەرکەوتوویی دروستکرا' : 'پسوڵەی هاوبەش بەسەرکەوتوویی نوێکرایەوە';

            // ناردنەوەی وەڵامێکی سەرکەوتوو بە کۆدی گونجاو
            return response()->json([
                'message' => $message,
                'data' => $order->load('items') // هێنانەوەی ئایتمەکانیش لەگەڵیدا
            ], $statusCode);
        } catch (\Illuminate\Validation\ValidationException $e) {
            throw $e;
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::error("SalesOrderController store error: " . $e->getMessage(), [
                'exception' => $e,
                'trace' => $e->getTraceAsString(),
            ]);

            return response()->json([
                'message' => 'هەڵەیەک ڕوویدا لە دروستکردنی پسوڵە: ' . $e->getMessage(),
                'error' => $e->getMessage()
            ], 500);
        }
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

        $targetCustomerId = $request->input('customer_id', $order->customer_id);

        if (!$user->hasCustomerAccess($order->customer_id) || !$user->hasCustomerAccess($targetCustomerId)) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ دەستکاری پسوڵە بۆ ئەم کڕیارە بەهۆی نەبوونی دەسەڵاتی دەستڕاگەیشتن.',
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
        if (in_array($status, ['DRAFT', 'CONFIRMED'])) {
            if (!$user->hasPermission('orders.create')) {
                return response()->json([
                    'message' => 'تۆ ڕێگەپێدراو نیت بۆ گۆڕینی دۆخی پسوڵە بۆ ' . $status,
                    'error' => 'Forbidden. Missing permission: orders.create'
                ], 403);
            }
        } elseif (in_array($status, ['PACKING', 'READY'])) {
            if (!$user->hasPermission('stock.pack') && !$user->hasPermission('orders.create')) {
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
        } elseif ($status === 'CANCELLED') {
            $canCancel = $user->hasPermission('orders.create')
                || $user->hasPermission('stock.pack')
                || $user->hasPermission('delivery.update')
                || $user->isAdmin()
                || $user->isOwner();

            if (!$canCancel) {
                return response()->json([
                    'message' => 'تۆ ڕێگەپێدراو نیت بۆ هەڵوەشاندنەوەی ئەم پسوڵەیە.',
                    'error' => 'Forbidden. Missing cancellation permission.'
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

        if ($user->role?->name === 'driver') {
            $onTrip = \DB::table('delivery_trip_orders')
                ->join('delivery_trips', 'delivery_trip_orders.delivery_trip_id', '=', 'delivery_trips.id')
                ->where('delivery_trip_orders.sales_order_id', $order->id)
                ->where('delivery_trips.driver_id', $user->id)
                ->exists();

            if (!$onTrip) {
                return response()->json([
                    'message' => 'تۆ ڕێگەپێدراو نیت بۆ گۆڕینی دۆخی ئەم پسوڵەیە.',
                    'error' => 'Forbidden.'
                ], 403);
            }
        }

        $updatedOrder = $this->salesOrderService->transitionTo($order, $status, $user);

        return response()->json([
            'message' => 'دۆخی پسوڵە بە سەرکەوتوویی نوێکرایەوە',
            'data' => $updatedOrder->load('items')
        ]);
    }

    public function destroy(\Illuminate\Http\Request $request, int $id): JsonResponse
    {
        $user = $request->user();
        $order = \App\Models\SalesOrder::findOrFail($id);

        // IDOR Prevention Access Check
        if ($user->role?->name === 'salesman' && $order->salesman_id !== $user->id) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ سڕینەوەی ئەم پسوڵەیە.',
                'error' => 'Forbidden.'
            ], 403);
        }

        // Warehouse staff or users with stock.pack can delete empty orders (items count == 0)
        $isEmptyOrder = ($order->items()->count() === 0);
        $canDelete = $user->hasPermission('orders.create') 
            || $user->isAdmin() 
            || $user->isOwner()
            || ($isEmptyOrder && ($user->hasPermission('stock.pack') || $user->role?->name === 'warehouse'));

        if (!$canDelete) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ سڕینەوەی ئەم پسوڵەیە.',
                'error' => 'Forbidden. Missing permission to delete order.'
            ], 403);
        }

        $this->salesOrderService->deleteOrder($order, $user);

        return response()->json([
            'message' => 'پسوڵەکە بەسەرکەوتوویی سڕایەوە',
            'data' => null
        ]);
    }

    public function salesmanDashboard(\Illuminate\Http\Request $request): JsonResponse
    {
        $user = $request->user();
        $today = now()->toDateString();
        $sevenDaysAgo = now()->subDays(6)->toDateString();
        $startOfWeek = now()->startOfWeek()->toDateTimeString();
        $endOfWeek = now()->endOfWeek()->toDateTimeString();
        $startOfMonth = now()->startOfMonth()->toDateTimeString();
        $endOfMonth = now()->endOfMonth()->toDateTimeString();
        $startOfLastMonth = now()->subMonthNoOverflow()->startOfMonth()->toDateTimeString();
        $endOfLastMonth = now()->subMonthNoOverflow()->endOfMonth()->toDateTimeString();

        // 1. Today's Route
        $currentDayOfWeek = now()->format('l'); // 'Saturday', 'Sunday', etc.
        $isHoliday = ($currentDayOfWeek === 'Friday');

        if ($isHoliday) {
            $routeName = 'پشوو';
            $todayRouteId = null;
        } else {
            $todayRouteId = $user->getTodayRouteId();
            if ($todayRouteId) {
                $routeObj = \App\Models\Route::find($todayRouteId);
                $routeName = $routeObj ? $routeObj->name : 'گشتی';
            } else {
                $routeName = 'پشوو';
            }
        }

        // Fetch today's route customers and visit completions
        $todayOrderCustomerIds = \App\Models\SalesOrder::where('salesman_id', $user->id)
            ->whereDate('created_at', $today)
            ->pluck('customer_id')
            ->toArray();

        $todayPaymentCustomerIds = \App\Models\CustomerPayment::where('collected_by', $user->id)
            ->whereDate('created_at', $today)
            ->pluck('customer_id')
            ->toArray();

        $todayRouteCustomers = [];

        // کڕیاری کاتی هەمیشە یەکەم بێت لە پلانی سەردانی ئەمڕۆ بۆ هەموو مەندوبەکان
        $tempCustomer = \App\Models\Customer::find(0);
        if ($tempCustomer) {
            $todayRouteCustomers[] = [
                'id' => 0,
                'name' => (string) $tempCustomer->name,
                'phone' => $tempCustomer->phone,
                'address' => $tempCustomer->address,
                'current_balance' => (int) $tempCustomer->current_balance,
                'visit_order' => 0,
                'visited' => in_array(0, $todayOrderCustomerIds) || in_array(0, $todayPaymentCustomerIds)
            ];
        }

        if ($todayRouteId) {
            $customers = \App\Models\Customer::where('route_id', $todayRouteId)
                ->where('id', '!=', 0)
                ->where('is_active', true)
                ->orderBy('visit_order')
                ->orderBy('name')
                ->select('id', 'name', 'phone', 'address', 'current_balance', 'visit_order')
                ->get();

            $orderIndex = 1;
            foreach ($customers as $customer) {
                $visitOrder = (int) $customer->visit_order;
                if ($visitOrder <= 0) {
                    $visitOrder = $orderIndex;
                }
                $todayRouteCustomers[] = [
                    'id' => (int) $customer->id,
                    'name' => (string) $customer->name,
                    'phone' => $customer->phone,
                    'address' => $customer->address,
                    'current_balance' => (int) $customer->current_balance,
                    'visit_order' => $visitOrder,
                    'visited' => in_array($customer->id, $todayOrderCustomerIds) || in_array($customer->id, $todayPaymentCustomerIds)
                ];
                $orderIndex++;
            }
        }

        // 2. Today's Sales Amount & Profit Units (1 Unit = 1,000 IQD profit, ONLY DELIVERED orders)
        $getDeliveredQuery = function () use ($user) {
            return \App\Models\SalesOrder::where('salesman_id', $user->id)
                ->where('status', \App\Models\SalesOrder::STATUS_DELIVERED);
        };

        $todayOrders = $getDeliveredQuery()
            ->where(function ($q) use ($today) {
                $q->whereDate('delivered_at', $today)
                  ->orWhere(function ($q2) use ($today) {
                      $q2->whereNull('delivered_at')->whereDate('created_at', $today);
                  });
            });

        $todaySalesAmount = (int) $todayOrders->sum('total_amount');
        $todayProfitSum = (int) $todayOrders->sum('total_profit');
        $todayUnits = (int) round($todayProfitSum / 1000);

        // 3. Last 7 Days Sales Amount & Profit Units (ONLY DELIVERED orders)
        $last7DaysOrders = $getDeliveredQuery()
            ->where(function ($q) use ($sevenDaysAgo) {
                $q->whereDate('delivered_at', '>=', $sevenDaysAgo)
                  ->orWhere(function ($q2) use ($sevenDaysAgo) {
                      $q2->whereNull('delivered_at')->whereDate('created_at', '>=', $sevenDaysAgo);
                  });
            });

        $last7DaysSalesAmount = (int) $last7DaysOrders->sum('total_amount');
        $last7DaysProfitSum = (int) $last7DaysOrders->sum('total_profit');
        $last7DaysUnits = (int) round($last7DaysProfitSum / 1000);

        // Month-to-date profit units (from 1st of current month until end of today, ONLY DELIVERED orders)
        $monthOrders = $getDeliveredQuery()
            ->where(function ($q) use ($startOfMonth, $endOfMonth) {
                $q->whereBetween('delivered_at', [$startOfMonth, $endOfMonth])
                  ->orWhere(function ($q2) use ($startOfMonth, $endOfMonth) {
                      $q2->whereNull('delivered_at')->whereBetween('created_at', [$startOfMonth, $endOfMonth]);
                  });
            });

        $monthProfitSum = (int) $monthOrders->sum('total_profit');
        $monthUnits = (int) round($monthProfitSum / 1000);

        // Previous month profit units (from 1st of last month to end of last month, ONLY DELIVERED orders)
        $lastMonthOrders = $getDeliveredQuery()
            ->where(function ($q) use ($startOfLastMonth, $endOfLastMonth) {
                $q->whereBetween('delivered_at', [$startOfLastMonth, $endOfLastMonth])
                  ->orWhere(function ($q2) use ($startOfLastMonth, $endOfLastMonth) {
                      $q2->whereNull('delivered_at')->whereBetween('created_at', [$startOfLastMonth, $endOfLastMonth]);
                  });
            });

        $lastMonthProfitSum = (int) $lastMonthOrders->sum('total_profit');
        $lastMonthUnits = (int) round($lastMonthProfitSum / 1000);

        // 4. Weekly Chart Data (Last 7 Days, ONLY DELIVERED orders)
        $weeklyChartData = [];
        for ($i = 6; $i >= 0; $i--) {
            $date = now()->subDays($i)->toDateString();
            $dayOrders = $getDeliveredQuery()
                ->where(function ($q) use ($date) {
                    $q->whereDate('delivered_at', $date)
                      ->orWhere(function ($q2) use ($date) {
                          $q2->whereNull('delivered_at')->whereDate('created_at', $date);
                      });
                });

            $daySales = (int) $dayOrders->sum('total_amount');
            $dayProfit = (int) $dayOrders->sum('total_profit');
            $dayUnits = (int) round($dayProfit / 1000);

            // Short Kurdish day names
            $dayNameMap = [
                'Mon' => 'دووشەممە',
                'Tue' => 'سێشەممە',
                'Wed' => 'چوارشەممە',
                'Thu' => 'پێنجشەممە',
                'Fri' => 'جومعە',
                'Sat' => 'شەممە',
                'Sun' => 'یەکشەممە',
            ];
            $englishDay = \Carbon\Carbon::parse($date)->format('D');
            $dayLabel = $dayNameMap[$englishDay] ?? $englishDay;

            $weeklyChartData[] = [
                'date' => $date,
                'label' => $dayLabel,
                'sales' => $daySales,
                'units' => $dayUnits,
            ];
        }

        // 5. New Customers added by salesman
        $newCustomersWeek = \App\Models\Customer::where('created_by', $user->id)
            ->whereBetween('created_at', [$startOfWeek, $endOfWeek])
            ->count();

        $newCustomersMonth = \App\Models\Customer::where('created_by', $user->id)
            ->whereBetween('created_at', [$startOfMonth, $endOfMonth])
            ->count();

        return response()->json([
            'message' => 'داشبۆردی مەندوب',
            'data' => [
                'route_name' => $routeName,
                'today_route_id' => $todayRouteId,
                'today_route_customers' => $todayRouteCustomers,
                'today_sales' => $todaySalesAmount,
                'today_units' => $todayUnits,
                'last_7_days_sales' => $last7DaysSalesAmount,
                'last_7_days_units' => $last7DaysUnits,
                'month_units' => $monthUnits,
                'last_month_units' => $lastMonthUnits,
                'new_customers_week' => $newCustomersWeek,
                'new_customers_month' => $newCustomersMonth,
                'weekly_chart_data' => $weeklyChartData,
            ]
        ]);
    }
}
