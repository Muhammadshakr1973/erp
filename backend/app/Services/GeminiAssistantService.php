<?php

namespace App\Services;

use App\Models\Category;
use App\Models\Customer;
use App\Models\CustomerPayment;
use App\Models\DeliveryTrip;
use App\Models\DriverCollection;
use App\Models\Product;
use App\Models\PurchaseOrder;
use App\Models\SalesOrder;
use App\Models\Supplier;
use App\Models\User;
use App\Models\Warehouse;
use App\Models\WarehouseStock;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class GeminiAssistantService
{
    protected ReportService $reportService;

    public function __construct(ReportService $reportService)
    {
        $this->reportService = $reportService;
    }

    /**
     * چارەسەرکردنی پرسیاری ئەدمین لە ڕێگەی Gemini بە داتای فەرمی و دەستڕاگەیشتن بە هەموو سێکتەرەکانی GARDI ERP
     */
    public function ask(string $userMessage, array $chatHistory = []): array
    {
        try {
            $apiKey = $this->resolveApiKey();
            $model = $this->resolveModel();

            // ١. کۆکردنەوەی داتای فەرمی و دەستڕاگەیشتن بە هەموو سێکتەرەکانی ERP بە شێوەیەکی پارێزراو
            $erpContext = $this->buildAuthoritativeErpContext($userMessage);

            // ئەگەر کلیل دیاری نەکرابوو لە .env، وەڵامێکی زیرەکی کوردی بە داتای فەرمی لۆکاڵی دەدەینەوە
            if (empty($apiKey)) {
                $fallbackReply = $this->generateLocalSummaryResponse($userMessage, $erpContext);
                return [
                    'reply' => $fallbackReply,
                    'source' => 'local_fallback',
                    'context_summary' => $erpContext['highlights'] ?? [],
                ];
            }

            // ٢. ئامادەکردنی پرۆمپتی سیستەم بە کوردی سۆرانی بۆ دەستڕاگەیشتن بە تەواوی سێکتەرەکان
            $systemInstruction = "تۆ یاریدەدەری زیرەکی ژمێریاری، دارایی، کۆگا، و بەڕێوەبردنی GARDI ERPیت بۆ بەڕێوەبەر و خاوەن کار.\n"
                . "دەستت بە هەموو سێکتەرەکانی سیستەمەکە دەگات: فرۆش، قازانج، کڕیاران و قازانجی کڕیاران، مەندوبەکان بۆ ئەم مانگە و مانگی پێشوو، دابینکەرەکان و قەرزەکانیان، کۆگا و بەرهەمەکان، گەیاندن و شوفێران.\n\n"
                . "یاساکانی وەڵامدانەوە (زۆر گرنگ):\n"
                . "١. وەڵامەکانت زۆر ڕوون، بێ هەڵە، دروست، و بە خاڵ (Bullet points) بن بە زمانی کوردی سۆرانی.\n"
                . "٢. ئەگەر پرسیار لەسەر چەند تەوەرێک بوو (وەک: قازانجی کڕیاران لەم دوو مانگە، ژمارەی مەندوبەکان، و فرۆش و قازانجی هەر مەندوبێک لەم مانگە و مانگی پێشوو)، هەموو بەشەکانی پرسیارەکە بە تەواوی و بە وردی وەڵام بدەوە بەبێ لەبیرکردن.\n"
                . "٣. بڕە داراییەکان و ژمارەکان هەمیشە بە فاریزە (جیاکەرەوە) بنووسە (وەک: ٤٩١،٥٠٠ دینار یان 239,500 دینار).\n"
                . "٤. داتای مانگی ئێستا و مانگی پێشوو و کۆی هەردوو مانگ بە تەواوی لە داتای خوارەوە بەردەستە، بە وردی پیشانی بدە.\n"
                . "٥. ڕاستەوخۆ وەڵامی خاڵەکان بدەوە بەبێ پێشەکی درێژ و بەبێ دروشم.\n\n"
                . "داتای فەرمی هەموو سێکتەرەکانی GARDI ERP:\n"
                . json_encode($erpContext, JSON_UNESCAPED_UNICODE);

            // ٣. ڕێکخستنی پەیامەکانی پێشوو (Conversation History)
            $contents = [];
            foreach ($chatHistory as $msg) {
                $role = ($msg['role'] ?? '') === 'assistant' ? 'model' : 'user';
                $text = trim($msg['content'] ?? '');
                if (!empty($text)) {
                    $contents[] = [
                        'role' => $role,
                        'parts' => [['text' => $text]],
                    ];
                }
            }

            // زیادکردنی پرسیاری ئێستا
            $contents[] = [
                'role' => 'user',
                'parts' => [['text' => $userMessage]],
            ];

            // ٤. ناردنی داواکاری بۆ Google Gemini API (بە پشتگیری مۆدێلە بەردەستەکان)
            $modelsToTry = array_unique([$model, 'gemini-2.5-flash', 'gemini-1.5-flash', 'gemini-2.0-flash']);
            $googleError = null;

            foreach ($modelsToTry as $candidateModel) {
                try {
                    $endpoint = "https://generativelanguage.googleapis.com/v1beta/models/{$candidateModel}:generateContent?key={$apiKey}";

                    $response = Http::timeout(25)
                        ->withHeaders([
                            'Content-Type' => 'application/json',
                            'x-goog-api-key' => $apiKey,
                        ])
                        ->post($endpoint, [
                            'systemInstruction' => [
                                'parts' => [
                                    ['text' => $systemInstruction],
                                ],
                            ],
                            'contents' => $contents,
                            'generationConfig' => [
                                'temperature' => 0.2,
                                'maxOutputTokens' => 2000,
                            ],
                        ]);

                    if ($response->successful()) {
                        $data = $response->json();
                        $replyText = $data['candidates'][0]['content']['parts'][0]['text'] ?? null;

                        if (!empty($replyText)) {
                            return [
                                'reply' => trim($replyText),
                                'source' => 'gemini',
                                'context_summary' => $erpContext['highlights'] ?? [],
                            ];
                        }
                    }

                    $errBody = $response->json();
                    $googleError = $errBody['error']['message'] ?? $response->body();
                    Log::warning("Gemini API Error with model {$candidateModel}: " . $googleError);

                    if ($response->status() === 400 || $response->status() === 403) {
                        break;
                    }
                } catch (\Throwable $e) {
                    $googleError = $e->getMessage();
                    Log::error('Gemini Exception: ' . $e->getMessage());
                }
            }

            // ئەگەر پەیوەندی بە گووگڵ سەری نەگرت، وەڵام بە داتای فەرمی لۆکاڵی دەگەڕێتەوە لەگەڵ هۆکارەکەی
            $fallbackReply = $this->generateLocalSummaryResponse($userMessage, $erpContext);
            if (!empty($googleError)) {
                $fallbackReply .= "\n\n⚠️ *سەرنج: گووگڵ ئەم هەڵەیەی گەڕاندەوە: {$googleError}*";
            }

            return [
                'reply' => $fallbackReply,
                'source' => 'local_fallback',
                'context_summary' => $erpContext['highlights'] ?? [],
            ];
        } catch (\Throwable $e) {
            Log::error('GeminiAssistantService top-level exception: ' . $e->getMessage(), [
                'trace' => $e->getTraceAsString(),
            ]);

            $safeContext = [
                'customers_sector' => ['total_customers_count' => (int) Customer::count()],
                'highlights' => [],
            ];

            return [
                'reply' => $this->generateLocalSummaryResponse($userMessage, $safeContext),
                'source' => 'safe_fallback',
                'context_summary' => [],
            ];
        }
    }

    /**
     * دروستکردنی دەستڕاگەیشتن بە هەموو سێکتەرەکانی GARDI ERP بە داتای فەرمی و بە تەواوی بێ کەموکوڕی
     */
    protected function buildAuthoritativeErpContext(?string $query = null): array
    {
        $now = Carbon::now();
        $todayStr = $now->toDateString();
        $yesterdayStr = $now->copy()->subDay()->toDateString();
        $startOfMonth = $now->copy()->startOfMonth()->toDateString();
        $endOfMonth = $now->copy()->endOfMonth()->toDateString();

        $startOfLastMonth = $now->copy()->subMonth()->startOfMonth()->toDateString();
        $endOfLastMonth = $now->copy()->subMonth()->endOfMonth()->toDateString();

        $activeStatuses = [
            SalesOrder::STATUS_DELIVERED,
            SalesOrder::STATUS_CONFIRMED,
            'delivered',
            'confirmed',
        ];

        // ==========================================
        // سێکتەری ١: فرۆش و قازانجی گشتی و بەراوردی کاتەکان
        // ==========================================
        try {
            $todayOrdersQuery = SalesOrder::whereIn('status', $activeStatuses)
                ->whereDate('order_date', $todayStr);
            $todayOrdersCount = (int) (clone $todayOrdersQuery)->count();
            $todaySales = (int) (clone $todayOrdersQuery)->sum('total_amount');
            $todayProfit = (int) (clone $todayOrdersQuery)->sum('total_profit');

            $yesterdayOrdersQuery = SalesOrder::whereIn('status', $activeStatuses)
                ->whereDate('order_date', $yesterdayStr);
            $yesterdaySales = (int) (clone $yesterdayOrdersQuery)->sum('total_amount');
            $yesterdayProfit = (int) (clone $yesterdayOrdersQuery)->sum('total_profit');

            $monthOrdersQuery = SalesOrder::whereIn('status', $activeStatuses)
                ->whereBetween('order_date', [$startOfMonth, $endOfMonth]);
            $monthOrdersCount = (int) (clone $monthOrdersQuery)->count();
            $monthSales = (int) (clone $monthOrdersQuery)->sum('total_amount');
            $monthProfit = (int) (clone $monthOrdersQuery)->sum('total_profit');

            $lastMonthOrdersQuery = SalesOrder::whereIn('status', $activeStatuses)
                ->whereBetween('order_date', [$startOfLastMonth, $endOfLastMonth]);
            $lastMonthOrdersCount = (int) (clone $lastMonthOrdersQuery)->count();
            $lastMonthSales = (int) (clone $lastMonthOrdersQuery)->sum('total_amount');
            $lastMonthProfit = (int) (clone $lastMonthOrdersQuery)->sum('total_profit');

            // کۆی فرۆش و قازانجی هەردوو مانگەکە (ئەم مانگە + مانگی ڕابردوو)
            $twoMonthsSales = $monthSales + $lastMonthSales;
            $twoMonthsProfit = $monthProfit + $lastMonthProfit;
        } catch (\Throwable $e) {
            Log::warning('Gemini context sales overview error: ' . $e->getMessage());
            $todayOrdersCount = 0; $todaySales = 0; $todayProfit = 0;
            $yesterdaySales = 0; $yesterdayProfit = 0;
            $monthOrdersCount = 0; $monthSales = 0; $monthProfit = 0;
            $lastMonthOrdersCount = 0; $lastMonthSales = 0; $lastMonthProfit = 0;
            $twoMonthsSales = 0; $twoMonthsProfit = 0;
        }

        // ==========================================
        // سێکتەری ٢: کڕیاران و قازانجی کڕیاران (Customer Profitability)
        // ==========================================
        $getCustomerProfitAgg = function ($startDate, $endDate, $limit = 10) use ($activeStatuses) {
            try {
                return SalesOrder::whereIn('sales_orders.status', $activeStatuses)
                    ->whereBetween('sales_orders.order_date', [$startDate, $endDate])
                    ->join('customers', 'sales_orders.customer_id', '=', 'customers.id')
                    ->select(
                        'sales_orders.customer_id',
                        'customers.name as customer_name',
                        'customers.phone as customer_phone',
                        DB::raw('COUNT(sales_orders.id) as orders_count'),
                        DB::raw('COALESCE(SUM(sales_orders.total_amount), 0) as total_sales'),
                        DB::raw('COALESCE(SUM(sales_orders.total_profit), 0) as total_profit')
                    )
                    ->groupBy('sales_orders.customer_id', 'customers.name', 'customers.phone')
                    ->orderByDesc('total_profit')
                    ->limit($limit)
                    ->get()
                    ->map(fn($row) => [
                        'customer_id'   => (int) $row->customer_id,
                        'customer_name' => $row->customer_name,
                        'phone'         => $row->customer_phone ?? '',
                        'orders_count'  => (int) $row->orders_count,
                        'total_sales'   => (int) $row->total_sales,
                        'total_profit'  => (int) $row->total_profit,
                    ])
                    ->toArray();
            } catch (\Throwable $e) {
                Log::warning('Gemini context getCustomerProfitAgg error: ' . $e->getMessage());
                return [];
            }
        };

        try {
            $topCustomersThisMonth = $getCustomerProfitAgg($startOfMonth, $endOfMonth, 10);
            $topCustomersLastMonth = $getCustomerProfitAgg($startOfLastMonth, $endOfLastMonth, 10);
            $topCustomersTwoMonths = $getCustomerProfitAgg($startOfLastMonth, $endOfMonth, 10);

            // قەرزی کڕیاران و ژمارەی گشتی
            $totalCustomersCount = (int) Customer::count();
            $totalCustomerDebts = (int) Customer::sum('current_balance');
            $debtorsCount = (int) Customer::where('current_balance', '>', 0)->count();

            $topDebtors = Customer::where('current_balance', '>', 0)
                ->orderByDesc('current_balance')
                ->take(10)
                ->get(['id', 'name', 'phone', 'current_balance'])
                ->map(fn($c) => [
                    'name' => $c->name,
                    'phone' => $c->phone ?? '',
                    'debt_amount' => (int) $c->current_balance,
                ])
                ->toArray();
        } catch (\Throwable $e) {
            Log::warning('Gemini context customer sector error: ' . $e->getMessage());
            $topCustomersThisMonth = [];
            $topCustomersLastMonth = [];
            $topCustomersTwoMonths = [];
            $totalCustomersCount = 0;
            $totalCustomerDebts = 0;
            $debtorsCount = 0;
            $topDebtors = [];
        }

        // ==========================================
        // سێکتەری ٣: مەندوبەکان و ئەدای کار بۆ ئەم مانگە و مانگی پێشوو
        // ==========================================
        try {
            $salesmenUsers = User::whereHas('role', fn($r) => $r->where('name', 'salesman'))
                ->orWhereHas('salesOrders')
                ->get(['id', 'name', 'phone']);

            $thisMonthSalesmenAgg = SalesOrder::whereIn('status', $activeStatuses)
                ->whereBetween('order_date', [$startOfMonth, $endOfMonth])
                ->selectRaw('salesman_id, COUNT(*) as orders_count, COALESCE(SUM(total_amount), 0) as total_sales, COALESCE(SUM(total_profit), 0) as total_profit')
                ->groupBy('salesman_id')
                ->get()
                ->keyBy('salesman_id');

            $lastMonthSalesmenAgg = SalesOrder::whereIn('status', $activeStatuses)
                ->whereBetween('order_date', [$startOfLastMonth, $endOfLastMonth])
                ->selectRaw('salesman_id, COUNT(*) as orders_count, COALESCE(SUM(total_amount), 0) as total_sales, COALESCE(SUM(total_profit), 0) as total_profit')
                ->groupBy('salesman_id')
                ->get()
                ->keyBy('salesman_id');

            $thisMonthPaymentsAgg = CustomerPayment::whereBetween('paid_at', [$startOfMonth, $endOfMonth])
                ->selectRaw('collected_by, COALESCE(SUM(amount), 0) as total_collected')
                ->groupBy('collected_by')
                ->get()
                ->keyBy('collected_by');

            $lastMonthPaymentsAgg = CustomerPayment::whereBetween('paid_at', [$startOfLastMonth, $endOfLastMonth])
                ->selectRaw('collected_by, COALESCE(SUM(amount), 0) as total_collected')
                ->groupBy('collected_by')
                ->get()
                ->keyBy('collected_by');

            $salesmenComprehensive = $salesmenUsers->map(function ($s) use ($thisMonthSalesmenAgg, $lastMonthSalesmenAgg, $thisMonthPaymentsAgg, $lastMonthPaymentsAgg) {
                $tm = $thisMonthSalesmenAgg->get($s->id);
                $lm = $lastMonthSalesmenAgg->get($s->id);
                $tmPay = $thisMonthPaymentsAgg->get($s->id);
                $lmPay = $lastMonthPaymentsAgg->get($s->id);

                $tmSales = (int) ($tm->total_sales ?? 0);
                $tmProfit = (int) ($tm->total_profit ?? 0);
                $tmOrders = (int) ($tm->orders_count ?? 0);

                $lmSales = (int) ($lm->total_sales ?? 0);
                $lmProfit = (int) ($lm->total_profit ?? 0);
                $lmOrders = (int) ($lm->orders_count ?? 0);

                return [
                    'id' => $s->id,
                    'name' => $s->name,
                    'phone' => $s->phone ?? '',
                    'this_month' => [
                        'orders_count' => $tmOrders,
                        'sales' => $tmSales,
                        'profit' => $tmProfit,
                        'collected' => (int) ($tmPay->total_collected ?? 0),
                    ],
                    'last_month' => [
                        'orders_count' => $lmOrders,
                        'sales' => $lmSales,
                        'profit' => $lmProfit,
                        'collected' => (int) ($lmPay->total_collected ?? 0),
                    ],
                    'two_months_combined' => [
                        'total_sales' => $tmSales + $lmSales,
                        'total_profit' => $tmProfit + $lmProfit,
                        'total_orders' => $tmOrders + $lmOrders,
                    ],
                ];
            })->values()->toArray();
        } catch (\Throwable $e) {
            Log::warning('Gemini context salesmen sector error: ' . $e->getMessage());
            $salesmenComprehensive = [];
        }

        // ==========================================
        // سێکتەری ٤: دابینکەرەکان و کڕین (Suppliers & Purchasing)
        // ==========================================
        try {
            $totalSuppliersCount = (int) Supplier::count();
            $totalSupplierDebts = (int) Supplier::sum('current_balance');
            $suppliersWithDebtCount = (int) Supplier::where('current_balance', '>', 0)->count();

            $topSuppliersOwed = Supplier::where('current_balance', '>', 0)
                ->orderByDesc('current_balance')
                ->take(10)
                ->get(['id', 'name', 'phone', 'current_balance'])
                ->map(fn($s) => [
                    'name' => $s->name,
                    'phone' => $s->phone ?? '',
                    'debt_amount' => (int) $s->current_balance,
                ])
                ->toArray();

            $thisMonthPurchases = (int) PurchaseOrder::whereIn('status', [PurchaseOrder::STATUS_RECEIVED, PurchaseOrder::STATUS_CONFIRMED, 'received', 'confirmed'])
                ->whereBetween('created_at', [$startOfMonth . ' 00:00:00', $endOfMonth . ' 23:59:59'])
                ->sum('total_amount');

            $pendingPurchasesCount = (int) PurchaseOrder::whereIn('status', [PurchaseOrder::STATUS_DRAFT, PurchaseOrder::STATUS_CONFIRMED, 'draft', 'ordered'])->count();
        } catch (\Throwable $e) {
            Log::warning('Gemini context supplier sector error: ' . $e->getMessage());
            $totalSuppliersCount = 0;
            $totalSupplierDebts = 0;
            $suppliersWithDebtCount = 0;
            $topSuppliersOwed = [];
            $thisMonthPurchases = 0;
            $pendingPurchasesCount = 0;
        }

        // ==========================================
        // سێکتەری ٥: کۆگا، بەهای کاڵاکان، و کەمیی مەخزەن (Warehouse & Inventory)
        // چاککراوە: ناوی خشتەی فەرمی warehouse_stock ـە نەک warehouse_stocks
        // ==========================================
        try {
            $totalProductsCount = (int) Product::count();
            $totalWarehousesCount = (int) Warehouse::count();

            // بەهای کۆگا بە نرخی تێچوون (تێکڕای سەرمایەی کاڵا) لە خشتەی warehouse_stock
            $inventoryValuation = (int) DB::table('warehouse_stock')
                ->join('products', 'warehouse_stock.product_id', '=', 'products.id')
                ->selectRaw('COALESCE(SUM(warehouse_stock.quantity * products.cost_price), 0) as total_val')
                ->value('total_val');

            $lowStockReport = $this->reportService->getLowStockReport([]);
            $lowStockItems = $lowStockReport['items'] ?? [];
            $lowStockCount = (int) ($lowStockReport['summary']['total_low_stock_items'] ?? count($lowStockItems));
            $criticalLowStock = collect($lowStockItems)
                ->take(10)
                ->map(fn($item) => [
                    'product' => $item['product_name'] ?? 'نەزانراو',
                    'warehouse' => $item['warehouse_name'] ?? 'کۆگا',
                    'current_qty' => $item['quantity'] ?? 0,
                    'min_level' => $item['min_stock_level'] ?? 0,
                    'suggested_reorder' => $item['suggested_reorder'] ?? 0,
                ])
                ->values()
                ->toArray();

            // پڕقازانجترین کاڵاکانی ئەم مانگە
            $topProfitableProducts = DB::table('sales_order_items')
                ->join('sales_orders', 'sales_order_items.sales_order_id', '=', 'sales_orders.id')
                ->join('products', 'sales_order_items.product_id', '=', 'products.id')
                ->whereIn('sales_orders.status', $activeStatuses)
                ->whereBetween('sales_orders.order_date', [$startOfMonth, $endOfMonth])
                ->select(
                    'products.name as product_name',
                    DB::raw('SUM(sales_order_items.quantity) as units_sold'),
                    DB::raw('COALESCE(SUM(sales_order_items.line_total), 0) as total_sales'),
                    DB::raw('COALESCE(SUM(sales_order_items.profit), 0) as total_profit')
                )
                ->groupBy('products.name')
                ->orderByDesc('total_profit')
                ->limit(10)
                ->get()
                ->toArray();
        } catch (\Throwable $e) {
            Log::warning('Gemini context warehouse sector error: ' . $e->getMessage());
            $totalProductsCount = $totalProductsCount ?? (int) Product::count();
            $totalWarehousesCount = $totalWarehousesCount ?? (int) Warehouse::count();
            $inventoryValuation = 0;
            $lowStockCount = 0;
            $criticalLowStock = [];
            $topProfitableProducts = [];
        }

        // ==========================================
        // سێکتەری ٦: گەیاندن و پارەی دەستی شوفێران (Delivery & Drivers)
        // ==========================================
        try {
            $totalCollectedByDrivers = (int) DB::table('delivery_trip_orders')
                ->where('status', 'DELIVERED')
                ->sum('received_amount');
            $totalPaidByDrivers = (int) DB::table('driver_collections')->sum('amount');
            $driversRemainingCash = max(0, $totalCollectedByDrivers - $totalPaidByDrivers);

            $monthlyCustomerCollected = (int) CustomerPayment::whereBetween('paid_at', [$startOfMonth, $endOfMonth])
                ->sum('amount');

            $deliveryTripsThisMonth = (int) DeliveryTrip::whereBetween('trip_date', [$startOfMonth, $endOfMonth])->count();
            $activeTripsCount = (int) DeliveryTrip::whereIn('status', [DeliveryTrip::STATUS_PLANNED, DeliveryTrip::STATUS_IN_PROGRESS, 'planned', 'in_progress'])->count();
        } catch (\Throwable $e) {
            Log::warning('Gemini context delivery sector error: ' . $e->getMessage());
            $driversRemainingCash = 0;
            $monthlyCustomerCollected = 0;
            $deliveryTripsThisMonth = 0;
            $activeTripsCount = 0;
        }

        // ==========================================
        // سێکتەری ٧: گەڕانی تایبەت بە پرسیار ئەگەر کەس یان کاڵایەکی دیاریکراو ناوبرا
        // ==========================================
        $focusedSearchResult = null;
        try {
            $focusedSearchResult = $this->searchSpecificEntity($query);
        } catch (\Throwable $e) {
            Log::warning('Gemini context searchSpecificEntity error: ' . $e->getMessage());
        }

        return [
            'date_today' => $todayStr,
            'current_month' => $now->format('Y-m'),
            'last_month' => $now->copy()->subMonth()->format('Y-m'),

            // سێکتەری فرۆش و قازانج
            'sales_and_profit_overview' => [
                'today' => [
                    'orders_count' => $todayOrdersCount,
                    'net_sales' => $todaySales,
                    'net_profit' => $todayProfit,
                ],
                'yesterday' => [
                    'net_sales' => $yesterdaySales,
                    'net_profit' => $yesterdayProfit,
                ],
                'this_month' => [
                    'orders_count' => $monthOrdersCount,
                    'net_sales' => $monthSales,
                    'net_profit' => $monthProfit,
                ],
                'last_month' => [
                    'orders_count' => $lastMonthOrdersCount,
                    'net_sales' => $lastMonthSales,
                    'net_profit' => $lastMonthProfit,
                ],
                'two_months_combined' => [
                    'total_sales' => $twoMonthsSales,
                    'total_profit' => $twoMonthsProfit,
                ],
            ],

            // سێکتەری کڕیاران و قازانجی کڕیاران
            'customers_sector' => [
                'total_customers_count' => $totalCustomersCount,
                'total_market_debt' => $totalCustomerDebts,
                'debtors_count' => $debtorsCount,
                'top_debtors' => $topDebtors,
                'top_profitable_customers_last_two_months' => $topCustomersTwoMonths,
                'top_profitable_customers_this_month' => $topCustomersThisMonth,
                'top_profitable_customers_last_month' => $topCustomersLastMonth,
            ],

            // سێکتەری مەندوبەکان
            'salesmen_sector' => [
                'total_salesmen_count' => count($salesmenComprehensive),
                'salesmen_performance' => $salesmenComprehensive,
            ],

            // سێکتەری دابینکەرەکان و کڕین
            'suppliers_sector' => [
                'total_suppliers_count' => $totalSuppliersCount,
                'total_debts_to_suppliers' => $totalSupplierDebts,
                'suppliers_with_debt_count' => $suppliersWithDebtCount,
                'top_suppliers_owed' => $topSuppliersOwed,
                'this_month_purchases_amount' => $thisMonthPurchases,
                'pending_purchase_orders_count' => $pendingPurchasesCount,
            ],

            // سێکتەری کۆگا و بەرهەمەکان
            'warehouse_and_products_sector' => [
                'total_products_count' => $totalProductsCount,
                'total_warehouses_count' => $totalWarehousesCount,
                'inventory_cost_valuation' => $inventoryValuation,
                'low_stock_items_count' => $lowStockCount,
                'critical_low_stock_items' => $criticalLowStock,
                'top_profitable_products' => $topProfitableProducts,
            ],

            // سێکتەری شوفێران و گەیاندن
            'delivery_and_drivers_sector' => [
                'drivers_remaining_cash' => $driversRemainingCash,
                'monthly_collected_cash' => $monthlyCustomerCollected,
                'trips_this_month_count' => $deliveryTripsThisMonth,
                'active_trips_count' => $activeTripsCount,
            ],

            // ئەنجامی گەڕانی ڕاستەوخۆ بەپێی دەقی پرسیار
            'focused_search_result' => $focusedSearchResult,

            'highlights' => [
                'today_net_sales' => $todaySales,
                'today_profit' => $todayProfit,
                'month_net_sales' => $monthSales,
                'month_profit' => $monthProfit,
                'last_month_sales' => $lastMonthSales,
                'last_month_profit' => $lastMonthProfit,
                'total_outstanding_debt' => $totalCustomerDebts,
                'drivers_remaining_cash' => $driversRemainingCash,
                'low_stock_count' => $lowStockCount,
            ],
        ];
    }

    /**
     * گەڕان بۆ دۆزینەوەی کڕیار یان کاڵای تایبەت ئەگەر ناوەکەی لە پرسیاردا هەبێت
     */
    protected function searchSpecificEntity(?string $query): ?array
    {
        if (empty($query)) {
            return null;
        }

        $cleaned = trim($query);
        // ئەگەر دەقی پرسیار کورت بوو، تێپەڕی بکە
        if (mb_strlen($cleaned) < 2) {
            return null;
        }

        // پشکنینی کڕیار
        $matchedCustomer = Customer::where('name', 'like', "%{$cleaned}%")
            ->orWhere('phone', 'like', "%{$cleaned}%")
            ->first(['id', 'name', 'phone', 'current_balance']);

        if ($matchedCustomer) {
            $customerSales = SalesOrder::where('customer_id', $matchedCustomer->id)
                ->whereIn('status', [SalesOrder::STATUS_DELIVERED, SalesOrder::STATUS_CONFIRMED, 'delivered', 'confirmed'])
                ->selectRaw('COUNT(*) as total_orders, COALESCE(SUM(total_amount), 0) as total_sales, COALESCE(SUM(total_profit), 0) as total_profit')
                ->first();

            return [
                'type' => 'customer',
                'name' => $matchedCustomer->name,
                'phone' => $matchedCustomer->phone,
                'current_debt' => (int) $matchedCustomer->current_balance,
                'total_orders' => (int) ($customerSales->total_orders ?? 0),
                'total_sales' => (int) ($customerSales->total_sales ?? 0),
                'total_profit' => (int) ($customerSales->total_profit ?? 0),
            ];
        }

        // پشکنینی کاڵا
        $matchedProduct = Product::where('name', 'like', "%{$cleaned}%")
            ->orWhere('sku', 'like', "%{$cleaned}%")
            ->orWhere('barcode', 'like', "%{$cleaned}%")
            ->first();

        if ($matchedProduct) {
            $stockTotal = (int) DB::table('warehouse_stock')
                ->where('product_id', $matchedProduct->id)
                ->sum('quantity');

            return [
                'type' => 'product',
                'name' => $matchedProduct->name,
                'sku' => $matchedProduct->sku,
                'barcode' => $matchedProduct->barcode ?? '',
                'cost_price' => (int) $matchedProduct->cost_price,
                'price_n1' => (int) $matchedProduct->price_n1,
                'total_stock' => $stockTotal,
            ];
        }

        return null;
    }

    /**
     * وەڵامدانەوەی لۆکاڵی پێشکەوتوو بۆ هەموو سێکتەرەکان لە کاتی نەبوونی کلیل یان پەیوەندی
     */
    protected function generateLocalSummaryResponse(string $query, array $context): string
    {
        $q = mb_strtolower(trim($query));

        $hasCustomer = str_contains($q, 'کڕیار') || str_contains($q, 'کریار') || str_contains($q, 'مشتەری');
        $hasSalesman = str_contains($q, 'مەندوب') || str_contains($q, 'مندوب');
        $hasTwoMonths = str_contains($q, 'دوو مانگ') || str_contains($q, 'مانگی ڕابردوو') || str_contains($q, 'مانگی پێشوو');

        // ١. ئەگەر هەردوو پرسیاری کڕیار و مەندوب پێکەوە کرابێت
        if ($hasCustomer && $hasSalesman) {
            $lines = [];

            // بەشی کڕیار
            $totalCust = number_format($context['customers_sector']['total_customers_count'] ?? 0);
            $lines[] = "• **کۆی گشتی کڕیاران:** **{$totalCust} کڕیار** لە سیستەمدا تۆمارکراوە.";

            $topCust = $context['customers_sector']['top_profitable_customers_last_two_months'][0] ?? null;
            if ($topCust) {
                $profitStr = number_format($topCust['total_profit']);
                $salesStr = number_format($topCust['total_sales']);
                $lines[] = "• **زۆرترین قازانجی کڕیار لەم دوو مانگەدا:**\n  كڕیار **{$topCust['customer_name']}** بووە بە **{$profitStr} دینار قازانج** (کۆی کڕینی: {$salesStr} دینار لە {$topCust['orders_count']} داواکاری).";
            }

            // بەشی مەندوبەکان
            $salesmen = $context['salesmen_sector']['salesmen_performance'] ?? [];
            $salesmenCount = count($salesmen);
            $lines[] = "• **مەندوبەکان ({$salesmenCount} مەندوبمان هەیە):**";

            foreach ($salesmen as $s) {
                $name = $s['name'];
                $tmSales = number_format($s['this_month']['sales']);
                $tmProfit = number_format($s['this_month']['profit']);
                $lmSales = number_format($s['last_month']['sales']);
                $lmProfit = number_format($s['last_month']['profit']);

                $lines[] = "  - **{$name}:**\n    - ئەم مانگە: فرۆش: **{$tmSales} دینار** | قازانج: **{$tmProfit} دینار**\n    - مانگی پێشوو: فرۆش: **{$lmSales} دینار** | قازانج: **{$lmProfit} دینار**";
            }

            return implode("\n\n", $lines);
        }

        // ٢. پرسیاری تایبەت بە کڕیاران (وەک: چەند کڕیارمان هەیە؟ کڕیاری بەقازانج، قەرزی کڕیاران)
        if ($hasCustomer) {
            $totalCust = number_format($context['customers_sector']['total_customers_count'] ?? 0);
            $debtorsCount = number_format($context['customers_sector']['debtors_count'] ?? 0);
            $totalDebt = number_format($context['customers_sector']['total_market_debt'] ?? 0);

            $list = $hasTwoMonths
                ? ($context['customers_sector']['top_profitable_customers_last_two_months'] ?? [])
                : ($context['customers_sector']['top_profitable_customers_this_month'] ?? []);

            $lines = [
                "👥 **ئاماری کڕیارانی GARDI ERP:**",
                "• **کۆی گشتی کڕیاران:** **{$totalCust} کڕیار** تۆمارکراوە لە سیستەمدا.",
                "• **کڕیارانی قەرزدار:** **{$debtorsCount} کڕیار** قەرزیان لایە.",
                "• **کۆی گشتی قەرزی بازاڕ:** **{$totalDebt} دینار**ە.",
            ];

            if (!empty($list)) {
                $top = $list[0];
                $periodText = $hasTwoMonths ? "لەم دوو مانگەدا" : "لەم مانگەدا";
                $lines[] = "\n👑 **بەقازانجترین کڕیار {$periodText}:**";
                $lines[] = "• **{$top['customer_name']}** | قازانج: **" . number_format($top['total_profit']) . " دینار** (فرۆش: " . number_format($top['total_sales']) . " د.ع لە {$top['orders_count']} داواکاری)";

                if (count($list) > 1) {
                    $lines[] = "\n📊 **کڕیارە بەقازانجەکانی تر:**";
                    foreach (array_slice($list, 1, 3) as $c) {
                        $lines[] = "• **{$c['customer_name']}**: " . number_format($c['total_profit']) . " د.ع قازانج";
                    }
                }
            }

            if (!empty($context['customers_sector']['top_debtors'])) {
                $topDebtor = $context['customers_sector']['top_debtors'][0];
                $lines[] = "\n💳 **گەورەترین قەرزداری کڕیاران:**";
                $lines[] = "• **{$topDebtor['name']}**: **" . number_format($topDebtor['debt_amount']) . " دینار** قەرز.";
            }

            return implode("\n", $lines);
        }

        // ٣. پرسیاری مەندوبەکان بە تەنها
        if ($hasSalesman) {
            $salesmen = $context['salesmen_sector']['salesmen_performance'] ?? [];
            $salesmenCount = count($salesmen);
            $lines = ["👥 **{$salesmenCount} مەندوبمان هەیە:**"];

            foreach ($salesmen as $s) {
                $name = $s['name'];
                $tmSales = number_format($s['this_month']['sales']);
                $tmProfit = number_format($s['this_month']['profit']);
                $lmSales = number_format($s['last_month']['sales']);
                $lmProfit = number_format($s['last_month']['profit']);

                if ($hasTwoMonths) {
                    $lines[] = "• **{$name}**:\n  - ئەم مانگە: فرۆش: **{$tmSales} د.ع** | قازانج: **{$tmProfit} د.ع**\n  - مانگی پێشوو: فرۆش: **{$lmSales} د.ع** | قازانج: **{$lmProfit} د.ع**";
                } else {
                    $lines[] = "• **{$name}**: فرۆش: **{$tmSales} د.ع** | قازانج: **{$tmProfit} د.ع** ({$s['this_month']['orders_count']} داواکاری)";
                }
            }
            return implode("\n\n", $lines);
        }

        // ٤. دابینکەرەکان و کڕین
        if (str_contains($q, 'دابینکەر') || str_contains($q, 'موەرید') || str_contains($q, 'کڕین') || str_contains($q, 'کرین')) {
            $totalSupDebts = number_format($context['suppliers_sector']['total_debts_to_suppliers'] ?? 0);
            $purchases = number_format($context['suppliers_sector']['this_month_purchases_amount'] ?? 0);
            $supCount = $context['suppliers_sector']['total_suppliers_count'] ?? 0;

            $msg = "🏢 **دابینکەرەکان و کڕین:**\n"
                . "• کۆی قەرزی دابینکەران لەسەرمان: **{$totalSupDebts} دینار** (بۆ {$supCount} دابینکەر)\n"
                . "• کۆی کڕینی ئەم مانگە: **{$purchases} دینار**";

            if (!empty($context['suppliers_sector']['top_suppliers_owed'])) {
                $top = $context['suppliers_sector']['top_suppliers_owed'][0];
                $msg .= "\n• گەورەترین قەرزی دابینکەر: **{$top['name']}** (" . number_format($top['debt_amount']) . " د.ع)";
            }
            return $msg;
        }

        // ٥. کۆگا و بەهای سەرمایە و کەمی کاڵا
        if (str_contains($q, 'کۆگا') || str_contains($q, 'کاڵا') || str_contains($q, 'مەخزەن') || str_contains($q, 'سەرمایە')) {
            $lowStockCount = $context['warehouse_and_products_sector']['low_stock_items_count'] ?? 0;
            $valuation = number_format($context['warehouse_and_products_sector']['inventory_cost_valuation'] ?? 0);
            $prodCount = $context['warehouse_and_products_sector']['total_products_count'] ?? 0;
            $wareCount = $context['warehouse_and_products_sector']['total_warehouses_count'] ?? 0;

            $msg = "📦 **کۆگا و سەرمایەی کاڵاکان:**\n"
                . "• کۆی جۆری کاڵاکان: **{$prodCount} بەرهەم** (لە {$wareCount} کۆگا)\n"
                . "• کۆی بەهای کاڵای کۆگاکان (تێچوون): **{$valuation} دینار**\n"
                . "• کاڵا کەمبووەکان (هێڵی سوور): **{$lowStockCount} کاڵا**";

            if (!empty($context['warehouse_and_products_sector']['critical_low_stock_items'])) {
                $items = collect($context['warehouse_and_products_sector']['critical_low_stock_items'])->take(3)->pluck('product')->implode('، ');
                $msg .= "\n• کەمبووەکان: {$items}";
            }
            return $msg;
        }

        // ٦. شوفێر و پارەی دەست
        if (str_contains($q, 'شوفێر') || str_contains($q, 'شۆفێر') || str_contains($q, 'گەشت')) {
            $driverCash = number_format($context['delivery_and_drivers_sector']['drivers_remaining_cash'] ?? 0);
            $trips = $context['delivery_and_drivers_sector']['trips_this_month_count'] ?? 0;
            return "🚚 **شوفێران و گەیاندن:**\n• پارەی ماوەی لای شوفێران: **{$driverCash} دینار**\n• کۆی گەشتەکانی ئەم مانگە: **{$trips} گەشت**";
        }

        // ٧. قەرزی بازاڕ
        if (str_contains($q, 'قەرز') || str_contains($q, 'قەرزدار')) {
            $totalDebt = number_format($context['customers_sector']['total_market_debt'] ?? 0);
            $debtorsCount = $context['customers_sector']['debtors_count'] ?? 0;
            $msg = "💳 **کۆی قەرزی بازاڕ:** **{$totalDebt} دینار** (لای {$debtorsCount} کڕیار)";
            if (!empty($context['customers_sector']['top_debtors'])) {
                $top = $context['customers_sector']['top_debtors'][0];
                $msg .= "\n• گەورەترین قەرزدار: **{$top['name']}** (" . number_format($top['debt_amount']) . " د.ع)";
            }
            return $msg;
        }

        // ٨. فرۆش و قازانجی ئەمڕۆ
        if (str_contains($q, 'ئەمڕۆ') || str_contains($q, 'امرو')) {
            $todaySales = number_format($context['sales_and_profit_overview']['today']['net_sales'] ?? 0);
            $todayProfit = number_format($context['sales_and_profit_overview']['today']['net_profit'] ?? 0);
            $todayOrders = $context['sales_and_profit_overview']['today']['orders_count'] ?? 0;

            return "📊 **فرۆش و قازانجی ئەمڕۆ:**\n"
                . "• فرۆش: **{$todaySales} دینار** ({$todayOrders} داواکاری)\n"
                . "• قازانج: **{$todayProfit} دینار**";
        }

        // ٩. پوختەی گشتی دارایی و فرۆش
        $monthSales = number_format($context['sales_and_profit_overview']['this_month']['net_sales'] ?? 0);
        $monthProfit = number_format($context['sales_and_profit_overview']['this_month']['net_profit'] ?? 0);
        $lastMonthSales = number_format($context['sales_and_profit_overview']['last_month']['net_sales'] ?? 0);
        $lastMonthProfit = number_format($context['sales_and_profit_overview']['last_month']['net_profit'] ?? 0);

        return "📈 **پوختەی دارایی و فرۆش:**\n"
            . "• فرۆشی ئەم مانگە: **{$monthSales} د.ع** | قازانج: **{$monthProfit} د.ع**\n"
            . "• فرۆشی مانگی پێشوو: **{$lastMonthSales} د.ع** | قازانج: **{$lastMonthProfit} د.ع**\n"
            . "💳 قەرزی بازاڕ: **" . number_format($context['customers_sector']['total_market_debt'] ?? 0) . " د.ع** | کۆگا: **" . ($context['warehouse_and_products_sector']['low_stock_items_count'] ?? 0) . " کاڵا کەمە**";
    }
}
