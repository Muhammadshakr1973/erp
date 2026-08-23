<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\SalesOrder;
use App\Models\Customer;
use App\Models\CustomerPayment;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Carbon;

class ReportController extends Controller
{
    /**
     * هێنانی داتای داشبۆردی سەرەکی (بۆ ئادمین و خاوەندارێت)
     */
    public function dashboard(): JsonResponse
    {
        // دیاریکردنی مانگی ئێستا
        $startOfMonth = Carbon::now()->startOfMonth();
        $endOfMonth = Carbon::now()->endOfMonth();

        // ١. کۆی فرۆشتنی ئەم مانگە (ئەو پسوڵانەی کە گەیەندراون یان تەواوبوون)
        $monthlySales = SalesOrder::whereIn('status', ['delivered', 'confirmed'])
            ->whereBetween('created_at', [$startOfMonth, $endOfMonth])
            ->sum('total_amount');

        // ٢. کۆی قازانجی ئەم مانگە
        $monthlyProfit = SalesOrder::whereIn('status', ['delivered', 'confirmed'])
            ->whereBetween('created_at', [$startOfMonth, $endOfMonth])
            ->sum('total_profit');

        // ٣. کۆی ئەو پارەیەی لای کڕیارەکانە (کۆی قەرزەکانمان لای خەڵک)
        $totalReceivables = Customer::sum('current_balance');

        // ٤. کۆی ئەو پارەیەی ئەم مانگە وەرگیراوە لە کڕیارەکانەوە
        $monthlyCollected = CustomerPayment::whereBetween('paid_at', [$startOfMonth->toDateString(), $endOfMonth->toDateString()])
            ->sum('amount');

        return response()->json([
            'message' => 'ئامارەکانی داشبۆرد',
            'data' => [
                'monthly_sales'     => $monthlySales,
                'monthly_profit'    => $monthlyProfit,
                'total_receivables' => $totalReceivables,
                'monthly_collected' => $monthlyCollected,
            ]
        ], 200);
    }
}
