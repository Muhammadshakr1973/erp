<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\SalesOrder;
use App\Models\Customer;
use App\Models\CustomerPayment;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
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
    
    public function supplierDebts(Request $request): JsonResponse
    {
        $query = \App\Models\SupplierLedger::with('supplier')->orderByDesc('created_at');

        if ($request->has('supplier_id') && $request->supplier_id != '') {
            $query->where('supplier_id', $request->supplier_id);
        }

        if ($request->has('start_date') && $request->start_date != '') {
            $query->whereDate('created_at', '>=', $request->start_date);
        }

        if ($request->has('end_date') && $request->end_date != '') {
            $query->whereDate('created_at', '<=', $request->end_date);
        }

        if ($request->has('entry_type') && $request->entry_type != '') {
            $query->where('entry_type', $request->entry_type);
        }

        $ledgers = $query->get();

        return response()->json([
            'message' => 'ڕاپۆرتی قەرزی کۆمپانیاکان',
            'data' => $ledgers
        ]);
    }
}
