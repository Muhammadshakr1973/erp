<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\Product;
use App\Models\SalesOrder;
use App\Models\User;
use Illuminate\Support\Carbon;
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

        // ١. کۆکردنەوەی پوختەی داتاکانی داتابەیس بە شێوەیەکی فەرمی لە ڕێگەی ReportService
        $erpContext = $this->buildAuthoritativeErpContext();

        // ئەگەر کلیلەکە دیاری نەکرابوو لە .env، وەڵامێکی زیرەکی لۆکاڵی پێشکەش بکە بە داتای فەرمی
        if (empty($apiKey)) {
            $fallbackReply = $this->generateLocalSummaryResponse($userMessage, $erpContext);
            return [
                'reply' => $fallbackReply,
                'source' => 'local_fallback',
                'context_summary' => $erpContext['highlights'] ?? [],
            ];
        }

        // ٢. ئامادەکردنی پرۆمپتی سیستم بە زمانی کوردی سۆرانی
        $systemInstruction = "تۆ یاریدەدەری زیرەکی دەستکردی سیستەمی ژمێریاری و کۆگای (GARDI ERP)یت تایبەت بە خاوەن کار و بەڕێوەبەر (Admin / Business Owner).\n"
            . "ئەرکی تۆ: وەڵامدانەوەی پرسیارەکانی خاوەن کارە بە شێوەیەکی زۆر دڵنیا، ڕێکخراو، و ژمێریارییانە بە زمانی کوردی سۆرانی (Kurdish Sorani).\n"
            . "یاساکانی وەڵامدانەوە:\n"
            . "١. تەنها و تەنها پشت بەم داتایە ببەستە کە لە داتابەیسی سیستەمەکەوە لە خوارەوە بۆت نێردراوە. هەرگیز ژمارە یان داتای خەیاڵی لە خۆتەوە دروست مەکە.\n"
            . "٢. نرخ و بڕە پارەکان بە جیاکەرەوەی هەزارەکان (،) بنووسە، وەک (١،٢٥٠،٠٠٠ دینار).\n"
            . "٣. لە کۆتایی هەموو وەڵامێکدا ئەگەر پێویست بوو ڕێنمایی یان سەرنجی ژمێریاری کورت پێشکەش بە بەڕێوەبەر بکە.\n"
            . "٤. ئەگەر بەڕێوەبەر پرسیاری کرد کە لەناو داتاکاندا نەبوو، بە ئەدەبەوە بڵێ کە ئەو زانیارییە لەم ڕاپۆرتەدا بەردەست نییە.\n\n"
            . "داتای ڕاستەقینەی داتابەیسی GARDI ERP:\n"
            . json_encode($erpContext, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);

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
                        'temperature' => 0.3,
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

        // ئەگەر هەڵەیەک ڕوویدا لە پەیوەندی بە گووگڵ، داتای ڕاستەقینەی لۆکاڵی دەگەڕێنینەوە
        $fallbackReply = $this->generateLocalSummaryResponse($userMessage, $erpContext);
        return [
            'reply' => $fallbackReply,
            'source' => 'local_fallback',
            'context_summary' => $erpContext['highlights'] ?? [],
        ];
    }

    /**
     * دروستکردنی پوختەی داتاکانی ERP بۆ کۆنتێکستی بۆتەکە
     */
    protected function buildAuthoritativeErpContext(): array
    {
        $now = Carbon::now();
        $todayStr = $now->toDateString();
        $startOfMonth = $now->copy()->startOfMonth()->toDateString();

        // فرۆشی ئەمڕۆ
        $todaySales = $this->reportService->getSalesReport([
            'start_date' => $todayStr,
            'end_date' => $todayStr,
        ]);

        // فرۆشی ئەم مانگە
        $monthSales = $this->reportService->getSalesReport([
            'start_date' => $startOfMonth,
            'end_date' => $todayStr,
        ]);

        // قازانجی ئەم مانگە
        $monthProfit = $this->reportService->getProfitReport([
            'start_date' => $startOfMonth,
            'end_date' => $todayStr,
        ]);

        // قەرزی کڕیاران
        $debtsReport = $this->reportService->getCustomerDebtsReport([
            'has_debt_only' => true,
        ]);

        // کەمی کاڵاکانی کۆگا
        $lowStockReport = $this->reportService->getLowStockReport([]);

        // فرۆشی مەندوبەکان
        $salesmenReport = $this->reportService->getSalesBySalesmanReport([
            'start_date' => $startOfMonth,
            'end_date' => $todayStr,
        ]);

        // گرنگترین ٥ کڕیاری قەرزدار
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

        // گرنگترین ٥ کاڵا کە کەمبوونەتەوە
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

        // پوختەی مەندوبەکان
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
                'total_orders' => $todaySales['summary']['total_orders_count'] ?? 0,
                'delivered_orders' => $todaySales['summary']['total_delivered_count'] ?? 0,
                'net_sales' => $todaySales['summary']['total_net_sales'] ?? 0,
                'net_profit' => $todaySales['summary']['total_profit_amount'] ?? 0,
            ],
            'month_sales' => [
                'total_orders' => $monthSales['summary']['total_orders_count'] ?? 0,
                'delivered_orders' => $monthSales['summary']['total_delivered_count'] ?? 0,
                'net_sales' => $monthSales['summary']['total_net_sales'] ?? 0,
                'gross_profit' => $monthProfit['summary']['total_profit_amount'] ?? 0,
                'margin_percentage' => $monthProfit['summary']['profit_margin_percentage'] ?? 0,
            ],
            'debts' => [
                'total_customers_with_debt' => $debtsReport['summary']['customers_with_debt'] ?? 0,
                'total_outstanding_debt' => $debtsReport['summary']['total_outstanding_debt'] ?? 0,
                'top_debtors' => $topDebtors,
            ],
            'inventory' => [
                'low_stock_items_count' => count($lowStockReport),
                'critical_items' => $criticalLowStock,
            ],
            'salesmen_performance' => $salesmenSummary,
            'highlights' => [
                'today_net_sales' => $todaySales['summary']['total_net_sales'] ?? 0,
                'today_profit' => $todaySales['summary']['total_profit_amount'] ?? 0,
                'month_net_sales' => $monthSales['summary']['total_net_sales'] ?? 0,
                'total_outstanding_debt' => $debtsReport['summary']['total_outstanding_debt'] ?? 0,
                'low_stock_count' => count($lowStockReport),
            ],
        ];
    }

    /**
     * گەڕانەوەی پوختەی زیرەک بەبێ ئینتەرنێت یان لە کاتی نەبوونی کلیلی API
     */
    protected function generateLocalSummaryResponse(string $query, array $context): string
    {
        $todaySales = number_format($context['today_sales']['net_sales'] ?? 0);
        $todayProfit = number_format($context['today_sales']['net_profit'] ?? 0);
        $todayOrders = $context['today_sales']['total_orders'] ?? 0;

        $monthSales = number_format($context['month_sales']['net_sales'] ?? 0);
        $monthProfit = number_format($context['month_sales']['gross_profit'] ?? 0);

        $totalDebt = number_format($context['debts']['total_outstanding_debt'] ?? 0);
        $debtorsCount = $context['debts']['total_customers_with_debt'] ?? 0;

        $lowStockCount = $context['inventory']['low_stock_items_count'] ?? 0;

        $msg = "سڵاو بەڕێز خاوەن کار، ئەمە پوختەی زانیارییە ژمێریاری و کۆگاییەکانی سیستەمی GARDI ERPـە:\n\n";
        $msg .= "📊 **فرۆش و قازانجی ئەمڕۆ:**\n";
        $msg .= "• ژمارەی داواکارییەکان: {$todayOrders}\n";
        $msg .= "• کۆی داواکارییەکانی ئەمڕۆ: {$todaySales} دینار\n";
        $msg .= "• قازانجی پوختەی ئەمڕۆ: {$todayProfit} دینار\n\n";

        $msg .= "📈 **فرۆش و قازانجی ئەم مانگە:**\n";
        $msg .= "• کۆی فرۆشی مانگ: {$monthSales} دینار\n";
        $msg .= "• قازانجی پوختەی مانگ: {$monthProfit} دینار\n\n";

        $msg .= "💳 **قەرزی کڕیاران:**\n";
        $msg .= "• کۆی گشتی قەرزەکان: {$totalDebt} دینار (لای {$debtorsCount} کڕیار)\n\n";

        $msg .= "📦 **بارودۆخی کۆگا:**\n";
        $msg .= "• ژمارەی کاڵا کەمبووەکان: {$lowStockCount} کاڵا پێویستیان بە داواکردنەوەیە.\n\n";

        if (empty(config('services.gemini.api_key') ?: env('GEMINI_API_KEY'))) {
            $msg .= "💡 *تێبینی: بۆ چالاککردنی شیکاری وردی دەقی و گفتوگۆ بە زیرەکی دەستکرد، تکایە کلیلی `GEMINI_API_KEY` لە فایلی سێرڤەر (.env) دابنێ.*";
        }

        return $msg;
    }
}
