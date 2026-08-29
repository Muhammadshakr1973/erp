<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Customer;
use App\Models\CustomerLedger;
use App\Models\CustomerPayment;
use App\Models\Product;
use App\Models\Role;
use App\Models\Route as CustomerRoute;
use App\Models\SalesOrder;
use App\Models\SalesOrderItem;
use App\Models\Stock;
use App\Models\StockTransaction;
use App\Models\Supplier;
use App\Models\SupplierLedger;
use App\Models\SupplierPayment;
use App\Models\User;
use App\Models\Warehouse;
use App\Services\ReportService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ReportServiceTest extends TestCase
{
    use RefreshDatabase;

    protected User $admin;
    protected User $salesman;
    protected Warehouse $warehouse;
    protected CustomerRoute $route;
    protected Customer $customer;
    protected Supplier $supplier;
    protected Category $category;
    protected Product $product;
    protected ReportService $reportService;

    protected function setUp(): void
    {
        parent::setUp();

        $adminRole = Role::create([
            'name' => Role::OWNER,
            'display_name' => 'Owner',
            'permissions' => ['*'],
        ]);

        $salesmanRole = Role::create([
            'name' => Role::SALESMAN,
            'display_name' => 'Salesman',
            'permissions' => ['orders.create', 'orders.view', 'customers.view'],
        ]);

        $this->admin = User::factory()->create([
            'role_id' => $adminRole->id,
            'is_active' => true,
        ]);

        $this->salesman = User::factory()->create([
            'role_id' => $salesmanRole->id,
            'name' => 'Aram Salesman',
            'commission_rate' => 5.0,
            'is_active' => true,
        ]);

        $this->warehouse = Warehouse::create([
            'name' => 'Main Warehouse',
            'is_main' => true,
            'is_active' => true,
        ]);

        $this->route = CustomerRoute::create([
            'name' => 'Route Sulaimaniyah 1',
            'is_active' => true,
        ]);

        $this->customer = Customer::create([
            'name' => 'Kawa Market',
            'route_id' => $this->route->id,
            'price_type' => 'N1',
            'current_balance' => 150000,
            'is_active' => true,
        ]);

        $this->supplier = Supplier::create([
            'name' => 'Al-Haramain Trading',
            'current_balance' => 500000,
            'is_active' => true,
        ]);

        $this->category = Category::create([
            'name' => 'Beverages',
        ]);

        $this->product = Product::create([
            'name' => 'Cola 250ml',
            'sku' => 'COL-250',
            'category_id' => $this->category->id,
            'supplier_id' => $this->supplier->id,
            'purchase_cost' => 500,
            'cost_type' => 'FIFO',
            'price_n1' => 750,
            'price_n2' => 700,
            'price_cash' => 650,
            'is_active' => true,
        ]);

        $this->reportService = app(ReportService::class);
    }

    public function test_sales_report_reconciles_totals_and_breakdowns(): void
    {
        // Create completed sales orders
        $order1 = SalesOrder::create([
            'order_number' => 'SO-1001',
            'customer_id' => $this->customer->id,
            'salesman_id' => $this->salesman->id,
            'warehouse_id' => $this->warehouse->id,
            'price_type' => 'N1',
            'subtotal' => 15000, // 20 * 750
            'discount_amount' => 1000,
            'total_amount' => 14000,
            'total_cost' => 10000, // 20 * 500
            'total_profit' => 4000, // 14000 - 10000
            'status' => SalesOrder::STATUS_DELIVERED,
            'order_date' => now()->toDateString(),
        ]);

        SalesOrderItem::create([
            'sales_order_id' => $order1->id,
            'product_id' => $this->product->id,
            'quantity' => 20,
            'unit_price' => 750,
            'cost_snapshot' => 500,
            'total_amount' => 15000,
            'total_profit' => 5000,
        ]);

        $response = $this->actingAs($this->admin)->getJson('/api/v1/reports/sales');

        $response->assertStatus(200);
        $response->assertJsonStructure([
            'data' => [
                'summary' => [
                    'total_orders_count',
                    'total_gross_amount',
                    'total_discount_amount',
                    'total_net_sales',
                    'total_cost_amount',
                    'total_profit_amount',
                ],
                'breakdown' => [
                    'by_salesman',
                    'by_route',
                    'by_status',
                ],
                'orders' => [
                    'data',
                ],
            ]
        ]);

        $this->assertEquals(14000, $response->json('data.summary.total_net_sales'));
        $this->assertEquals(4000, $response->json('data.summary.total_profit_amount'));
    }

    public function test_profit_report_calculates_margins_accurately(): void
    {
        $order = SalesOrder::create([
            'order_number' => 'SO-1002',
            'customer_id' => $this->customer->id,
            'salesman_id' => $this->salesman->id,
            'warehouse_id' => $this->warehouse->id,
            'price_type' => 'N1',
            'subtotal' => 75000,
            'discount_amount' => 0,
            'total_amount' => 75000,
            'total_cost' => 50000,
            'total_profit' => 25000,
            'status' => SalesOrder::STATUS_DELIVERED,
            'order_date' => now()->toDateString(),
        ]);

        SalesOrderItem::create([
            'sales_order_id' => $order->id,
            'product_id' => $this->product->id,
            'quantity' => 100,
            'unit_price' => 750,
            'cost_snapshot' => 500,
            'total_amount' => 75000,
            'total_profit' => 25000,
        ]);

        $response = $this->actingAs($this->admin)->getJson('/api/v1/reports/profit');

        $response->assertStatus(200);
        $this->assertEquals(75000, $response->json('data.summary.total_revenue'));
        $this->assertEquals(50000, $response->json('data.summary.total_cost'));
        $this->assertEquals(25000, $response->json('data.summary.total_profit'));
        $this->assertEquals(33.33, $response->json('data.summary.profit_margin_percent'));
    }

    public function test_customer_and_supplier_debts_reports_reconcile_with_ledgers(): void
    {
        // Customer Ledger entry
        CustomerLedger::create([
            'customer_id' => $this->customer->id,
            'entry_type' => CustomerLedger::TYPE_SALE,
            'debit' => 150000,
            'credit' => 0,
            'balance_after' => 150000,
            'notes' => 'Sales invoice debit',
        ]);

        $custResponse = $this->actingAs($this->admin)->getJson('/api/v1/reports/customer-debts');
        $custResponse->assertStatus(200);
        $this->assertEquals(150000, $custResponse->json('summary.total_outstanding_receivables'));

        // Supplier Ledger entry
        SupplierLedger::create([
            'supplier_id' => $this->supplier->id,
            'entry_type' => SupplierLedger::TYPE_PURCHASE,
            'debit' => 0,
            'credit' => 500000,
            'balance_after' => 500000,
            'notes' => 'Goods received credit',
        ]);

        $supResponse = $this->actingAs($this->admin)->getJson('/api/v1/reports/supplier-debts');
        $supResponse->assertStatus(200);
        $this->assertEquals(500000, $supResponse->json('summary.total_outstanding_payables'));
    }

    public function test_low_stock_report_detects_inventory_under_threshold(): void
    {
        // Create stock item below min_stock_level
        Stock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 5,
            'reserved_quantity' => 2,
            'min_stock_level' => 20,
        ]);

        $response = $this->actingAs($this->admin)->getJson('/api/v1/reports/low-stock');
        $response->assertStatus(200);
        $this->assertEquals(1, $response->json('data.summary.total_low_stock_items'));
        $this->assertEquals(3, $response->json('data.items.0.available_quantity'));
        $this->assertEquals(17, $response->json('data.items.0.suggested_reorder')); // 20 - 3
    }
}
