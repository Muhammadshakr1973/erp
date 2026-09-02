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
     * Authoritative sales data with filters and KPIs
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

        // Calculate Authoritative Totals from matching orders
        $totalOrdersCount = (clone $query)->count();
        $totalDeliveredCount = (clone $query)->where('status', SalesOrder::STATUS_DELIVERED)->count();
        $totalGrossAmount = (int) (clone $query)->sum('subtotal');
        $totalDiscountAmount = (int) (clone $query)->sum('discount_amount');
        $totalNetAmount = (int) (clone $query)->sum('total_amount');
        $totalProfitAmount = (int) (clone $query)->sum('total_profit');
        $totalCostAmount = $totalNetAmount - $totalProfitAmount;
        $avgOrderValue = $totalOrdersCount > 0 ? (int) round($totalNetAmount / $totalOrdersCount) : 0;

        // Breakdown by Salesman
        $bySalesman = (clone $query)
            ->select('salesman_id', DB::raw('COUNT(*) as orders_count'), DB::raw('SUM(total_amount) as total_sales'), DB::raw('SUM(total_profit) as total_profit'))
            ->groupBy('salesman_id')
            ->get()
            ->map(function ($row) {
                $salesman = User::find($row->salesman_id);
                return [
                    'salesman_id'   => $row->salesman_id,
                    'salesman_name' => $salesman?->name ?? 'نەزانراو',
                    'orders_count'  => (int) $row->orders_count,
                    'total_sales'   => (int) $row->total_sales,
                    'total_profit'  => (int) $row->total_profit,
                ];
            });

        // Breakdown by Route
        $byRoute = (clone $query)
            ->join('customers', 'sales_orders.customer_id', '=', 'customers.id')
            ->select('customers.route_id', DB::raw('COUNT(sales_orders.id) as orders_count'), DB::raw('SUM(sales_orders.total_amount) as total_sales'))
            ->groupBy('customers.route_id')
            ->get()
            ->map(function ($row) {
                $route = Route::find($row->route_id);
                return [
                    'route_id'     => $row->route_id,
                    'route_name'   => $route?->name ?? 'بێ ڕێگا',
                    'orders_count' => (int) $row->orders_count,
                    'total_sales'  => (int) $row->total_sales,
                ];
            });

        // Breakdown by Status
        $byStatus = (clone $query)
            ->select('status', DB::raw('COUNT(*) as count'), DB::raw('SUM(total_amount) as total_amount'))
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
     * Uses strictly historical snapshots from orders and order items to prevent recalculation drifts.
     */
    public function getProfitReport(array $filters): array
    {
        $orderQuery = SalesOrder::query()
            ->whereIn('status', [SalesOrder::STATUS_DELIVERED, SalesOrder::STATUS_CONFIRMED]);

        $this->applySalesOrderFilters($orderQuery, $filters);

        $matchingOrderIds = (clone $orderQuery)->pluck('id');

        $itemQuery = SalesOrderItem::query()
            ->with(['product:id,name,sku,category_id', 'product.category:id,name', 'order:id,order_number,order_date,customer_id,salesman_id', 'order.customer:id,name', 'order.salesman:id,name'])
            ->whereIn('sales_order_id', $matchingOrderIds);

        if (!empty($filters['product_id'])) {
            $itemQuery->where('product_id', $filters['product_id']);
        }

        if (!empty($filters['category_id'])) {
            $itemQuery->whereHas('product', function ($q) use ($filters) {
                $q->where('category_id', $filters['category_id']);
            });
        }

        $totalRevenue = (int) (clone $itemQuery)->sum('line_total');
        $totalCost = (int) (clone $itemQuery)->select(DB::raw('SUM(quantity * cost_price) as total_cost'))->value('total_cost');
        $totalProfit = (int) (clone $itemQuery)->sum('profit');
        $totalUnitsSold = (int) (clone $itemQuery)->sum('quantity');
        $profitMargin = $totalRevenue > 0 ? round(($totalProfit / $totalRevenue) * 100, 2) : 0.0;

        // Top Profitable Products
        $productBreakdown = (clone $itemQuery)
            ->select(
                'product_id',
                DB::raw('SUM(quantity) as units_sold'),
                DB::raw('SUM(line_total) as total_revenue'),
                DB::raw('SUM(quantity * cost_price) as total_cost'),
                DB::raw('SUM(profit) as total_profit')
            )
            ->groupBy('product_id')
            ->orderByDesc('total_profit')
            ->limit(15)
            ->get()
            ->map(function ($row) {
                $product = Product::with('category')->find($row->product_id);
                $revenue = (int) $row->total_revenue;
                $profit = (int) $row->total_profit;
                $margin = $revenue > 0 ? round(($profit / $revenue) * 100, 2) : 0.0;

                return [
                    'product_id'     => $row->product_id,
                    'product_name'   => $product?->name ?? 'نەزانراو',
                    'sku'            => $product?->sku ?? '',
                    'category_name'  => $product?->category?->name ?? 'گشتی',
                    'units_sold'     => (int) $row->units_sold,
                    'total_revenue'  => $revenue,
                    'total_cost'     => (int) $row->total_cost,
                    'total_profit'   => $profit,
                    'margin_percent' => $margin,
                ];
            });

        // Top Profitable Categories
        $categoryBreakdown = (clone $itemQuery)
            ->join('products', 'sales_order_items.product_id', '=', 'products.id')
            ->leftJoin('categories', 'products.category_id', '=', 'categories.id')
            ->select(
                'categories.id as category_id',
                'categories.name as category_name',
                DB::raw('SUM(sales_order_items.quantity) as units_sold'),
                DB::raw('SUM(sales_order_items.line_total) as total_revenue'),
                DB::raw('SUM(sales_order_items.profit) as total_profit')
            )
            ->groupBy('categories.id', 'categories.name')
            ->orderByDesc('total_profit')
            ->get()
            ->map(function ($row) {
                $revenue = (int) $row->total_revenue;
                $profit = (int) $row->total_profit;
                $margin = $revenue > 0 ? round(($profit / $revenue) * 100, 2) : 0.0;

                return [
                    'category_id'    => $row->category_id,
                    'category_name'  => $row->category_name ?? 'بێ پۆل',
                    'units_sold'     => (int) $row->units_sold,
                    'total_revenue'  => $revenue,
                    'total_profit'   => $profit,
                    'margin_percent' => $margin,
                ];
            });

        // Profit Breakdown by Salesman
        $salesmanBreakdown = (clone $orderQuery)
            ->select('salesman_id', DB::raw('SUM(total_amount) as total_revenue'), DB::raw('SUM(total_profit) as total_profit'))
            ->groupBy('salesman_id')
            ->get()
            ->map(function ($row) {
                $salesman = User::find($row->salesman_id);
                $revenue = (int) $row->total_revenue;
                $profit = (int) $row->total_profit;
                $margin = $revenue > 0 ? round(($profit / $revenue) * 100, 2) : 0.0;

                return [
                    'salesman_id'    => $row->salesman_id,
                    'salesman_name'  => $salesman?->name ?? 'نەزانراو',
                    'total_revenue'  => $revenue,
                    'total_profit'   => $profit,
                    'margin_percent' => $margin,
                ];
            });

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

        $reportData = $salesmen->map(function ($salesman) use ($startDate, $endDate, $filters) {
            $ordersQuery = SalesOrder::where('salesman_id', $salesman->id)
                ->whereBetween('order_date', [$startDate, $endDate]);

            if (!empty($filters['warehouse_id'])) {
                $ordersQuery->where('warehouse_id', $filters['warehouse_id']);
            }

            $ordersForComp = (clone $ordersQuery)->with('commissionDetail')->get();
            $totalOrders = $ordersForComp->count();
            $deliveredOrders = $ordersForComp->where('status', SalesOrder::STATUS_DELIVERED)->count();
            $totalSales = (int) $ordersForComp->sum('total_amount');
            $totalProfit = (int) $ordersForComp->sum('total_profit');

            $rate = (float) ($salesman->commission_rate ?? 0);
            $estimatedCommission = 0;
            foreach ($ordersForComp as $order) {
                if ($order->commissionDetail) {
                    $estimatedCommission += (int) $order->commissionDetail->commission_amount;
                } else {
                    $estimatedCommission += (int) round(($order->total_profit * $rate) / 100);
                }
            }

            // Payments collected by this salesman in period
            $paymentsCollected = (int) CustomerPayment::where('collected_by', $salesman->id)
                ->whereBetween('paid_at', [$startDate, $endDate])
                ->sum('amount');

            $avgOrder = $totalOrders > 0 ? (int) round($totalSales / $totalOrders) : 0;

            return [
                'salesman_id'          => $salesman->id,
                'salesman_name'        => $salesman->name,
                'salesman_phone'       => $salesman->phone,
                'commission_rate'      => $rate,
                'total_orders'         => $totalOrders,
                'delivered_orders'     => $deliveredOrders,
                'total_sales'          => $totalSales,
                'total_profit'         => $totalProfit,
                'estimated_commission' => $estimatedCommission,
                'payments_collected'   => $paymentsCollected,
                'average_order_value'  => $avgOrder,
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
        // 1. Authoritative Customer Balances Summary
        $customerQuery = Customer::query()->with('route:id,name');

        if (!empty($filters['customer_id'])) {
            $customerQuery->where('id', $filters['customer_id']);
        }
        if (!empty($filters['route_id'])) {
            $customerQuery->where('route_id', $filters['route_id']);
        }
        if (!empty($filters['has_debt_only']) && filter_var($filters['has_debt_only'], FILTER_VALIDATE_BOOLEAN)) {
            $customerQuery->where('current_balance', '>', 0);
        }

        $totalCustomersCount = (clone $customerQuery)->count();
        $totalOutstandingDebt = (int) (clone $customerQuery)->sum('current_balance');
        $customersWithDebtCount = (clone $customerQuery)->where('current_balance', '>', 0)->count();

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

        $totalDebitInPeriod = (int) (clone $ledgerQuery)->sum('debit');
        $totalCreditInPeriod = (int) (clone $ledgerQuery)->sum('credit');

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

        $totalSuppliers = (clone $supplierQuery)->count();
        $totalOutstandingPayables = (int) (clone $supplierQuery)->sum('current_balance');
        $suppliersWithDebtCount = (clone $supplierQuery)->where('current_balance', '>', 0)->count();

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

        $totalDebitInPeriod = (int) (clone $ledgerQuery)->sum('debit');
        $totalCreditInPeriod = (int) (clone $ledgerQuery)->sum('credit');

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

            $totalCount = (clone $query)->count();
            $totalAmount = (int) (clone $query)->sum('amount');
            $cashTotal = (int) (clone $query)->where('payment_method', 'cash')->sum('amount');
            $bankTotal = (int) (clone $query)->where('payment_method', 'bank')->sum('amount');
            $transferTotal = (int) (clone $query)->where('payment_method', 'transfer')->sum('amount');

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

        $totalCount = (clone $query)->count();
        $totalAmount = (int) (clone $query)->sum('amount');
        $cashTotal = (int) (clone $query)->where('payment_method', 'CASH')->sum('amount');
        $bankTotal = (int) (clone $query)->where('payment_method', 'BANK')->sum('amount');

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
            $reorderQty = max(0, ($minLevel > 0 ? $minLevel : 50) - $available);

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

        $totalTransactions = (clone $query)->count();
        $totalInQty = (int) (clone $query)->where('quantity_change', '>', 0)->sum('quantity_change');
        $totalOutQty = (int) abs((clone $query)->where('quantity_change', '<', 0)->sum('quantity_change'));

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

        $totalTransfers = (clone $query)->count();
        $completedTransfers = (clone $query)->where('status', 'COMPLETED')->count();

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
