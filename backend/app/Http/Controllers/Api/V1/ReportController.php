<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Customer;
use App\Models\CustomerPayment;
use App\Models\SalesOrder;
use App\Services\ReportService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class ReportController extends Controller
{
    public function __construct(
        protected ReportService $reportService
    ) {}

    /**
     * Dashboard KPI summary
     */
    public function dashboard(): JsonResponse
    {
        $startOfMonth = Carbon::now()->startOfMonth();
        $endOfMonth = Carbon::now()->endOfMonth();

        // 1. Monthly sales from confirmed/delivered orders
        $monthlySales = (int) SalesOrder::whereIn('status', [SalesOrder::STATUS_DELIVERED, SalesOrder::STATUS_CONFIRMED, 'delivered', 'confirmed'])
            ->whereBetween('created_at', [$startOfMonth, $endOfMonth])
            ->sum('total_amount');

        // 2. Monthly profit
        $monthlyProfit = (int) SalesOrder::whereIn('status', [SalesOrder::STATUS_DELIVERED, SalesOrder::STATUS_CONFIRMED, 'delivered', 'confirmed'])
            ->whereBetween('created_at', [$startOfMonth, $endOfMonth])
            ->sum('total_profit');

        // 3. Outstanding customer receivables
        $totalReceivables = (int) Customer::sum('current_balance');

        // 4. Monthly collections
        $monthlyCollected = (int) CustomerPayment::whereBetween('paid_at', [$startOfMonth->toDateString(), $endOfMonth->toDateString()])
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

    /**
     * Sales Report (ڕاپۆرتی فرۆشتن)
     */
    public function sales(Request $request): JsonResponse
    {
        $filters = $request->only([
            'start_date',
            'end_date',
            'customer_id',
            'salesman_id',
            'route_id',
            'warehouse_id',
            'status',
            'price_tier',
            'per_page',
            'page',
        ]);

        $report = $this->reportService->getSalesReport($filters);

        return response()->json([
            'message' => 'ڕاپۆرتی فرۆشتن',
            'data'    => $report,
        ], 200);
    }

    /**
     * Profit Report (ڕاپۆرتی قازانج)
     */
    public function profit(Request $request): JsonResponse
    {
        $filters = $request->only([
            'start_date',
            'end_date',
            'customer_id',
            'salesman_id',
            'route_id',
            'warehouse_id',
            'product_id',
            'category_id',
            'per_page',
            'page',
        ]);

        $report = $this->reportService->getProfitReport($filters);

        return response()->json([
            'message' => 'ڕاپۆرتی قازانج',
            'data'    => $report,
        ], 200);
    }

    /**
     * Sales by Salesman (فرۆشتن بەپێی مەندوب)
     */
    public function salesBySalesman(Request $request): JsonResponse
    {
        $filters = $request->only([
            'start_date',
            'end_date',
            'salesman_id',
            'warehouse_id',
        ]);

        $report = $this->reportService->getSalesBySalesmanReport($filters);

        return response()->json([
            'message' => 'ڕاپۆرتی فرۆشتن بەپێی مەندوب',
            'data'    => $report,
        ], 200);
    }

    /**
     * Customer Debts Report (قەرزی کڕیارەکان)
     */
    public function customerDebts(Request $request): JsonResponse
    {
        $filters = $request->only([
            'customer_id',
            'route_id',
            'start_date',
            'end_date',
            'entry_type',
            'has_debt_only',
            'per_page',
            'page',
        ]);

        $report = $this->reportService->getCustomerDebtsReport($filters);

        return response()->json([
            'message' => 'ڕاپۆرتی قەرزی کڕیارەکان',
            'summary' => $report['summary'],
            'data'    => $report['ledgers'] instanceof \Illuminate\Contracts\Pagination\LengthAwarePaginator
                ? $report['ledgers']->items()
                : $report['ledgers'],
            'pagination' => $report['ledgers'] instanceof \Illuminate\Contracts\Pagination\LengthAwarePaginator ? [
                'current_page' => $report['ledgers']->currentPage(),
                'last_page'    => $report['ledgers']->lastPage(),
                'per_page'     => $report['ledgers']->perPage(),
                'total'        => $report['ledgers']->total(),
            ] : null,
        ], 200);
    }

    /**
     * Supplier Debts Report (قەرزی کۆمپانیاکان)
     */
    public function supplierDebts(Request $request): JsonResponse
    {
        $filters = $request->only([
            'supplier_id',
            'start_date',
            'end_date',
            'entry_type',
            'has_debt_only',
            'per_page',
            'page',
        ]);

        $report = $this->reportService->getSupplierDebtsReport($filters);

        return response()->json([
            'message' => 'ڕاپۆرتی قەرزی کۆمپانیاکان',
            'summary' => $report['summary'],
            'data'    => $report['ledgers'] instanceof \Illuminate\Contracts\Pagination\LengthAwarePaginator
                ? $report['ledgers']->items()
                : $report['ledgers'],
            'pagination' => $report['ledgers'] instanceof \Illuminate\Contracts\Pagination\LengthAwarePaginator ? [
                'current_page' => $report['ledgers']->currentPage(),
                'last_page'    => $report['ledgers']->lastPage(),
                'per_page'     => $report['ledgers']->perPage(),
                'total'        => $report['ledgers']->total(),
            ] : null,
        ], 200);
    }

    /**
     * Payments History Report (مێژووی پارەدان)
     */
    public function paymentsHistory(Request $request): JsonResponse
    {
        $filters = $request->only([
            'type',
            'customer_id',
            'supplier_id',
            'salesman_id',
            'payment_method',
            'start_date',
            'end_date',
            'per_page',
            'page',
        ]);

        $report = $this->reportService->getPaymentsHistoryReport($filters);

        return response()->json([
            'message' => 'ڕاپۆرتی مێژووی پارەدان',
            'summary' => $report['summary'],
            'data'    => $report['payments']->items(),
            'pagination' => [
                'current_page' => $report['payments']->currentPage(),
                'last_page'    => $report['payments']->lastPage(),
                'per_page'     => $report['payments']->perPage(),
                'total'        => $report['payments']->total(),
            ],
        ], 200);
    }

    /**
     * Low Stock Report (کاڵا کەمبووەکان)
     */
    public function lowStock(Request $request): JsonResponse
    {
        $filters = $request->only([
            'warehouse_id',
            'category_id',
            'supplier_id',
        ]);

        $report = $this->reportService->getLowStockReport($filters);

        return response()->json([
            'message' => 'ڕاپۆرتی کاڵا کەمبووەکان',
            'data'    => $report,
        ], 200);
    }

    /**
     * Stock Movements Report (جوڵەی ستۆک)
     */
    public function stockMovements(Request $request): JsonResponse
    {
        $filters = $request->only([
            'warehouse_id',
            'product_id',
            'type',
            'start_date',
            'end_date',
            'per_page',
            'page',
        ]);

        $report = $this->reportService->getStockMovementsReport($filters);

        return response()->json([
            'message' => 'ڕاپۆرتی جوڵەی ستۆک',
            'data'    => $report,
        ], 200);
    }

    /**
     * Stock Transfers Report (گواستنەوەی کۆگاکان)
     */
    public function stockTransfers(Request $request): JsonResponse
    {
        $filters = $request->only([
            'from_warehouse_id',
            'to_warehouse_id',
            'status',
            'start_date',
            'end_date',
            'per_page',
            'page',
        ]);

        $report = $this->reportService->getStockTransfersReport($filters);

        return response()->json([
            'message' => 'ڕاپۆرتی گواستنەوەی کۆگاکان',
            'data'    => $report,
        ], 200);
    }
}
