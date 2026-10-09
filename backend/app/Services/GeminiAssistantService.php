<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\CustomerPayment;
use App\Models\DriverCollection;
use App\Models\Product;
use App\Models\SalesOrder;
use App\Models\User;
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
     * چارەسەرکردنی پرسیاری ئەدمین لە ڕێگەی Gemini بە داتای فەرمی GARDI ERP
     */
    public function ask(string $userMessage, array $chatHistory = []): array
    {
        $apiKey = config('services.gemini.api_key') ?: env('GEMINI_API_KEY');
        $model = config('services.gemini.model', 'gemini-3.8-flash');

        // ١. کۆکردنەوەی داتاکانی ERP بە تەواوی هاوتا لەگەڵ داشبۆردی فەرمی ئەدمین (ReportController::dashboard)
        $erpContext = $this->buildAuthoritativeErpContext();

        // ئەگەر کلیل دیاری نەکرابوو لە .env، وەڵامێکی زیرەکی کوردی بە داتای فەرمی داشبۆرد دەدەینەوە
        if (empty($apiKey)) {
            $fallbackReply = $this->generateLocalSummaryResponse($userMessage, $erpContext);
            return [
                'reply' => $fallbackReply,
                'source' => 'local_fallback',
                'context_summary' => $erpContext['highlights'] ?? [],
            ];
        }

        // ٢. ئامادەکردنی پرۆمپتی سیستەم بە کوردی سۆرانی
        $systemInstruction = "تۆ یاریدەدەری ژمێریاری و دارایی ERPیت بۆ بەڕێوەبەر و خاوەن کار.\n"
            . "یاساکانی وەڵامدانەوە (زۆر گرنگ):\n"
            . "١. زۆر زۆر کورت، پوخت، و ڕاستەوخۆ وەڵام بدەوە (Executive Summary). بە هیچ شێوەیەک درێژدادڕی مەکە.\n"
            . "٢. تەنها و تەنها وەڵامی ئەو بەشە بدەوە کە لێت پرسیراوە. بۆ نموونە ئەگەر پرسیاری ئەمڕۆ کرا تەنها داتای ئەمڕۆ بنووسە، هەموو بەشەکانی تر مەهێنە.\n"
            . "٣. وەڵامەکەت بە گشتی لە ١ بۆ ٣ دێڕ زیاتر نەبێت.\n"
            . "٤. نرخ و ژمارەکان بە جیاکەرەوە بنووسە (وەک ٦٩٥،٥٠٠ دینار).\n"
            . "٥. هیچ پێشەکی و کۆتاییەکی ناپێویست مەنووسە؛ ڕاستەوخۆ بڕۆ سەر ژمارە و داتاکە.\n\n"
            . "داتای فەرمی داشبۆرد:\n"
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

        // ٤. ناردنی داواکاری بۆ Google Gemini API
        try {
            $endpoint = "https://generativelanguage.googleapis.com/v1beta/models/{$model}:generateContent?key={$apiKey}";

            $response = Http::timeout(25)
                ->withHeaders([
                    'Content-Type' => 'application/json',
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
                        'maxOutputTokens' => 1500,
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

            Log::warning('Gemini API Error: ' . $response->body());
        } catch (\Throwable $e) {
            Log::error('Gemini Exception: ' . $e->getMessage());
        }

        // ئەگەر پەیوەندی بە Gemini سەری نەگرت، وەڵام بە داتای فەرمی لۆکاڵی دەگەڕێتەوە
        $fallbackReply = $this->generateLocalSummaryResponse($userMessage, $erpContext);
        return [
            'reply' => $fallbackReply,
            'source' => 'local_fallback',
            'context_summary' => $erpContext['highlights'] ?? [],
        ];
    }

    /**
     * دروستکردنی پوختەی داتاکانی ERP ڕێک هاوتای داشبۆردی فەرمی (ReportController::dashboard)
     */
    protected function buildAuthoritativeErpContext(): array
    {
        $now = Carbon::now();
        $todayStr = $now->toDateString();
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

        // ١. فرۆش و قازانجی فەرمی ئەم مانگە (هاوتای کارتی داشبۆرد)
        $monthSales = (int) SalesOrder::whereIn('status', $activeStatuses)
            ->whereBetween('order_date', [$startOfMonth, $endOfMonth])
            ->sum('total_amount');

        $monthProfit = (int) SalesOrder::whereIn('status', $activeStatuses)
            ->whereBetween('order_date', [$startOfMonth, $endOfMonth])
            ->sum('total_profit');

        $monthOrdersCount = (int) SalesOrder::whereIn('status', $activeStatuses)
            ->whereBetween('order_date', [$startOfMonth, $endOfMonth])
            ->count();

        // فرۆش و قازانجی مانگی پێشوو
        $lastMonthSales = (int) SalesOrder::whereIn('status', $activeStatuses)
            ->whereBetween('order_date', [$startOfLastMonth, $endOfLastMonth])
            ->sum('total_amount');

        $lastMonthProfit = (int) SalesOrder::whereIn('status', $activeStatuses)
            ->whereBetween('order_date', [$startOfLastMonth, $endOfLastMonth])
            ->sum('total_profit');

        // ٢. فرۆش و قازانجی ئەمڕۆ
        $todayOrdersQuery = SalesOrder::whereIn('status', $activeStatuses)
            ->whereDate('order_date', $todayStr);

        $todayOrdersCount = (int) (clone $todayOrdersQuery)->count();
        $todaySales = (int) (clone $todayOrdersQuery)->sum('total_amount');
        $todayProfit = (int) (clone $todayOrdersQuery)->sum('total_profit');

        // ٣. قەرزی بازاڕ و کڕیاران (هاوتای کارتی داشبۆرد)
        $totalCustomerDebts = (int) Customer::sum('current_balance');
        $debtorsCount = (int) Customer::where('current_balance', '>', 0)->count();

        $topDebtors = Customer::where('current_balance', '>', 0)
            ->orderByDesc('current_balance')
            ->take(5)
            ->get(['name', 'phone', 'current_balance'])
            ->map(fn($c) => [
                'name' => $c->name,
                'phone' => $c->phone,
                'debt_amount' => (int) $c->current_balance,
            ])
            ->toArray();

        // ٤. پارەی لای شوفێر و کۆکراوەکان (هاوتای کارتی داشبۆرد)
        $totalCollectedByDrivers = (int) DB::table('delivery_trip_orders')
            ->where('status', 'DELIVERED')
            ->sum('received_amount');
        $totalPaidByDrivers = (int) DB::table('driver_collections')->sum('amount');
        $driversRemainingCash = max(0, $totalCollectedByDrivers - $totalPaidByDrivers);

        $monthlyCollected = (int) CustomerPayment::whereBetween('paid_at', [$startOfMonth, $endOfMonth])
            ->sum('amount');

        // ٥. کاڵا کەمبووەکانی کۆگا
        $lowStockReport = $this->reportService->getLowStockReport([]);
        $lowStockCount = count($lowStockReport);
        $criticalLowStock = collect($lowStockReport)
            ->take(5)
            ->map(fn($item) => [
                'product' => $item['product_name'] ?? 'نەزانراو',
                'warehouse' => $item['warehouse_name'] ?? 'کۆگا',
                'current_qty' => $item['quantity'] ?? 0,
                'min_level' => $item['min_stock_level'] ?? 0,
                'suggested_reorder' => $item['suggested_reorder'] ?? 0,
            ])
            ->toArray();

        // ٦. فرۆشی مەندوبەکان
        $salesmenReport = $this->reportService->getSalesBySalesmanReport([
            'start_date' => $startOfMonth,
            'end_date' => $endOfMonth,
        ]);
        $salesmenSummary = collect($salesmenReport['salesmen'] ?? [])
            ->map(fn($s) => [
                'name' => $s['salesman_name'] ?? '',
                'total_orders' => $s['total_orders'] ?? 0,
                'total_sales' => $s['total_sales'] ?? 0,
                'total_profit' => $s['total_profit'] ?? 0,
                'payments_collected' => $s['payments_collected'] ?? 0,
            ])
            ->toArray();

        return [
            'date_today' => $todayStr,
            'current_month' => $now->format('Y-m'),
            'today_sales' => [
                'total_orders' => $todayOrdersCount,
                'net_sales' => $todaySales,
                'net_profit' => $todayProfit,
            ],
            'month_sales' => [
                'total_orders' => $monthOrdersCount,
                'net_sales' => $monthSales,
                'net_profit' => $monthProfit,
                'last_month_sales' => $lastMonthSales,
                'last_month_profit' => $lastMonthProfit,
            ],
            'debts' => [
                'total_outstanding_debt' => $totalCustomerDebts,
                'debtors_count' => $debtorsCount,
                'top_debtors' => $topDebtors,
            ],
            'drivers' => [
                'remaining_cash' => $driversRemainingCash,
                'monthly_collected' => $monthlyCollected,
            ],
            'inventory' => [
                'low_stock_items_count' => $lowStockCount,
                'critical_items' => $criticalLowStock,
            ],
            'salesmen_performance' => $salesmenSummary,
            'highlights' => [
                'today_net_sales' => $todaySales,
                'today_profit' => $todayProfit,
                'month_net_sales' => $monthSales,
                'month_profit' => $monthProfit,
                'total_outstanding_debt' => $totalCustomerDebts,
                'drivers_remaining_cash' => $driversRemainingCash,
                'low_stock_count' => $lowStockCount,
            ],
        ];
    }

    /**
     * وەڵامدانەوەی زیرەک و زۆر کورت بەپێی جۆری پرسیارەکە بە بەکارهێنانی داتای فەرمی
     */
    protected function generateLocalSummaryResponse(string $query, array $context): string
    {
        $q = mb_strtolower(trim($query));

        $todaySales = number_format($context['today_sales']['net_sales'] ?? 0);
        $todayProfit = number_format($context['today_sales']['net_profit'] ?? 0);
        $todayOrders = $context['today_sales']['total_orders'] ?? 0;

        $monthSales = number_format($context['month_sales']['net_sales'] ?? 0);
        $monthProfit = number_format($context['month_sales']['net_profit'] ?? 0);
        $lastMonthSales = number_format($context['month_sales']['last_month_sales'] ?? 0);
        $lastMonthProfit = number_format($context['month_sales']['last_month_profit'] ?? 0);

        $totalDebt = number_format($context['debts']['total_outstanding_debt'] ?? 0);
        $debtorsCount = $context['debts']['debtors_count'] ?? 0;

        $lowStockCount = $context['inventory']['low_stock_items_count'] ?? 0;

        // ١. فرۆش و قازانجی ئەمڕۆ
        if (str_contains($q, 'ئەمڕۆ') || str_contains($q, 'امرو')) {
            return "📊 **فرۆش و قازانجی ئەمڕۆ:**\n"
                . "• فرۆش: **{$todaySales} دینار** ({$todayOrders} داواکاری)\n"
                . "• قازانج: **{$todayProfit} دینار**";
        }

        // ٢. قازانجی ئەم مانگە
        if (str_contains($q, 'قازانج')) {
            return "📈 **قازانجی ئەم مانگەتان:** **{$monthProfit} دینار**\n"
                . "(مانگی پێشوو: {$lastMonthProfit} د.ع | فرۆشی مانگ: {$monthSales} د.ع)";
        }

        // ٣. فرۆشی ئەم مانگە
        if (str_contains($q, 'فرۆش') && str_contains($q, 'مانگ')) {
            return "📈 **فرۆشتنی ئەم مانگەتان:** **{$monthSales} دینار**\n"
                . "(مانگی پێشوو: {$lastMonthSales} د.ع | قازانج: {$monthProfit} د.ع)";
        }

        // ٤. قەرزی کڕیاران و بازاڕ
        if (str_contains($q, 'قەرز') || str_contains($q, 'قەرزدار')) {
            $msg = "💳 **کۆی قەرزی بازاڕ:** **{$totalDebt} دینار** (لای {$debtorsCount} کڕیار)";
            if (!empty($context['debts']['top_debtors'])) {
                $top = $context['debts']['top_debtors'][0];
                $msg .= "\n• گەورەترین قەرزدار: **{$top['name']}** (" . number_format($top['debt_amount']) . " د.ع)";
            }
            return $msg;
        }

        // ٥. کۆگا و کەمیی کاڵاکان
        if (str_contains($q, 'کۆگا') || str_contains($q, 'کاڵا') || str_contains($q, 'مەخزەن')) {
            $msg = "📦 **کۆگا:** **{$lowStockCount} کاڵا** لە هێڵی سوورن و کەمبوونەتەوە.";
            if (!empty($context['inventory']['critical_items'])) {
                $items = collect($context['inventory']['critical_items'])->take(3)->pluck('product')->implode('، ');
                $msg .= "\n• لەوانە: {$items}";
            }
            return $msg;
        }

        // ٦. فرۆشی مەندوبەکان
        if (str_contains($q, 'مەندوب') || str_contains($q, 'مندوب')) {
            if (!empty($context['salesmen_performance'])) {
                $lines = [];
                foreach (array_slice($context['salesmen_performance'], 0, 3) as $s) {
                    $lines[] = "• **{$s['name']}**: " . number_format($s['total_sales']) . " د.ع فرۆش (" . number_format($s['total_profit']) . " د.ع قازانج)";
                }
                return "👥 **فرۆشی مەندوبەکان بۆ ئەم مانگە:**\n" . implode("\n", $lines);
            }
            return "👥 **مەندوبەکان:** هیچ فرۆشێکی مەندوب بۆ ئەم مانگە تۆمار نەکراوە.";
        }

        // ٧. وەڵامی کورت و پوخت بۆ پرسیاری گشتی
        return "📊 فرۆشی مانگ: **{$monthSales} د.ع** | قازانج: **{$monthProfit} د.ع**\n"
            . "💳 قەرزی بازاڕ: **{$totalDebt} د.ع** | کۆگا: **{$lowStockCount} کاڵا کەمە**";
    }
}
