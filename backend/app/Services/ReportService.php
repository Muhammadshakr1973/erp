<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\CustomerLedger;
use App\Models\CustomerPayment;
use App\Models\Product;
use App\Models\Route;
use App\Models\SalesOrder;
use App\Models\SalesOrderItem;
use App\Models\StockTransaction;
use App\Models\StockTransfer;
use App\Models\Supplier;
use App\Models\SupplierLedger;
use App\Models\SupplierPayment;
use App\Models\User;
use App\Models\Warehouse;
use App\Models\WarehouseStock;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class ReportService
{
    /**
     * ١. ڕاپۆرتی گشتگیری فرۆشتن (Sales Report)
     * Ultra-fast Authoritative sales data with single SQL aggregations and indexed joins.
     */
    public function getSalesReport(array $filters): array
    {
        $query = SalesOrder::query()
            ->with([
                'customer:id,name,phone,route_id,price_type',
                'customer.route:id,name',
                'salesman:id,name,phone',
                'warehouse:id,name'
            ]);

        $this->applySalesOrderFilters($query, $filters);

        // Single SQL query for complete summary metrics
        $summaryData = (clone $query)
            ->withoutEagerLoads()
            ->selectRaw("
                COUNT(*) as total_orders_count,
                SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) as total_delivered_count,
                COALESCE(SUM(subtotal), 0) as total_gross_amount,
                COALESCE(SUM(discount_amount), 0) as total_discount_amount,
                COALESCE(SUM(total_amount), 0) as total_net_amount,
                COALESCE(SUM(total_profit), 0) as total_profit_amount
            ", [SalesOrder::STATUS_DELIVERED])
            ->first();

        $totalOrdersCount = (int) ($summaryData->total_orders_count ?? 0);
        $totalDeliveredCount = (int) ($summaryData->total_delivered_count ?? 0);
        $totalGrossAmount = (int) ($summaryData->total_gross_amount ?? 0);
        $totalDiscountAmount = (int) ($summaryData->total_discount_amount ?? 0);
        $totalNetAmount = (int) ($summaryData->total_net_amount ?? 0);
        $totalProfitAmount = (int) ($summaryData->total_profit_amount ?? 0);
        $totalCostAmount = $totalNetAmount - $totalProfitAmount;
        $avgOrderValue = $totalOrdersCount > 0 ? (int) round($totalNetAmount / $totalOrdersCount) : 0;

        // Breakdown by Salesman (single joined query without pluck collection overhead)
        $bySalesman = (clone $query)
            ->leftJoin('users', 'sales_orders.salesman_id', '=', 'users.id')
            ->select(
                'sales_orders.salesman_id',
                DB::raw("COALESCE(users.name, 'نەزانراو') as salesman_name"),
                DB::raw('COUNT(*) as orders_count'),
                DB::raw('COALESCE(SUM(sales_orders.total_amount), 0) as total_sales'),
                DB::raw('COALESCE(SUM(sales_orders.total_profit), 0) as total_profit')
            )
            ->groupBy('sales_orders.salesman_id', 'users.name')
            ->get()
            ->map(fn($row) => [
                'salesman_id'   => $row->salesman_id,
                'salesman_name' => $row->salesman_name,
                'orders_count'  => (int) $row->orders_count,
                'total_sales'   => (int) $row->total_sales,
                'total_profit'  => (int) $row->total_profit,
            ]);

        // Breakdown by Route (single joined query)
        $byRoute = (clone $query)
            ->join('customers', 'sales_orders.customer_id', '=', 'customers.id')
            ->leftJoin('routes', 'customers.route_id', '=', 'routes.id')
            ->select(
                'customers.route_id',
                DB::raw("COALESCE(routes.name, 'بێ ڕێگا') as route_name"),
                DB::raw('COUNT(sales_orders.id) as orders_count'),
                DB::raw('COALESCE(SUM(sales_orders.total_amount), 0) as total_sales')
            )
            ->groupBy('customers.route_id', 'routes.name')
            ->get()
            ->map(fn($row) => [
                'route_id'     => $row->route_id,
                'route_name'   => $row->route_name,
                'orders_count' => (int) $row->orders_count,
                'total_sales'  => (int) $row->total_sales,
            ]);

        // Breakdown by Status
        $byStatus = (clone $query)
            ->select('status', DB::raw('COUNT(*) as count'), DB::raw('COALESCE(SUM(total_amount), 0) as total_amount'))
            ->groupBy('status')
            ->get()
            ->map(fn($row) => [
                'status'       => $row->status,
                'count'        => (int) $row->count,
                'total_amount' => (int) $row->total_amount,
            ]);

        // Paginate Orders List
        $perPage = (int) ($filters['per_page'] ?? 25);
        $page = (int) ($filters['page'] ?? 1);
        $paginated = $query->orderByDesc('order_date')->orderByDesc('id')->paginate($perPage, ['*'], 'page', $page);

        return [
            'summary' => [
                'total_orders_count'    => $totalOrdersCount,
                'total_delivered_count' => $totalDeliveredCount,
                'total_gross_amount'    => $totalGrossAmount,
                'total_discount_amount' => $totalDiscountAmount,
                'total_net_sales'       => $totalNetAmount,
                'total_cost_amount'     => $totalCostAmount,
                'total_profit_amount'   => $totalProfitAmount,
                'average_order_value'   => $avgOrderValue,
            ],
            'breakdown' => [
                'by_salesman' => $bySalesman,
                'by_route'    => $byRoute,
                'by_status'   => $byStatus,
            ],
            'orders' => $paginated,
        ];
    }

    /**
     * ٢. ڕاپۆرتی گشتگیری قازانج (Profit Report)
     * High performance database joins and single query aggregations using strictly historical snapshots.
     */
    public function getProfitReport(array $filters): array
    {
        $baseItemQuery = SalesOrderItem::query()
            ->join('sales_orders', 'sales_order_items.sales_order_id', '=', 'sales_orders.id')
            ->whereIn('sales_orders.status', [SalesOrder::STATUS_DELIVERED, SalesOrder::STATUS_CONFIRMED]);

        // Apply filters on baseItemQuery
        if (!empty($filters['start_date'])) {
            $baseItemQuery->whereDate('sales_orders.order_date', '>=', $filters['start_date']);
        }
        if (!empty($filters['end_date'])) {
            $baseItemQuery->whereDate('sales_orders.order_date', '<=', $filters['end_date']);
        }
        if (!empty($filters['customer_id'])) {
            $baseItemQuery->where('sales_orders.customer_id', $filters['customer_id']);
        }
        if (!empty($filters['salesman_id'])) {
            $baseItemQuery->where('sales_orders.salesman_id', $filters['salesman_id']);
        }
        if (!empty($filters['warehouse_id'])) {
            $baseItemQuery->where('sales_orders.warehouse_id', $filters['warehouse_id']);
        }
        if (!empty($filters['product_id'])) {
            $baseItemQuery->where('sales_order_items.product_id', $filters['product_id']);
        }
        if (!empty($filters['category_id'])) {
            $baseItemQuery->join('products as p_cat', 'sales_order_items.product_id', '=', 'p_cat.id')
                          ->where('p_cat.category_id', $filters['category_id']);
        }

        // Single aggregation query for profit KPIs
        $summaryData = (clone $baseItemQuery)
            ->selectRaw('
                COALESCE(SUM(sales_order_items.line_total), 0) as total_revenue,
                COALESCE(SUM(sales_order_items.quantity * sales_order_items.cost_price), 0) as total_cost,
                COALESCE(SUM(sales_order_items.profit), 0) as total_profit,
                COALESCE(SUM(sales_order_items.quantity), 0) as total_units_sold
            ')
            ->first();

        $totalRevenue = (int) ($summaryData->total_revenue ?? 0);
        $totalCost = (int) ($summaryData->total_cost ?? 0);
        $totalProfit = (int) ($summaryData->total_profit ?? 0);
        $totalUnitsSold = (int) ($summaryData->total_units_sold ?? 0);
        $profitMargin = $totalRevenue > 0 ? round(($totalProfit / $totalRevenue) * 100, 2) : 0.0;

        // Top Profitable Products (Direct SQL Group By with joins)
        $productBreakdown = (clone $baseItemQuery)
            ->join('products', 'sales_order_items.product_id', '=', 'products.id')
            ->leftJoin('categories', 'products.category_id', '=', 'categories.id')
            ->select(
                'sales_order_items.product_id',
                'products.name as product_name',
                'products.sku',
                DB::raw("COALESCE(categories.name, 'گشتی') as category_name"),
                DB::raw('SUM(sales_order_items.quantity) as units_sold'),
                DB::raw('SUM(sales_order_items.line_total) as total_revenue'),
                DB::raw('SUM(sales_order_items.quantity * sales_order_items.cost_price) as total_cost'),
                DB::raw('SUM(sales_order_items.profit) as total_profit')
            )
            ->groupBy('sales_order_items.product_id', 'products.name', 'products.sku', 'categories.name')
            ->orderByDesc('total_profit')
            ->limit(15)
            ->get()
            ->map(function ($row) {
                $revenue = (int) $row->total_revenue;
                $profit = (int) $row->total_profit;
                $margin = $revenue > 0 ? round(($profit / $revenue) * 100, 2) : 0.0;

                return [
                    'product_id'     => $row->product_id,
                    'product_name'   => $row->product_name ?? 'نەزانراو',
                    'sku'            => $row->sku ?? '',
                    'category_name'  => $row->category_name,
                    'units_sold'     => (int) $row->units_sold,
                    'total_revenue'  => $revenue,
                    'total_cost'     => (int) $row->total_cost,
                    'total_profit'   => $profit,
                    'margin_percent' => $margin,
                ];
            });

        // Top Profitable Categories (Direct SQL Group By)
        $categoryBreakdown = (clone $baseItemQuery)
            ->join('products as prd_cat', 'sales_order_items.product_id', '=', 'prd_cat.id')
            ->leftJoin('categories as cat_tbl', 'prd_cat.category_id', '=', 'cat_tbl.id')
            ->select(
                'cat_tbl.id as category_id',
                DB::raw("COALESCE(cat_tbl.name, 'بێ پۆل') as category_name"),
                DB::raw('SUM(sales_order_items.quantity) as units_sold'),
                DB::raw('SUM(sales_order_items.line_total) as total_revenue'),
                DB::raw('SUM(sales_order_items.profit) as total_profit')
            )
            ->groupBy('cat_tbl.id', 'cat_tbl.name')
            ->orderByDesc('total_profit')
            ->get()
            ->map(function ($row) {
                $revenue = (int) $row->total_revenue;
                $profit = (int) $row->total_profit;
                $margin = $revenue > 0 ? round(($profit / $revenue) * 100, 2) : 0.0;

                return [
                    'category_id'    => $row->category_id,
                    'category_name'  => $row->category_name,
                    'units_sold'     => (int) $row->units_sold,
                    'total_revenue'  => $revenue,
                    'total_profit'   => $profit,
                    'margin_percent' => $margin,
                ];
            });

        // Profit Breakdown by Salesman
        $orderQuery = SalesOrder::query()
            ->whereIn('status', [SalesOrder::STATUS_DELIVERED, SalesOrder::STATUS_CONFIRMED]);
        $this->applySalesOrderFilters($orderQuery, $filters);

        $salesmanBreakdown = (clone $orderQuery)
            ->leftJoin('users', 'sales_orders.salesman_id', '=', 'users.id')
            ->select(
                'sales_orders.salesman_id',
                DB::raw("COALESCE(users.name, 'نەزانراو') as salesman_name"),
                DB::raw('COALESCE(SUM(sales_orders.total_amount), 0) as total_revenue'),
                DB::raw('COALESCE(SUM(sales_orders.total_profit), 0) as total_profit')
            )
            ->groupBy('sales_orders.salesman_id', 'users.name')
            ->get()
            ->map(function ($row) {
                $revenue = (int) $row->total_revenue;
                $profit = (int) $row->total_profit;
                $margin = $revenue > 0 ? round(($profit / $revenue) * 100, 2) : 0.0;

                return [
                    'salesman_id'    => $row->salesman_id,
                    'salesman_name'  => $row->salesman_name,
                    'total_revenue'  => $revenue,
                    'total_profit'   => $profit,
                    'margin_percent' => $margin,
                ];
            });

        // Eager-loaded paginated items
        $itemQuery = SalesOrderItem::query()
            ->with([
                'product:id,name,sku,category_id',
                'product.category:id,name',
                'order:id,order_number,order_date,customer_id,salesman_id',
                'order.customer:id,name',
                'order.salesman:id,name'
            ])
            ->whereHas('order', function ($q) use ($filters) {
                $q->whereIn('status', [SalesOrder::STATUS_DELIVERED, SalesOrder::STATUS_CONFIRMED]);
                $this->applySalesOrderFilters($q, $filters);
            });

        if (!empty($filters['product_id'])) {
            $itemQuery->where('product_id', $filters['product_id']);
        }
        if (!empty($filters['category_id'])) {
            $itemQuery->whereHas('product', fn($q) => $q->where('category_id', $filters['category_id']));
        }

        $perPage = (int) ($filters['per_page'] ?? 25);
        $page = (int) ($filters['page'] ?? 1);
        $paginatedItems = $itemQuery->orderByDesc('id')->paginate($perPage, ['*'], 'page', $page);

        return [
            'summary' => [
                'total_revenue'          => $totalRevenue,
                'total_cost'             => $totalCost,
                'total_profit'           => $totalProfit,
                'total_units_sold'       => $totalUnitsSold,
                'profit_margin_percent'  => $profitMargin,
            ],
            'breakdown' => [
                'by_product'  => $productBreakdown,
                'by_category' => $categoryBreakdown,
                'by_salesman' => $salesmanBreakdown,
            ],
            'items' => $paginatedItems,
        ];
    }

    /**
     * ٣. فرۆشتن بەپێی مەندوب و ئەدای کار (Sales by Salesman Report)
     * High efficiency aggregated report.
     */
    public function getSalesBySalesmanReport(array $filters): array
    {
        $salesmenQuery = User::whereHas('role', fn($r) => $r->where('name', 'salesman'))
            ->orWhereHas('salesOrders');

        if (!empty($filters['salesman_id'])) {
            $salesmenQuery->where('id', $filters['salesman_id']);
        }

        $salesmen = $salesmenQuery->get();
        $startDate = !empty($filters['start_date']) ? $filters['start_date'] : Carbon::now()->startOfMonth()->toDateString();
        $endDate = !empty($filters['end_date']) ? $filters['end_date'] : Carbon::now()->endOfMonth()->toDateString();
        $salesmanIds = $salesmen->pluck('id');

        $startOfThisMonth = Carbon::now()->startOfMonth()->toDateString();
        $endOfThisMonth = Carbon::now()->endOfMonth()->toDateString();
        $startOfLastMonth = Carbon::now()->subMonth()->startOfMonth()->toDateString();
        $endOfLastMonth = Carbon::now()->subMonth()->endOfMonth()->toDateString();

        // Aggregated orders summary by salesman
        $ordersAggQuery = SalesOrder::whereIn('salesman_id', $salesmanIds)
            ->whereBetween('order_date', [$startDate, $endDate]);

        if (!empty($filters['warehouse_id'])) {
            $ordersAggQuery->where('warehouse_id', $filters['warehouse_id']);
        }

        $ordersAgg = (clone $ordersAggQuery)
            ->selectRaw("
                salesman_id,
                COUNT(*) as total_orders,
                SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) as delivered_orders,
                COALESCE(SUM(CASE WHEN status IN ('confirmed', 'delivered') THEN total_amount ELSE 0 END), 0) as total_sales,
                COALESCE(SUM(CASE WHEN status IN ('confirmed', 'delivered') THEN total_profit ELSE 0 END), 0) as total_profit
            ", [SalesOrder::STATUS_DELIVERED])
            ->groupBy('salesman_id')
            ->get()
            ->keyBy('salesman_id');

        // Aggregated last month profit by salesman
        $lastMonthOrdersAgg = SalesOrder::whereIn('salesman_id', $salesmanIds)
            ->whereBetween('order_date', [$startOfLastMonth, $endOfLastMonth])
            ->selectRaw("
                salesman_id,
                COALESCE(SUM(CASE WHEN status IN ('confirmed', 'delivered') THEN total_profit ELSE 0 END), 0) as total_profit
            ")
            ->groupBy('salesman_id')
            ->get()
            ->keyBy('salesman_id');

        // Payments aggregated by collector in period
        $paymentsAgg = CustomerPayment::whereIn('collected_by', $salesmanIds)
            ->whereBetween('paid_at', [$startDate, $endDate])
            ->selectRaw('collected_by, COALESCE(SUM(amount), 0) as total_collected')
            ->groupBy('collected_by')
            ->get()
            ->keyBy('collected_by');

        // Commission details if recorded
        $commissionsAgg = DB::table('salesman_commission_details')
            ->join('sales_orders', 'salesman_commission_details.sales_order_id', '=', 'sales_orders.id')
            ->whereIn('sales_orders.salesman_id', $salesmanIds)
            ->whereBetween('sales_orders.order_date', [$startDate, $endDate])
            ->selectRaw('sales_orders.salesman_id, COALESCE(SUM(salesman_commission_details.commission_amount), 0) as total_commission')
            ->groupBy('sales_orders.salesman_id')
            ->get()
            ->keyBy('salesman_id');

        $reportData = $salesmen->map(function ($salesman) use ($ordersAgg, $paymentsAgg, $commissionsAgg, $lastMonthOrdersAgg, $startOfThisMonth, $endOfThisMonth, $startOfLastMonth, $endOfLastMonth) {
            $ord = $ordersAgg->get($salesman->id);
            $totalOrders = (int) ($ord->total_orders ?? 0);
            $deliveredOrders = (int) ($ord->delivered_orders ?? 0);
            $totalSales = (int) ($ord->total_sales ?? 0);
            $totalProfit = (int) ($ord->total_profit ?? 0);

            $lastMonthOrd = $lastMonthOrdersAgg->get($salesman->id);
            $lastMonthProfit = (int) ($lastMonthOrd->total_profit ?? 0);

            $assignedRouteIds = DB::table('route_salesmen')
                ->where('salesman_id', $salesman->id)
                ->pluck('route_id')
                ->toArray();

            $thisMonthCustomers = (int) Customer::where(function ($q) use ($salesman, $assignedRouteIds) {
                    $q->where('created_by', $salesman->id);
                    if (!empty($assignedRouteIds)) {
                        $q->orWhereIn('route_id', $assignedRouteIds);
                    }
                })
                ->whereBetween(DB::raw('DATE(created_at)'), [$startOfThisMonth, $endOfThisMonth])
                ->count();

            $lastMonthCustomers = (int) Customer::where(function ($q) use ($salesman, $assignedRouteIds) {
                    $q->where('created_by', $salesman->id);
                    if (!empty($assignedRouteIds)) {
                        $q->orWhereIn('route_id', $assignedRouteIds);
                    }
                })
                ->whereBetween(DB::raw('DATE(created_at)'), [$startOfLastMonth, $endOfLastMonth])
                ->count();

            $rate = (float) ($salesman->commission_rate ?? 0);
            
            // Check if authoritative commission details exist, else use formula
            $commDetail = $commissionsAgg->get($salesman->id);
            if ($commDetail) {
                $estimatedCommission = (int) $commDetail->total_commission;
            } else {
                $estimatedCommission = (int) round(($totalProfit * $rate) / 100);
            }

            $paymentsCollected = (int) ($paymentsAgg->get($salesman->id)->total_collected ?? 0);
            $avgOrder = $totalOrders > 0 ? (int) round($totalSales / $totalOrders) : 0;

            return [
                'salesman_id'              => $salesman->id,
                'salesman_name'            => $salesman->name,
                'salesman_phone'           => $salesman->phone,
                'commission_rate'          => $rate,
                'total_orders'             => $totalOrders,
                'delivered_orders'         => $deliveredOrders,
                'total_sales'              => $totalSales,
                'total_profit'             => $totalProfit,
                'last_month_profit'        => $lastMonthProfit,
                'new_customers_this_month' => $thisMonthCustomers,
                'new_customers_last_month' => $lastMonthCustomers,
                'estimated_commission'     => $estimatedCommission,
                'payments_collected'       => $paymentsCollected,
                'average_order_value'      => $avgOrder,
            ];
        });

        $totalSalesAll = $reportData->sum('total_sales');
        $totalProfitAll = $reportData->sum('total_profit');
        $totalCommissionAll = $reportData->sum('estimated_commission');
        $totalCollectedAll = $reportData->sum('payments_collected');

        return [
            'summary' => [
                'total_salesmen'        => $reportData->count(),
                'total_sales_amount'    => $totalSalesAll,
                'total_profit_amount'   => $totalProfitAll,
                'total_commission'      => $totalCommissionAll,
                'total_collected_cash'  => $totalCollectedAll,
            ],
            'period' => [
                'start_date' => $startDate,
                'end_date'   => $endDate,
            ],
            'salesmen' => $reportData,
        ];
    }

    /**
     * ٤. ڕاپۆرتی قەرزی کڕیارەکان (Customer Debts & Ledger Reconciliation)
     */
    public function getCustomerDebtsReport(array $filters): array
    {
        // 1. Authoritative Customer Balances Summary (Single aggregated query)
        $customerQuery = Customer::query();

        if (!empty($filters['customer_id'])) {
            $customerQuery->where('id', $filters['customer_id']);
        }
        if (!empty($filters['route_id'])) {
            $customerQuery->where('route_id', $filters['route_id']);
        }
        if (!empty($filters['has_debt_only']) && filter_var($filters['has_debt_only'], FILTER_VALIDATE_BOOLEAN)) {
            $customerQuery->where('current_balance', '>', 0);
        }

        $custSummary = (clone $customerQuery)
            ->withoutEagerLoads()
            ->selectRaw('
                COUNT(*) as total_customers,
                SUM(CASE WHEN current_balance > 0 THEN 1 ELSE 0 END) as customers_with_debt,
                COALESCE(SUM(current_balance), 0) as total_outstanding_debt
            ')->first();

        $totalCustomersCount = (int) ($custSummary->total_customers ?? 0);
        $customersWithDebtCount = (int) ($custSummary->customers_with_debt ?? 0);
        $totalOutstandingDebt = (int) ($custSummary->total_outstanding_debt ?? 0);

        // 2. Ledger Entries Query
        $ledgerQuery = CustomerLedger::query()
            ->with(['customer:id,name,phone,route_id', 'customer.route:id,name', 'creator:id,name'])
            ->orderByDesc('created_at')
            ->orderByDesc('id');

        if (!empty($filters['customer_id'])) {
            $ledgerQuery->where('customer_id', $filters['customer_id']);
        }

        if (!empty($filters['route_id'])) {
            $ledgerQuery->whereHas('customer', fn($q) => $q->where('route_id', $filters['route_id']));
        }

        if (!empty($filters['start_date'])) {
            $ledgerQuery->whereDate('created_at', '>=', $filters['start_date']);
        }

        if (!empty($filters['end_date'])) {
            $ledgerQuery->whereDate('created_at', '<=', $filters['end_date']);
        }

        if (!empty($filters['entry_type']) && $filters['entry_type'] !== 'ALL') {
            $ledgerQuery->where('entry_type', $filters['entry_type']);
        }

        $ledgerSummary = (clone $ledgerQuery)
            ->withoutEagerLoads()
            ->selectRaw('
                COALESCE(SUM(debit), 0) as total_debit,
                COALESCE(SUM(credit), 0) as total_credit
            ')->first();

        $totalDebitInPeriod = (int) ($ledgerSummary->total_debit ?? 0);
        $totalCreditInPeriod = (int) ($ledgerSummary->total_credit ?? 0);

        $perPage = (int) ($filters['per_page'] ?? 30);
        $page = (int) ($filters['page'] ?? 1);
        $paginatedLedgers = $ledgerQuery->paginate($perPage, ['*'], 'page', $page);

        return [
            'summary' => [
                'total_customers'               => $totalCustomersCount,
                'customers_with_debt'           => $customersWithDebtCount,
                'total_outstanding_debt'        => $totalOutstandingDebt,
                'total_outstanding_receivables' => $totalOutstandingDebt, // compatibility alias
                'total_sales_on_credit'         => $totalDebitInPeriod,
                'total_payments_received'       => $totalCreditInPeriod,
            ],
            'ledgers' => $paginatedLedgers,
        ];
    }

    /**
     * ٥. ڕاپۆرتی قەرزی کۆمپانیا و دابینکەرەکان (Supplier Debts Report)
     */
    public function getSupplierDebtsReport(array $filters): array
    {
        $supplierQuery = Supplier::query();

        if (!empty($filters['supplier_id'])) {
            $supplierQuery->where('id', $filters['supplier_id']);
        }
        if (!empty($filters['has_debt_only']) && filter_var($filters['has_debt_only'], FILTER_VALIDATE_BOOLEAN)) {
            $supplierQuery->where('current_balance', '>', 0);
        }

        $supSummary = (clone $supplierQuery)
            ->withoutEagerLoads()
            ->selectRaw('
            COUNT(*) as total_suppliers,
            SUM(CASE WHEN current_balance > 0 THEN 1 ELSE 0 END) as suppliers_with_debt,
            COALESCE(SUM(current_balance), 0) as total_outstanding_payables
        ')->first();

        $totalSuppliers = (int) ($supSummary->total_suppliers ?? 0);
        $suppliersWithDebtCount = (int) ($supSummary->suppliers_with_debt ?? 0);
        $totalOutstandingPayables = (int) ($supSummary->total_outstanding_payables ?? 0);

        // Ledger
        $ledgerQuery = SupplierLedger::query()
            ->with(['supplier:id,name,phone,contact_person'])
            ->orderByDesc('created_at')
            ->orderByDesc('id');

        if (!empty($filters['supplier_id'])) {
            $ledgerQuery->where('supplier_id', $filters['supplier_id']);
        }

        if (!empty($filters['start_date'])) {
            $ledgerQuery->whereDate('created_at', '>=', $filters['start_date']);
        }

        if (!empty($filters['end_date'])) {
            $ledgerQuery->whereDate('created_at', '<=', $filters['end_date']);
        }

        if (!empty($filters['entry_type']) && $filters['entry_type'] !== 'ALL') {
            $ledgerQuery->where('entry_type', $filters['entry_type']);
        }

        $ledgerSummary = (clone $ledgerQuery)
            ->withoutEagerLoads()
            ->selectRaw('
            COALESCE(SUM(debit), 0) as total_debit,
            COALESCE(SUM(credit), 0) as total_credit
        ')->first();

        $totalDebitInPeriod = (int) ($ledgerSummary->total_debit ?? 0);
        $totalCreditInPeriod = (int) ($ledgerSummary->total_credit ?? 0);

        $perPage = (int) ($filters['per_page'] ?? 30);
        $page = (int) ($filters['page'] ?? 1);
        $paginatedLedgers = $ledgerQuery->paginate($perPage, ['*'], 'page', $page);

        return [
            'summary' => [
                'total_suppliers'            => $totalSuppliers,
                'suppliers_with_debt'        => $suppliersWithDebtCount,
                'total_outstanding_payable'  => $totalOutstandingPayables,
                'total_outstanding_payables' => $totalOutstandingPayables, // compatibility alias
                'total_purchases_on_credit'  => $totalDebitInPeriod,
                'total_payments_made'        => $totalCreditInPeriod,
            ],
            'ledgers' => $paginatedLedgers,
        ];
    }

    /**
     * ٦. ڕاپۆرتی مێژووی پارەدانەکان (Payments History Report)
     */
    public function getPaymentsHistoryReport(array $filters): array
    {
        $type = $filters['type'] ?? 'customer'; // 'customer' or 'supplier'

        if ($type === 'supplier') {
            $query = SupplierPayment::query()
                ->with(['supplier:id,name,phone', 'creator:id,name'])
                ->orderByDesc('paid_at')
                ->orderByDesc('id');

            if (!empty($filters['supplier_id'])) {
                $query->where('supplier_id', $filters['supplier_id']);
            }
            if (!empty($filters['start_date'])) {
                $query->whereDate('paid_at', '>=', $filters['start_date']);
            }
            if (!empty($filters['end_date'])) {
                $query->whereDate('paid_at', '<=', $filters['end_date']);
            }
            if (!empty($filters['payment_method'])) {
                $query->where('payment_method', strtolower($filters['payment_method']));
            }

            $summaryData = (clone $query)
                ->withoutEagerLoads()
                ->selectRaw("
                COUNT(*) as total_count,
                COALESCE(SUM(amount), 0) as total_amount,
                COALESCE(SUM(CASE WHEN LOWER(payment_method) = 'cash' THEN amount ELSE 0 END), 0) as cash_total,
                COALESCE(SUM(CASE WHEN LOWER(payment_method) = 'bank' THEN amount ELSE 0 END), 0) as bank_total,
                COALESCE(SUM(CASE WHEN LOWER(payment_method) = 'transfer' THEN amount ELSE 0 END), 0) as transfer_total
            ")->first();

            $totalCount = (int) ($summaryData->total_count ?? 0);
            $totalAmount = (int) ($summaryData->total_amount ?? 0);
            $cashTotal = (int) ($summaryData->cash_total ?? 0);
            $bankTotal = (int) ($summaryData->bank_total ?? 0);
            $transferTotal = (int) ($summaryData->transfer_total ?? 0);

            $perPage = (int) ($filters['per_page'] ?? 30);
            $page = (int) ($filters['page'] ?? 1);
            $paginated = $query->paginate($perPage, ['*'], 'page', $page);

            $transformedItems = $paginated->getCollection()->map(fn($payment) => [
                'id'             => $payment->id,
                'type'           => 'supplier',
                'party_id'       => $payment->supplier_id,
                'party_name'     => $payment->supplier?->name ?? 'N/A',
                'amount'         => (int) $payment->amount,
                'payment_method' => strtoupper($payment->payment_method),
                'paid_at'        => $payment->paid_at ? $payment->paid_at->format('Y-m-d') : '',
                'notes'          => $payment->notes,
                'reference'      => $payment->purchase_order_id ? 'پسوڵەی کڕین #' . $payment->purchase_order_id : 'قەرزی گشتی',
            ]);

            return [
                'summary' => [
                    'type'                  => 'supplier',
                    'total_payments_count'  => $totalCount,
                    'total_amount'          => $totalAmount,
                    'cash_amount'           => $cashTotal,
                    'bank_amount'           => $bankTotal,
                    'transfer_amount'       => $transferTotal,
                ],
                'payments' => $paginated->setCollection($transformedItems),
            ];
        }

        // Customer Payments (Default)
        $query = CustomerPayment::query()
            ->with(['customer:id,name,phone', 'collector:id,name', 'receiver:id,name'])
            ->orderByDesc('paid_at')
            ->orderByDesc('id');

        if (!empty($filters['customer_id'])) {
            $query->where('customer_id', $filters['customer_id']);
        }
        if (!empty($filters['salesman_id'])) {
            $query->where('collected_by', $filters['salesman_id']);
        }
        if (!empty($filters['start_date'])) {
            $query->whereDate('paid_at', '>=', $filters['start_date']);
        }
        if (!empty($filters['end_date'])) {
            $query->whereDate('paid_at', '<=', $filters['end_date']);
        }
        if (!empty($filters['payment_method'])) {
            $query->where('payment_method', strtoupper($filters['payment_method']));
        }

        $summaryData = (clone $query)
            ->withoutEagerLoads()
            ->selectRaw("
            COUNT(*) as total_count,
            COALESCE(SUM(amount), 0) as total_amount,
            COALESCE(SUM(CASE WHEN UPPER(payment_method) = 'CASH' THEN amount ELSE 0 END), 0) as cash_total,
            COALESCE(SUM(CASE WHEN UPPER(payment_method) = 'BANK' THEN amount ELSE 0 END), 0) as bank_total
        ")->first();

        $totalCount = (int) ($summaryData->total_count ?? 0);
        $totalAmount = (int) ($summaryData->total_amount ?? 0);
        $cashTotal = (int) ($summaryData->cash_total ?? 0);
        $bankTotal = (int) ($summaryData->bank_total ?? 0);

        $perPage = (int) ($filters['per_page'] ?? 30);
        $page = (int) ($filters['page'] ?? 1);
        $paginated = $query->paginate($perPage, ['*'], 'page', $page);

        $transformedItems = $paginated->getCollection()->map(fn($payment) => [
            'id'             => $payment->id,
            'type'           => 'customer',
            'party_id'       => $payment->customer_id,
            'party_name'     => $payment->customer?->name ?? 'N/A',
            'collected_by'   => $payment->collector?->name ?? 'ئۆفیس',
            'amount'         => (int) $payment->amount,
            'payment_method' => strtoupper($payment->payment_method),
            'paid_at'        => $payment->paid_at ? $payment->paid_at->format('Y-m-d') : '',
            'notes'          => $payment->notes,
            'reference'      => $payment->payment_number ?? ($payment->sales_order_id ? 'پسوڵەی فرۆشتن #' . $payment->sales_order_id : 'قەرزی گشتی'),
        ]);

        return [
            'summary' => [
                'type'                 => 'customer',
                'total_payments_count' => $totalCount,
                'total_amount'         => $totalAmount,
                'cash_amount'          => $cashTotal,
                'bank_amount'          => $bankTotal,
                'transfer_amount'      => 0,
            ],
            'payments' => $paginated->setCollection($transformedItems),
        ];
    }

    /**
     * ٧. ڕاپۆرتی کاڵا کەمبووەکان و پێویستی کڕین (Low Stock & Reorder Alert Report)
     */
    public function getLowStockReport(array $filters): array
    {
        $query = WarehouseStock::query()
            ->with(['product:id,name,sku,barcode,unit,cost_price,supplier_id,category_id', 'product.category:id,name', 'product.supplier:id,name', 'warehouse:id,name'])
            ->lowStock();

        if (!empty($filters['warehouse_id'])) {
            $query->where('warehouse_id', $filters['warehouse_id']);
        }

        if (!empty($filters['category_id'])) {
            $query->whereHas('product', fn($p) => $p->where('category_id', $filters['category_id']));
        }

        if (!empty($filters['supplier_id'])) {
            $query->whereHas('product', fn($p) => $p->where('supplier_id', $filters['supplier_id']));
        }

        $stocks = $query->get()->map(function ($ws) {
            $product = $ws->product;
            $quantity = (int) $ws->quantity;
            $reserved = (int) $ws->reserved_quantity;
            $available = max(0, $quantity - $reserved);
            $minLevel = (int) $ws->min_stock_level;
            $defaultReorderFallback = config('app.default_reorder_quantity', 0);
            $reorderQty = max(0, ($minLevel > 0 ? $minLevel : $defaultReorderFallback) - $available);

            return [
                'warehouse_id'       => $ws->warehouse_id,
                'warehouse_name'     => $ws->warehouse?->name ?? 'گشتی',
                'product_id'         => $ws->product_id,
                'product_name'       => $product?->name ?? 'نەزانراو',
                'sku'                => $product?->sku ?? '',
                'barcode'            => $product?->barcode ?? '',
                'unit'               => $product?->unit ?? 'PCS',
                'category_name'      => $product?->category?->name ?? 'گشتی',
                'supplier_name'      => $product?->supplier?->name ?? 'نەزانراو',
                'quantity'           => $quantity,
                'reserved_quantity'  => $reserved,
                'available_quantity' => $available,
                'min_stock_level'    => $minLevel,
                'suggested_reorder'  => $reorderQty,
                'estimated_cost'     => $reorderQty * ((int) ($product?->cost_price ?? 0)),
            ];
        });

        $totalLowStockItems = $stocks->count();
        $totalReorderValue = $stocks->sum('estimated_cost');

        return [
            'summary' => [
                'total_low_stock_items' => $totalLowStockItems,
                'estimated_reorder_cost' => $totalReorderValue,
            ],
            'items' => $stocks,
        ];
    }

    /**
     * ٨. ڕاپۆرتی جوڵەی ستۆک (Stock Movements Report)
     */
    public function getStockMovementsReport(array $filters): array
    {
        $query = StockTransaction::query()
            ->with(['product:id,name,sku,unit', 'warehouse:id,name'])
            ->orderByDesc('created_at')
            ->orderByDesc('id');

        if (!empty($filters['warehouse_id'])) {
            $query->where('warehouse_id', $filters['warehouse_id']);
        }
        if (!empty($filters['product_id'])) {
            $query->where('product_id', $filters['product_id']);
        }
        if (!empty($filters['type']) && $filters['type'] !== 'ALL') {
            $query->where('type', $filters['type']);
        }
        if (!empty($filters['start_date'])) {
            $query->whereDate('created_at', '>=', $filters['start_date']);
        }
        if (!empty($filters['end_date'])) {
            $query->whereDate('created_at', '<=', $filters['end_date']);
        }

        $summaryData = (clone $query)
            ->withoutEagerLoads()
            ->selectRaw('
            COUNT(*) as total_transactions,
            COALESCE(SUM(CASE WHEN quantity_change > 0 THEN quantity_change ELSE 0 END), 0) as total_in_qty,
            COALESCE(SUM(CASE WHEN quantity_change < 0 THEN ABS(quantity_change) ELSE 0 END), 0) as total_out_qty
        ')->first();

        $totalTransactions = (int) ($summaryData->total_transactions ?? 0);
        $totalInQty = (int) ($summaryData->total_in_qty ?? 0);
        $totalOutQty = (int) ($summaryData->total_out_qty ?? 0);

        $perPage = (int) ($filters['per_page'] ?? 30);
        $page = (int) ($filters['page'] ?? 1);
        $paginated = $query->paginate($perPage, ['*'], 'page', $page);

        return [
            'summary' => [
                'total_transactions' => $totalTransactions,
                'total_quantity_in'  => $totalInQty,
                'total_quantity_out' => $totalOutQty,
            ],
            'transactions' => $paginated,
        ];
    }

    /**
     * ٩. ڕاپۆرتی گواستنەوەی کۆگاکان (Stock Transfers Report)
     */
    public function getStockTransfersReport(array $filters): array
    {
        $query = StockTransfer::query()
            ->with(['fromWarehouse:id,name', 'toWarehouse:id,name', 'items.product:id,name,sku', 'creator:id,name'])
            ->orderByDesc('created_at')
            ->orderByDesc('id');

        if (!empty($filters['from_warehouse_id'])) {
            $query->where('from_warehouse_id', $filters['from_warehouse_id']);
        }
        if (!empty($filters['to_warehouse_id'])) {
            $query->where('to_warehouse_id', $filters['to_warehouse_id']);
        }
        if (!empty($filters['status']) && $filters['status'] !== 'ALL') {
            $query->where('status', $filters['status']);
        }
        if (!empty($filters['start_date'])) {
            $query->whereDate('created_at', '>=', $filters['start_date']);
        }
        if (!empty($filters['end_date'])) {
            $query->whereDate('created_at', '<=', $filters['end_date']);
        }

        $summaryData = (clone $query)
            ->withoutEagerLoads()
            ->selectRaw("
            COUNT(*) as total_transfers,
            SUM(CASE WHEN status = 'COMPLETED' THEN 1 ELSE 0 END) as completed_transfers
        ")->first();

        $totalTransfers = (int) ($summaryData->total_transfers ?? 0);
        $completedTransfers = (int) ($summaryData->completed_transfers ?? 0);

        $perPage = (int) ($filters['per_page'] ?? 25);
        $page = (int) ($filters['page'] ?? 1);
        $paginated = $query->paginate($perPage, ['*'], 'page', $page);

        return [
            'summary' => [
                'total_transfers'     => $totalTransfers,
                'completed_transfers' => $completedTransfers,
            ],
            'transfers' => $paginated,
        ];
    }

    /**
     * Helper to apply common sales order filters
     */
    protected function applySalesOrderFilters(Builder $query, array $filters): void
    {
        if (!empty($filters['start_date'])) {
            $query->whereDate('order_date', '>=', $filters['start_date']);
        }

        if (!empty($filters['end_date'])) {
            $query->whereDate('order_date', '<=', $filters['end_date']);
        }

        if (!empty($filters['customer_id'])) {
            $query->where('customer_id', $filters['customer_id']);
        }

        if (!empty($filters['salesman_id'])) {
            $query->where('salesman_id', $filters['salesman_id']);
        }

        if (!empty($filters['warehouse_id'])) {
            $query->where('warehouse_id', $filters['warehouse_id']);
        }

        if (!empty($filters['status']) && $filters['status'] !== 'ALL') {
            $query->where('status', $filters['status']);
        }

        if (!empty($filters['route_id'])) {
            $query->whereHas('customer', fn($c) => $c->where('route_id', $filters['route_id']));
        }

        if (!empty($filters['price_tier'])) {
            $query->whereHas('customer', fn($c) => $c->where('price_type', $filters['price_tier']));
        }
    }
}
