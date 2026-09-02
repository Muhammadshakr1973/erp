<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\Customer;
use App\Models\Role;
use App\Models\SalesmanCommission;
use App\Models\SalesmanCommissionDetail;
use App\Models\SalesOrder;
use App\Models\User;
use App\Models\Warehouse;
use App\Services\CommissionService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CommissionLifecycleTest extends TestCase
{
    use RefreshDatabase;

    protected User $admin;
    protected User $salesman;
    protected User $otherSalesman;
    protected Customer $customer;
    protected Warehouse $warehouse;

    protected function setUp(): void
    {
        parent::setUp();

        $adminRole = Role::create([
            'name'         => Role::ADMIN,
            'display_name' => 'Admin',
            'permissions'  => ['*'],
            'is_system'    => true,
        ]);

        $salesmanRole = Role::create([
            'name'         => Role::SALESMAN,
            'display_name' => 'Salesman',
            'permissions'  => ['orders.create', 'customers.view'],
            'is_system'    => true,
        ]);

        $this->admin = User::create([
            'name'      => 'Admin User',
            'phone'     => '07501111111',
            'password'  => bcrypt('password123'),
            'role_id'   => $adminRole->id,
            'is_active' => true,
        ]);

        $this->salesman = User::create([
            'name'            => 'Sales Rep A',
            'phone'           => '07502222222',
            'password'        => bcrypt('password123'),
            'role_id'         => $salesmanRole->id,
            'commission_rate' => 5.00, // 5%
            'is_active'       => true,
        ]);

        $this->otherSalesman = User::create([
            'name'            => 'Sales Rep B',
            'phone'           => '07503333333',
            'password'        => bcrypt('password123'),
            'role_id'         => $salesmanRole->id,
            'commission_rate' => 7.50, // 7.5%
            'is_active'       => true,
        ]);

        $this->customer = Customer::create([
            'name'            => 'City Market',
            'phone'           => '07504444444',
            'address'         => 'Erbil Center',
            'price_tier'      => 'RETAIL',
            'credit_limit'    => 5000000,
            'current_balance' => 0,
            'is_active'       => true,
        ]);

        $this->warehouse = Warehouse::create([
            'name'      => 'Main Warehouse',
            'location'  => 'Erbil Industrial',
            'is_active' => true,
        ]);
    }

    /**
     * Test that commission is calculated strictly on DELIVERED orders within the date range,
     * excluding non-delivered statuses (draft, confirmed, packing, ready).
     */
    public function test_commission_calculated_only_on_delivered_orders_in_period(): void
    {
        $this->actingAs($this->admin);

        // 1. Delivered order within period (Delivered on 2026-08-10)
        $deliveredOrder1 = SalesOrder::create([
            'order_number'    => 'SO-20260810-001',
            'salesman_id'     => $this->salesman->id,
            'customer_id'     => $this->customer->id,
            'warehouse_id'    => $this->warehouse->id,
            'status'          => SalesOrder::STATUS_DELIVERED,
            'price_tier'      => 'RETAIL',
            'total_amount'    => 100000,
            'total_cost'      => 80000,
            'total_profit'    => 20000,
            'delivered_at'    => '2026-08-10 14:00:00',
        ]);

        // 2. Another delivered order within period (Delivered on 2026-08-15)
        $deliveredOrder2 = SalesOrder::create([
            'order_number'    => 'SO-20260815-002',
            'salesman_id'     => $this->salesman->id,
            'customer_id'     => $this->customer->id,
            'warehouse_id'    => $this->warehouse->id,
            'status'          => SalesOrder::STATUS_DELIVERED,
            'price_tier'      => 'RETAIL',
            'total_amount'    => 200000,
            'total_cost'      => 150000,
            'total_profit'    => 50000,
            'delivered_at'    => '2026-08-15 11:30:00',
        ]);

        // 3. Delivered order outside period (Delivered in July 2026)
        SalesOrder::create([
            'order_number'    => 'SO-20260710-003',
            'salesman_id'     => $this->salesman->id,
            'customer_id'     => $this->customer->id,
            'warehouse_id'    => $this->warehouse->id,
            'status'          => SalesOrder::STATUS_DELIVERED,
            'price_tier'      => 'RETAIL',
            'total_amount'    => 50000,
            'total_cost'      => 40000,
            'total_profit'    => 10000,
            'delivered_at'    => '2026-07-10 10:00:00',
        ]);

        // 4. Non-delivered order within period (Status: CONFIRMED)
        SalesOrder::create([
            'order_number'    => 'SO-20260820-004',
            'salesman_id'     => $this->salesman->id,
            'customer_id'     => $this->customer->id,
            'warehouse_id'    => $this->warehouse->id,
            'status'          => SalesOrder::STATUS_CONFIRMED,
            'price_tier'      => 'RETAIL',
            'total_amount'    => 100000,
            'total_cost'      => 80000,
            'total_profit'    => 20000,
        ]);

        $response = $this->postJson('/api/v1/commissions/calculate', [
            'salesman_id' => $this->salesman->id,
            'period_from' => '2026-08-01',
            'period_to'   => '2026-08-31',
        ]);

        $response->assertStatus(201);
        $commissionId = $response->json('data.id');

        $commission = SalesmanCommission::with('details')->findOrFail($commissionId);

        // Total sales: 100,000 + 200,000 = 300,000
        $this->assertEquals(300000, $commission->total_sales);
        // Total profit: 20,000 + 50,000 = 70,000
        $this->assertEquals(70000, $commission->total_profit);
        // Commission amount at 5%: 70,000 * 5% = 3,500
        $this->assertEquals(3500, $commission->commission_amount);
        $this->assertEquals(5.00, (float) $commission->commission_rate);
        $this->assertEquals(SalesmanCommission::STATUS_CALCULATED, $commission->status);
        $this->assertCount(2, $commission->details);
    }

    /**
     * Test DEC-005: Commission is calculated based on profit, NOT on sales revenue.
     */
    public function test_commission_is_based_on_profit_not_sales_revenue(): void
    {
        $this->actingAs($this->admin);

        // Order with high sales revenue but low profit: Sales 1,000,000 IQD, Cost 900,000 IQD, Profit 100,000 IQD
        SalesOrder::create([
            'order_number'    => 'SO-20260812-005',
            'salesman_id'     => $this->salesman->id,
            'customer_id'     => $this->customer->id,
            'warehouse_id'    => $this->warehouse->id,
            'status'          => SalesOrder::STATUS_DELIVERED,
            'price_tier'      => 'RETAIL',
            'total_amount'    => 1000000,
            'total_cost'      => 900000,
            'total_profit'    => 100000,
            'delivered_at'    => '2026-08-12 15:00:00',
        ]);

        $response = $this->postJson('/api/v1/commissions/calculate', [
            'salesman_id' => $this->salesman->id,
            'period_from' => '2026-08-01',
            'period_to'   => '2026-08-31',
        ]);

        $response->assertStatus(201);
        $commissionId = $response->json('data.id');

        $commission = SalesmanCommission::findOrFail($commissionId);

        // At 5% rate on 100,000 IQD profit = 5,000 IQD
        // (If it were calculated on sales revenue of 1,000,000 IQD it would have been 50,000 IQD!)
        $this->assertEquals(5000, $commission->commission_amount);
        $this->assertEquals(100000, $commission->total_profit);
    }

    /**
     * Test historical snapshot rule: rate changes or order changes later do not rewrite old commission records.
     */
    public function test_historical_commission_rate_snapshot_integrity(): void
    {
        $this->actingAs($this->admin);

        $order = SalesOrder::create([
            'order_number'    => 'SO-20260805-006',
            'salesman_id'     => $this->salesman->id,
            'customer_id'     => $this->customer->id,
            'warehouse_id'    => $this->warehouse->id,
            'status'          => SalesOrder::STATUS_DELIVERED,
            'price_tier'      => 'RETAIL',
            'total_amount'    => 500000,
            'total_cost'      => 300000,
            'total_profit'    => 200000,
            'delivered_at'    => '2026-08-05 16:00:00',
        ]);

        $response = $this->postJson('/api/v1/commissions/calculate', [
            'salesman_id' => $this->salesman->id,
            'period_from' => '2026-08-01',
            'period_to'   => '2026-08-31',
        ]);

        $response->assertStatus(201);
        $commissionId = $response->json('data.id');

        // Now modify the salesman's current commission rate in user profile
        $this->salesman->update(['commission_rate' => 15.00]);

        // Refresh commission model from database
        $commission = SalesmanCommission::findOrFail($commissionId);

        // Historical snapshot in commission record MUST remain 5.00% and 10,000 IQD
        $this->assertEquals(5.00, (float) $commission->commission_rate);
        $this->assertEquals(10000, $commission->commission_amount);
    }

    /**
     * Test duplicate calculation prevention: cannot calculate twice for the same active period.
     */
    public function test_cannot_calculate_duplicate_commission_for_same_period(): void
    {
        $this->actingAs($this->admin);

        SalesOrder::create([
            'order_number'    => 'SO-20260802-007',
            'salesman_id'     => $this->salesman->id,
            'customer_id'     => $this->customer->id,
            'warehouse_id'    => $this->warehouse->id,
            'status'          => SalesOrder::STATUS_DELIVERED,
            'price_tier'      => 'RETAIL',
            'total_amount'    => 100000,
            'total_cost'      => 70000,
            'total_profit'    => 30000,
            'delivered_at'    => '2026-08-02 12:00:00',
        ]);

        // First calculation succeeds
        $res1 = $this->postJson('/api/v1/commissions/calculate', [
            'salesman_id' => $this->salesman->id,
            'period_from' => '2026-08-01',
            'period_to'   => '2026-08-31',
        ]);
        $res1->assertStatus(201);

        // Second calculation for identical period MUST be rejected
        $res2 = $this->postJson('/api/v1/commissions/calculate', [
            'salesman_id' => $this->salesman->id,
            'period_from' => '2026-08-01',
            'period_to'   => '2026-08-31',
        ]);
        $res2->assertStatus(422);
    }

    /**
     * Test full approval and payment lifecycle (CALCULATED -> APPROVED -> PAID).
     */
    public function test_complete_commission_lifecycle_flow(): void
    {
        $this->actingAs($this->admin);

        SalesOrder::create([
            'order_number'    => 'SO-20260818-008',
            'salesman_id'     => $this->salesman->id,
            'customer_id'     => $this->customer->id,
            'warehouse_id'    => $this->warehouse->id,
            'status'          => SalesOrder::STATUS_DELIVERED,
            'price_tier'      => 'RETAIL',
            'total_amount'    => 200000,
            'total_cost'      => 160000,
            'total_profit'    => 40000,
            'delivered_at'    => '2026-08-18 10:00:00',
        ]);

        // 1. Calculate
        $calcRes = $this->postJson('/api/v1/commissions/calculate', [
            'salesman_id' => $this->salesman->id,
            'period_from' => '2026-08-01',
            'period_to'   => '2026-08-31',
        ]);
        $calcRes->assertStatus(201);
        $commissionId = $calcRes->json('data.id');

        $commission = SalesmanCommission::findOrFail($commissionId);
        $this->assertEquals(SalesmanCommission::STATUS_CALCULATED, $commission->status);

        // 2. Direct payment before approval should be rejected
        $prematurePayRes = $this->postJson("/api/v1/commissions/{$commissionId}/pay", [
            'payment_method' => 'cash',
        ]);
        $prematurePayRes->assertStatus(422);

        // 3. Approve
        $approveRes = $this->postJson("/api/v1/commissions/{$commissionId}/approve", [
            'notes' => 'Approved by manager',
        ]);
        $approveRes->assertStatus(200);

        $commission->refresh();
        $this->assertEquals(SalesmanCommission::STATUS_APPROVED, $commission->status);
        $this->assertEquals($this->admin->id, $commission->approved_by);
        $this->assertNotNull($commission->approved_at);

        // Verify audit log for approval
        $this->assertDatabaseHas('audit_logs', [
            'action'      => 'COMMISSION_APPROVE',
            'entity_type' => 'SalesmanCommission',
            'entity_id'   => $commissionId,
            'user_id'     => $this->admin->id,
        ]);

        // 4. Pay
        $payRes = $this->postJson("/api/v1/commissions/{$commissionId}/pay", [
            'payment_method' => 'bank',
            'notes'          => 'Paid via direct bank deposit',
        ]);
        $payRes->assertStatus(200);

        $commission->refresh();
        $this->assertEquals(SalesmanCommission::STATUS_PAID, $commission->status);
        $this->assertEquals($this->admin->id, $commission->paid_by);
        $this->assertEquals('bank', $commission->payment_method);
        $this->assertNotNull($commission->paid_at);

        // Verify audit log for payment
        $this->assertDatabaseHas('audit_logs', [
            'action'      => 'COMMISSION_PAY',
            'entity_type' => 'SalesmanCommission',
            'entity_id'   => $commissionId,
            'user_id'     => $this->admin->id,
        ]);

        // 5. Prevent duplicate payment
        $duplicatePayRes = $this->postJson("/api/v1/commissions/{$commissionId}/pay", [
            'payment_method' => 'cash',
        ]);
        $duplicatePayRes->assertStatus(422);
    }

    /**
     * Test commission cancellation and order release for recalculation.
     */
    public function test_cancellation_releases_orders_for_recalculation(): void
    {
        $this->actingAs($this->admin);

        $order = SalesOrder::create([
            'order_number'    => 'SO-20260822-009',
            'salesman_id'     => $this->salesman->id,
            'customer_id'     => $this->customer->id,
            'warehouse_id'    => $this->warehouse->id,
            'status'          => SalesOrder::STATUS_DELIVERED,
            'price_tier'      => 'RETAIL',
            'total_amount'    => 150000,
            'total_cost'      => 100000,
            'total_profit'    => 50000,
            'delivered_at'    => '2026-08-22 14:00:00',
        ]);

        // Calculate
        $calcRes = $this->postJson('/api/v1/commissions/calculate', [
            'salesman_id' => $this->salesman->id,
            'period_from' => '2026-08-01',
            'period_to'   => '2026-08-31',
        ]);
        $calcRes->assertStatus(201);
        $commissionId = $calcRes->json('data.id');

        // Cancel
        $cancelRes = $this->postJson("/api/v1/commissions/{$commissionId}/cancel", [
            'reason' => 'Calculated with wrong date range',
        ]);
        $cancelRes->assertStatus(200);

        $commission = SalesmanCommission::findOrFail($commissionId);
        $this->assertEquals(SalesmanCommission::STATUS_CANCELLED, $commission->status);
        $this->assertEquals('Calculated with wrong date range', $commission->cancellation_reason);

        // Now recalculating for the same period MUST succeed because the previous one was cancelled
        $recalcRes = $this->postJson('/api/v1/commissions/calculate', [
            'salesman_id' => $this->salesman->id,
            'period_from' => '2026-08-01',
            'period_to'   => '2026-08-31',
        ]);
        $recalcRes->assertStatus(201);
    }

    /**
     * Test preview API returns accurate calculation without persisting records.
     */
    public function test_preview_api_computes_estimations_without_persisting(): void
    {
        $this->actingAs($this->admin);

        SalesOrder::create([
            'order_number'    => 'SO-20260825-010',
            'salesman_id'     => $this->salesman->id,
            'customer_id'     => $this->customer->id,
            'warehouse_id'    => $this->warehouse->id,
            'status'          => SalesOrder::STATUS_DELIVERED,
            'price_tier'      => 'RETAIL',
            'total_amount'    => 300000,
            'total_cost'      => 200000,
            'total_profit'    => 100000,
            'delivered_at'    => '2026-08-25 17:00:00',
        ]);

        $initialCommissionsCount = SalesmanCommission::count();

        $response = $this->getJson("/api/v1/commissions/preview?salesman_id={$this->salesman->id}&period_from=2026-08-01&period_to=2026-08-31");
        $response->assertStatus(200);
        $response->assertJson([
            'data' => [
                'eligible_orders_count' => 1,
                'total_sales'           => 300000,
                'total_profit'          => 100000,
                'commission_rate'       => 5,
                'estimated_commission'  => 5000,
            ],
        ]);

        // Verify that preview did not create any records in database
        $this->assertEquals($initialCommissionsCount, SalesmanCommission::count());
    }

    /**
     * Test authorization: Salesman can view their own commissions but cannot calculate or approve.
     */
    public function test_salesman_authorization_restrictions(): void
    {
        $this->actingAs($this->salesman);

        // Salesman trying to calculate commission -> 403 Forbidden
        $calcRes = $this->postJson('/api/v1/commissions/calculate', [
            'salesman_id' => $this->salesman->id,
            'period_from' => '2026-08-01',
            'period_to'   => '2026-08-31',
        ]);
        $calcRes->assertStatus(403);

        // Salesman accessing general commissions list -> 403 Forbidden
        $listRes = $this->getJson('/api/v1/commissions');
        $listRes->assertStatus(403);

        // Salesman accessing own commissions endpoint -> 200 OK
        $myCommissionsRes = $this->getJson('/api/v1/commissions/my-commissions');
        $myCommissionsRes->assertStatus(200);
    }

    /**
     * Test returns deduction: commission must be calculated on net values if returns are completed.
     */
    public function test_returns_deduction_calculates_commission_on_net_profit(): void
    {
        $this->actingAs($this->admin);

        $product = \App\Models\Product::create([
            'name' => 'Test Product',
            'sku' => 'TEST-SKU-RETURNS',
            'unit' => 'PCS',
            'cost_price' => 12000,
            'price_n1' => 22000,
            'price_n2' => 20000,
            'price_n3' => 18000,
            'is_active' => true,
        ]);

        // Create delivered order: Sales 200,000, Cost 120,000, Profit 80,000
        $order = SalesOrder::create([
            'order_number'    => 'SO-20260828-999',
            'salesman_id'     => $this->salesman->id,
            'customer_id'     => $this->customer->id,
            'warehouse_id'    => $this->warehouse->id,
            'status'          => SalesOrder::STATUS_DELIVERED,
            'price_tier'      => 'RETAIL',
            'total_amount'    => 200000,
            'total_cost'      => 120000,
            'total_profit'    => 80000,
            'delivered_at'    => '2026-08-28 10:00:00',
        ]);

        $orderItem = \App\Models\SalesOrderItem::create([
            'sales_order_id' => $order->id,
            'product_id'     => $product->id,
            'quantity'       => 10,
            'unit_price'     => 20000,
            'cost_price'     => 12000,
            'line_total'     => 200000,
            'total_price'    => 200000,
        ]);

        // Create completed return on this order
        $return = \App\Models\SalesReturn::create([
            'return_number'       => 'RET-20260828-001',
            'sales_order_id'      => $order->id,
            'customer_id'         => $this->customer->id,
            'status'              => 'completed',
            'total_return_amount' => 40000, // Returned 2 items
            'created_by'          => $this->admin->id,
        ]);

        $returnItem = \App\Models\SalesReturnItem::create([
            'sales_return_id'     => $return->id,
            'sales_order_item_id' => $orderItem->id,
            'product_id'          => $product->id,
            'quantity'            => 2,
            'unit_price'          => 20000,
            'total'               => 40000,
        ]);

        // Net sales: 200,000 - 40,000 = 160,000
        // Net profit: 80,000 - (2 * (20,000 - 12,000)) = 80,000 - 16,000 = 64,000
        // Commission at 5%: 64,000 * 5% = 3,200

        $response = $this->postJson('/api/v1/commissions/calculate', [
            'salesman_id' => $this->salesman->id,
            'period_from' => '2026-08-01',
            'period_to'   => '2026-08-31',
        ]);

        $response->assertStatus(201);
        $commissionId = $response->json('data.id');

        $commission = SalesmanCommission::with('details')->findOrFail($commissionId);

        $this->assertEquals(160000, $commission->total_sales);
        $this->assertEquals(64000, $commission->total_profit);
        $this->assertEquals(3200, $commission->commission_amount);
    }

    /**
     * Test preventing cancellation of an order that is associated with an active commission.
     */
    public function test_cannot_cancel_order_with_active_commission(): void
    {
        $this->actingAs($this->admin);

        $order = SalesOrder::create([
            'order_number'    => 'SO-20260829-888',
            'salesman_id'     => $this->salesman->id,
            'customer_id'     => $this->customer->id,
            'warehouse_id'    => $this->warehouse->id,
            'status'          => SalesOrder::STATUS_DELIVERED,
            'price_tier'      => 'RETAIL',
            'total_amount'    => 100000,
            'total_cost'      => 80000,
            'total_profit'    => 20000,
            'delivered_at'    => '2026-08-29 10:00:00',
        ]);

        // Calculate commission
        $this->postJson('/api/v1/commissions/calculate', [
            'salesman_id' => $this->salesman->id,
            'period_from' => '2026-08-01',
            'period_to'   => '2026-08-31',
        ])->assertStatus(201);

        // Attempting to cancel the order via SalesOrderService should throw exception
        $this->expectException(\Illuminate\Validation\ValidationException::class);
        app(\App\Services\SalesOrderService::class)->transitionTo($order, SalesOrder::STATUS_CANCELLED, $this->admin);
    }

    /**
     * Test preventing cancellation of an already PAID commission.
     */
    public function test_cannot_cancel_paid_commission(): void
    {
        $this->actingAs($this->admin);

        SalesOrder::create([
            'order_number'    => 'SO-20260830-777',
            'salesman_id'     => $this->salesman->id,
            'customer_id'     => $this->customer->id,
            'warehouse_id'    => $this->warehouse->id,
            'status'          => SalesOrder::STATUS_DELIVERED,
            'price_tier'      => 'RETAIL',
            'total_amount'    => 100000,
            'total_cost'      => 80000,
            'total_profit'    => 20000,
            'delivered_at'    => '2026-08-30 10:00:00',
        ]);

        // Calculate
        $calcRes = $this->postJson('/api/v1/commissions/calculate', [
            'salesman_id' => $this->salesman->id,
            'period_from' => '2026-08-01',
            'period_to'   => '2026-08-31',
        ]);
        $commissionId = $calcRes->json('data.id');

        // Approve
        $this->postJson("/api/v1/commissions/{$commissionId}/approve")->assertStatus(200);

        // Pay
        $this->postJson("/api/v1/commissions/{$commissionId}/pay", [
            'payment_method' => 'cash',
        ])->assertStatus(200);

        // Attempting to cancel the PAID commission should fail
        $cancelRes = $this->postJson("/api/v1/commissions/{$commissionId}/cancel", [
            'reason' => 'Should fail',
        ]);
        $cancelRes->assertStatus(422);
    }

    /**
     * Test sales returns BEFORE calculation reduce net profit used for commission.
     */
    public function test_returns_before_commission_calculation_deduct_sales_and_profit(): void
    {
        $this->actingAs($this->admin);

        $order = SalesOrder::create([
            'order_number'    => 'SO-20260830-RET1',
            'salesman_id'     => $this->salesman->id,
            'customer_id'     => $this->customer->id,
            'warehouse_id'    => $this->warehouse->id,
            'status'          => SalesOrder::STATUS_DELIVERED,
            'price_tier'      => 'RETAIL',
            'total_amount'    => 100000,
            'total_cost'      => 60000,
            'total_profit'    => 40000,
            'delivered_at'    => '2026-08-30 10:00:00',
        ]);

        $orderItem = \App\Models\SalesOrderItem::create([
            'sales_order_id' => $order->id,
            'product_id' => $this->product->id,
            'quantity' => 10,
            'unit_price' => 10000,
            'cost_price' => 6000,
            'total' => 100000,
        ]);

        // Process a return of 5 items before commission calculation
        app(\App\Services\SalesReturnService::class)->createReturn([
            'sales_order_id' => $order->id,
            'reason' => 'Customer changed mind',
            'items' => [
                ['sales_order_item_id' => $orderItem->id, 'quantity' => 5]
            ]
        ], $this->admin);

        // Calculate commission
        $response = $this->postJson('/api/v1/commissions/calculate', [
            'salesman_id' => $this->salesman->id,
            'period_from' => '2026-08-01',
            'period_to'   => '2026-08-31',
        ]);

        $response->assertStatus(201);
        $commissionId = $response->json('data.id');
        $commission = SalesmanCommission::findOrFail($commissionId);

        // Net profit should be 20,000 (40,000 original - 20,000 returned profit)
        // Commission at 5% rate on 20,000 = 1,000
        $this->assertEquals(20000, $commission->total_profit);
        $this->assertEquals(1000, $commission->commission_amount);
    }

    /**
     * Test sales returns AFTER commission payment do not rewrite paid commission snapshots.
     */
    public function test_returns_after_commission_paid_do_not_rewrite_commission_snapshot(): void
    {
        $this->actingAs($this->admin);

        $order = SalesOrder::create([
            'order_number'    => 'SO-20260830-RET2',
            'salesman_id'     => $this->salesman->id,
            'customer_id'     => $this->customer->id,
            'warehouse_id'    => $this->warehouse->id,
            'status'          => SalesOrder::STATUS_DELIVERED,
            'price_tier'      => 'RETAIL',
            'total_amount'    => 100000,
            'total_cost'      => 60000,
            'total_profit'    => 40000,
            'delivered_at'    => '2026-08-30 10:00:00',
        ]);

        $orderItem = \App\Models\SalesOrderItem::create([
            'sales_order_id' => $order->id,
            'product_id' => $this->product->id,
            'quantity' => 10,
            'unit_price' => 10000,
            'cost_price' => 6000,
            'total' => 100000,
        ]);

        // Calculate & Pay commission
        $calcRes = $this->postJson('/api/v1/commissions/calculate', [
            'salesman_id' => $this->salesman->id,
            'period_from' => '2026-08-01',
            'period_to'   => '2026-08-31',
        ]);
        $commissionId = $calcRes->json('data.id');
        $this->postJson("/api/v1/commissions/{$commissionId}/approve")->assertStatus(200);
        $this->postJson("/api/v1/commissions/{$commissionId}/pay", ['payment_method' => 'cash'])->assertStatus(200);

        $paidCommissionBefore = SalesmanCommission::findOrFail($commissionId);
        $originalAmount = $paidCommissionBefore->commission_amount; // 2000

        // Now process a return after payment
        app(\App\Services\SalesReturnService::class)->createReturn([
            'sales_order_id' => $order->id,
            'reason' => 'Late Return',
            'items' => [
                ['sales_order_item_id' => $orderItem->id, 'quantity' => 5]
            ]
        ], $this->admin);

        // Verify the paid commission snapshot is untouched
        $paidCommissionAfter = SalesmanCommission::findOrFail($commissionId);
        $this->assertEquals($originalAmount, $paidCommissionAfter->commission_amount);
        $this->assertEquals(SalesmanCommission::STATUS_PAID, $paidCommissionAfter->status);
    }
}
