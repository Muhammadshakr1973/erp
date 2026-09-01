<?php

namespace Tests\Feature;

use App\Models\Customer;
use App\Models\Product;
use App\Models\Role;
use App\Models\SalesOrder;
use App\Models\User;
use App\Models\Warehouse;
use App\Models\WarehouseStock;
use App\Models\CustomerLedger;
use App\Models\StockTransaction;
use App\Models\PurchaseRequirement;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SalesOrderTest extends TestCase
{
    use RefreshDatabase;

    protected User $salesman;
    protected Customer $customer;
    protected Warehouse $warehouse;
    protected Product $product;

    protected function setUp(): void
    {
        parent::setUp();

        // Create salesman role
        $salesmanRole = Role::create([
            'name' => Role::SALESMAN,
            'display_name' => 'Salesman',
            'permissions' => []
        ]);

        // Create user
        $this->salesman = User::factory()->create([
            'role_id' => $salesmanRole->id,
            'is_active' => true,
        ]);

        // Create route
        $route = \App\Models\Route::create([
            'name' => 'Route A',
            'is_active' => true,
        ]);

        // Assign salesman to route for today
        \DB::table('route_salesmen')->insert([
            'route_id' => $route->id,
            'salesman_id' => $this->salesman->id,
            'work_date' => now()->toDateString(),
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Create customer on the route
        $this->customer = Customer::create([
            'route_id' => $route->id,
            'name' => 'Test Customer',
            'price_type' => 'N2',
            'current_balance' => 0,
            'is_active' => true,
        ]);

        // Create warehouse
        $this->warehouse = Warehouse::create([
            'name' => 'Main Warehouse',
            'is_main' => true,
            'is_active' => true,
        ]);

        // Create product
        $this->product = Product::create([
            'name' => 'Test Product',
            'sku' => 'TEST-SKU',
            'unit' => 'PCS',
            'cost_price' => 5000,
            'price_n1' => 8000,
            'price_n2' => 7500,
            'price_n3' => 7000,
            'is_active' => true,
        ]);

        // Seed stock
        WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 10,
            'reserved_quantity' => 0,
        ]);
    }

    /** @test */
    public function it_can_create_a_sales_order_and_transitions_it_to_confirmed_reserving_stock()
    {
        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'discount_type' => 'PERCENT',
            'discount_percent' => 10,
            'shared_key' => 'test-order-key-1',
            'version' => 1,
            'notes' => 'Please deliver fast',
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 5,
                ]
            ]
        ];

        $response = $this->actingAs($this->salesman)
            ->postJson('/api/v1/orders', $payload);

        $response->assertStatus(200); // Because it auto-confirmed and updated status, returning 200/201

        // Assert order exists in database
        $order = SalesOrder::with('items')->first();
        $this->assertNotNull($order);
        $this->assertEquals(SalesOrder::STATUS_CONFIRMED, $order->status);
        $this->assertEquals(37500, $order->subtotal); // 7500 * 5 = 37500
        $this->assertEquals(3750, $order->discount_amount); // 10% of 37500 = 3750
        $this->assertEquals(33750, $order->total_amount); // 37500 - 3750 = 33750
        $this->assertEquals(12500, $order->total_profit); // (7500 - 5000) * 5 = 12500

        // Assert item total_price is persisted in database
        $item = $order->items->first();
        $this->assertNotNull($item);
        $this->assertEquals(37500, $item->line_total);
        $this->assertEquals(37500, $item->total_price);

        // Assert stock was reserved
        $stock = WarehouseStock::first();
        $this->assertEquals(5, $stock->reserved_quantity);

        // Assert stock transaction was recorded
        $transaction = StockTransaction::where('type', 'RESERVE')->first();
        $this->assertNotNull($transaction);
        $this->assertEquals(5, $transaction->quantity_change);
    }

    /** @test */
    public function it_enforces_idempotency_to_prevent_duplicate_orders()
    {
        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'discount_type' => 'FIXED',
            'discount_amount' => 10,
            'shared_key' => 'test-order-key-1',
            'version' => 1,
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 3,
                ]
            ]
        ];

        // Send first request
        $response1 = $this->actingAs($this->salesman)
            ->postJson('/api/v1/orders', $payload);

        $response1->assertStatus(200);

        // Send identical second request immediately
        $response2 = $this->actingAs($this->salesman)
            ->postJson('/api/v1/orders', $payload);

        $response2->assertStatus(200);

        // Assert only ONE order was created
        $this->assertEquals(1, SalesOrder::count());
    }

    /** @test */
    public function it_creates_purchase_requirement_on_stock_shortage()
    {
        // Reduce warehouse stock quantity to 2
        WarehouseStock::where('product_id', $this->product->id)->update(['quantity' => 2]);

        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'discount_type' => 'FIXED',
            'discount_amount' => 10,
            'shared_key' => 'test-order-key-1',
            'version' => 1,
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 5, // Requires 5, but only 2 available
                ]
            ]
        ];

        $response = $this->actingAs($this->salesman)
            ->postJson('/api/v1/orders', $payload);

        $response->assertStatus(200);

        // Assert stock reserved was limited to available (2)
        $stock = WarehouseStock::first();
        $this->assertEquals(2, $stock->reserved_quantity);

        // Assert purchase requirement was created for the shortage (3)
        $requirement = PurchaseRequirement::first();
        $this->assertNotNull($requirement);
        $this->assertEquals(3, $requirement->required_quantity);
        $this->assertEquals('OPEN', $requirement->status);
    }

    /** @test */
    public function it_reverts_reservation_on_cancellation()
    {
        // Create confirmed order
        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'discount_type' => 'FIXED',
            'discount_amount' => 10,
            'shared_key' => 'test-order-key-1',
            'version' => 1,
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 4,
                ]
            ]
        ];

        $this->actingAs($this->salesman)->postJson('/api/v1/orders', $payload);

        $order = SalesOrder::first();
        $stock = WarehouseStock::first();
        $this->assertEquals(4, $stock->reserved_quantity);

        // Cancel order
        $response = $this->actingAs($this->salesman)
            ->postJson("/api/v1/orders/{$order->id}/status", [
                'status' => SalesOrder::STATUS_CANCELLED
            ]);

        $response->assertStatus(200);

        // Assert stock reserved was decremented to 0
        $stock->refresh();
        $this->assertEquals(0, $stock->reserved_quantity);

        // Assert RELEASE transaction was recorded
        $transaction = StockTransaction::where('type', 'RELEASE')->first();
        $this->assertNotNull($transaction);
        $this->assertEquals(-4, $transaction->quantity_change);
    }

    /** @test */
    public function it_posts_to_ledger_and_updates_balance_on_delivery()
    {
        // Give salesman role all permissions for simplicity in this full-flow test
        $this->salesman->role->update(['permissions' => ['orders.create', 'stock.pack', 'delivery.update']]);

        // 1. Create order (auto-confirmed)
        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'discount_type' => 'FIXED',
            'discount_amount' => 10,
            'shared_key' => 'test-order-key-1',
            'version' => 1,
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 2, // total = 7500 * 2 = 15000
                ]
            ]
        ];

        $this->actingAs($this->salesman)->postJson('/api/v1/orders', $payload);
        $order = SalesOrder::first();

        // 2. Transition status flow: CONFIRMED -> PACKING -> READY -> IN_DELIVERY -> DELIVERED
        $this->actingAs($this->salesman)->postJson("/api/v1/orders/{$order->id}/status", ['status' => SalesOrder::STATUS_PACKING]);
        
        // Pack the item first so we can transition to READY
        $item = $order->items()->first();
        $item->update(['is_packed' => true]);

        $this->actingAs($this->salesman)->postJson("/api/v1/orders/{$order->id}/status", ['status' => SalesOrder::STATUS_READY]);
        $this->actingAs($this->salesman)->postJson("/api/v1/orders/{$order->id}/status", ['status' => SalesOrder::STATUS_IN_DELIVERY]);

        // Deliver order
        $response = $this->actingAs($this->salesman)->postJson("/api/v1/orders/{$order->id}/status", [
            'status' => SalesOrder::STATUS_DELIVERED
        ]);

        $response->assertStatus(200);

        // Assert warehouse stock decreased
        $stock = WarehouseStock::first();
        $this->assertEquals(8, $stock->quantity); // 10 - 2 = 8
        $this->assertEquals(0, $stock->reserved_quantity); // 2 - 2 = 0

        // Assert customer ledger SALE debit entry was recorded
        $ledger = CustomerLedger::where('entry_type', 'SALE')->first();
        $this->assertNotNull($ledger);
        $this->assertEquals('debit', $ledger->type);
        $this->assertEquals(15000, $ledger->debit);
        $this->assertEquals(15000, $ledger->balance_after);

        // Assert customer current balance was updated
        $customer = Customer::first();
        $this->assertEquals(15000, $customer->current_balance);
    }

    /** @test */
    public function it_rejects_invalid_transitions()
    {
        $this->salesman->role->update(['permissions' => ['orders.create', 'stock.pack', 'delivery.update']]);

        // 1. Create order (auto-confirmed)
        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'discount_type' => 'FIXED',
            'discount_amount' => 10,
            'shared_key' => 'test-order-key-1',
            'version' => 1,
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 2,
                ]
            ]
        ];

        $this->actingAs($this->salesman)->postJson('/api/v1/orders', $payload);
        $order = SalesOrder::first(); // Currently CONFIRMED

        // Attempt invalid transitions: CONFIRMED -> DELIVERED (Must go through PACKING -> READY -> IN_DELIVERY first)
        $response = $this->actingAs($this->salesman)->postJson("/api/v1/orders/{$order->id}/status", [
            'status' => SalesOrder::STATUS_DELIVERED
        ]);
        $response->assertStatus(422); // Rejects invalid transitions

        // Attempt invalid transition: CONFIRMED -> IN_DELIVERY
        $response = $this->actingAs($this->salesman)->postJson("/api/v1/orders/{$order->id}/status", [
            'status' => SalesOrder::STATUS_IN_DELIVERY
        ]);
        $response->assertStatus(422);
    }

    /** @test */
    public function it_enforces_permissions_for_each_state_transition()
    {
        // 1. Create a pure salesman user who has ONLY orders.create
        $salesmanRole = Role::create([
            'name' => 'salesman_test',
            'display_name' => 'Salesman Test',
            'permissions' => ['orders.create']
        ]);
        $salesmanUser = User::factory()->create(['role_id' => $salesmanRole->id]);

        // 2. Create a pure packer user who has ONLY stock.pack
        $packerRole = Role::create([
            'name' => 'packer_test',
            'display_name' => 'Packer Test',
            'permissions' => ['stock.pack']
        ]);
        $packerUser = User::factory()->create(['role_id' => $packerRole->id]);

        // 3. Create order
        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'discount_type' => 'FIXED',
            'discount_amount' => 10,
            'shared_key' => 'test-order-key-1',
            'version' => 1,
            'items' => [[
                'product_id' => $this->product->id,
                'quantity' => 1,
            ]]
        ];
        $this->actingAs($this->salesman)->postJson('/api/v1/orders', $payload);
        $order = SalesOrder::first(); // CONFIRMED

        // Salesman attempts to start PACKING (Requires stock.pack) -> Should fail
        $response = $this->actingAs($salesmanUser)->postJson("/api/v1/orders/{$order->id}/status", [
            'status' => SalesOrder::STATUS_PACKING
        ]);
        $response->assertStatus(403);

        // Packer attempts to cancel or deliver (Requires orders.create or delivery.update) -> Should fail
        $response = $this->actingAs($packerUser)->postJson("/api/v1/orders/{$order->id}/status", [
            'status' => SalesOrder::STATUS_CANCELLED
        ]);
        $response->assertStatus(403);

        // Packer can transition to PACKING
        $response = $this->actingAs($packerUser)->postJson("/api/v1/orders/{$order->id}/status", [
            'status' => SalesOrder::STATUS_PACKING
        ]);
        $response->assertStatus(200);
    }

    /** @test */
    public function it_only_releases_stock_on_cancellation_if_reserved()
    {
        $this->salesman->role->update(['permissions' => ['orders.create', 'stock.pack']]);

        // Scenario A: Order in DRAFT (no stock reserved yet) -> cancel
        $orderDraft = SalesOrder::create([
            'order_number' => 'ORD-DRAFT-1',
            'customer_id' => $this->customer->id,
            'salesman_id' => $this->salesman->id,
            'warehouse_id' => $this->warehouse->id,
            'order_date' => now()->toDateString(),
            'status' => SalesOrder::STATUS_DRAFT,
            'subtotal' => 15000,
            'total_amount' => 15000,
            'total_profit' => 5000,
            'created_by' => $this->salesman->id,
        ]);

        $stockBefore = WarehouseStock::first()->reserved_quantity;

        // Cancel the DRAFT order
        $response = $this->actingAs($this->salesman)->postJson("/api/v1/orders/{$orderDraft->id}/status", [
            'status' => SalesOrder::STATUS_CANCELLED
        ]);
        $response->assertStatus(200);

        // Verify reserved stock didn't change (still 0)
        $stockAfter = WarehouseStock::first()->reserved_quantity;
        $this->assertEquals($stockBefore, $stockAfter);

        // Scenario B: Order in CONFIRMED (stock is reserved) -> cancel
        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'discount_type' => 'FIXED',
            'discount_amount' => 10,
            'shared_key' => 'test-order-key-1',
            'version' => 1,
            'items' => [[
                'product_id' => $this->product->id,
                'quantity' => 3,
            ]]
        ];
        $this->actingAs($this->salesman)->postJson('/api/v1/orders', $payload);
        $orderConfirmed = SalesOrder::orderBy('id', 'desc')->first();

        $stockReserved = WarehouseStock::first()->reserved_quantity;
        $this->assertEquals(3, $stockReserved);

        // Cancel the CONFIRMED order
        $response = $this->actingAs($this->salesman)->postJson("/api/v1/orders/{$orderConfirmed->id}/status", [
            'status' => SalesOrder::STATUS_CANCELLED
        ]);
        $response->assertStatus(200);

        // Verify reserved stock decremented back to 0
        $stockReleased = WarehouseStock::first()->reserved_quantity;
        $this->assertEquals(0, $stockReleased);
    }

    /** @test */
    public function it_logs_activity_audit_trail_on_transition()
    {
        $this->salesman->role->update(['permissions' => ['orders.create', 'stock.pack']]);

        // 1. Create order
        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'discount_type' => 'FIXED',
            'discount_amount' => 10,
            'shared_key' => 'test-order-key-1',
            'version' => 1,
            'items' => [[
                'product_id' => $this->product->id,
                'quantity' => 1,
            ]]
        ];
        $this->actingAs($this->salesman)->postJson('/api/v1/orders', $payload);
        $order = SalesOrder::first();

        // 2. Transition to PACKING
        $this->actingAs($this->salesman)->postJson("/api/v1/orders/{$order->id}/status", [
            'status' => SalesOrder::STATUS_PACKING
        ]);

        // Assert sync log was inserted
        $log = \DB::table('sync_logs')
            ->where('entity_type', 'sales_order')
            ->where('entity_id', $order->id)
            ->first();

        $this->assertNotNull($log);
        $this->assertEquals('UPDATE', $log->action);
        $this->assertEquals('sales_orders', $log->table_name);
        
        $payloadData = json_encode($log->payload);
        $this->assertStringContainsString('CONFIRMED', $log->payload);
        $this->assertStringContainsString('PACKING', $log->payload);
    }

    /** @test */
    public function it_correctly_releases_stock_and_syncs_delivery_trip_on_in_delivery_cancellation_and_delivery()
    {
        $this->salesman->role->update(['permissions' => ['orders.create', 'stock.pack', 'delivery.update']]);

        // 1. Create order (auto-confirmed)
        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'discount_type' => 'FIXED',
            'discount_amount' => 10,
            'shared_key' => 'test-order-key-1',
            'version' => 1,
            'items' => [[
                'product_id' => $this->product->id,
                'quantity' => 2,
            ]]
        ];
        $this->actingAs($this->salesman)->postJson('/api/v1/orders', $payload);
        $order = SalesOrder::first();

        // 2. Transition to PACKING
        $this->actingAs($this->salesman)->postJson("/api/v1/orders/{$order->id}/status", ['status' => SalesOrder::STATUS_PACKING]);

        // Pack item
        $item = $order->items()->first();
        $item->update(['is_packed' => true]);

        // 3. Transition to READY
        $this->actingAs($this->salesman)->postJson("/api/v1/orders/{$order->id}/status", ['status' => SalesOrder::STATUS_READY]);

        // 4. Transition to IN_DELIVERY
        $this->actingAs($this->salesman)->postJson("/api/v1/orders/{$order->id}/status", ['status' => SalesOrder::STATUS_IN_DELIVERY]);

        // Verify stock is still reserved
        $stock = WarehouseStock::first();
        $this->assertEquals(2, $stock->reserved_quantity);

        // Associate with a delivery trip order manually for testing sync
        $trip = \App\Models\DeliveryTrip::create([
            'trip_number' => 'TRP-123456',
            'driver_id' => $this->salesman->id,
            'trip_date' => now()->toDateString(),
            'status' => 'IN_PROGRESS',
            'created_by' => $this->salesman->id,
        ]);

        $tripOrder = $trip->orders()->create([
            'sales_order_id' => $order->id,
            'status' => 'PENDING',
            'delivery_order' => 1,
        ]);

        // 5. Cancel the order from IN_DELIVERY status
        $response = $this->actingAs($this->salesman)->postJson("/api/v1/orders/{$order->id}/status", [
            'status' => SalesOrder::STATUS_CANCELLED
        ]);
        $response->assertStatus(200);

        // Assert stock was successfully released!
        $stock->refresh();
        $this->assertEquals(0, $stock->reserved_quantity);

        // Assert delivery trip order was updated to FAILED with reason
        $tripOrder->refresh();
        $this->assertEquals('FAILED', $tripOrder->status);
        $this->assertEquals('Cancelled via Sales Order', $tripOrder->failed_reason);
    }

    /** @test */
    public function it_treats_same_status_transitions_as_idempotent_no_ops()
    {
        $this->salesman->role->update(['permissions' => ['orders.create', 'stock.pack']]);

        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'discount_type' => 'FIXED',
            'discount_amount' => 10,
            'shared_key' => 'test-order-key-1',
            'version' => 1,
            'items' => [[
                'product_id' => $this->product->id,
                'quantity' => 1,
            ]]
        ];
        $this->actingAs($this->salesman)->postJson('/api/v1/orders', $payload);
        $order = SalesOrder::first(); // CONFIRMED

        // Request transition to CONFIRMED again (already CONFIRMED)
        $response = $this->actingAs($this->salesman)->postJson("/api/v1/orders/{$order->id}/status", [
            'status' => SalesOrder::STATUS_CONFIRMED
        ]);

        $response->assertStatus(200);
        $order->refresh();
        $this->assertEquals(SalesOrder::STATUS_CONFIRMED, $order->status);
    }

    /** @test */
    public function it_blocks_transitions_from_terminal_states()
    {
        $this->salesman->role->update(['permissions' => ['orders.create', 'stock.pack', 'delivery.update']]);

        // Scenario 1: DELIVERED order cannot be cancelled or moved to any other state
        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'discount_type' => 'FIXED',
            'discount_amount' => 10,
            'shared_key' => 'test-order-key-1',
            'version' => 1,
            'items' => [[
                'product_id' => $this->product->id,
                'quantity' => 1,
            ]]
        ];
        $this->actingAs($this->salesman)->postJson('/api/v1/orders', $payload);
        $order = SalesOrder::first();

        $this->actingAs($this->salesman)->postJson("/api/v1/orders/{$order->id}/status", ['status' => SalesOrder::STATUS_PACKING]);
        $order->items()->first()->update(['is_packed' => true]);
        $this->actingAs($this->salesman)->postJson("/api/v1/orders/{$order->id}/status", ['status' => SalesOrder::STATUS_READY]);
        $this->actingAs($this->salesman)->postJson("/api/v1/orders/{$order->id}/status", ['status' => SalesOrder::STATUS_IN_DELIVERY]);
        $this->actingAs($this->salesman)->postJson("/api/v1/orders/{$order->id}/status", ['status' => SalesOrder::STATUS_DELIVERED]);

        $order->refresh();
        $this->assertEquals(SalesOrder::STATUS_DELIVERED, $order->status);

        // Attempt CANCELLED from DELIVERED -> Must fail 422
        $response = $this->actingAs($this->salesman)->postJson("/api/v1/orders/{$order->id}/status", [
            'status' => SalesOrder::STATUS_CANCELLED
        ]);
        $response->assertStatus(422);

        // Scenario 2: CANCELLED order cannot be moved to CONFIRMED or any other state
        $orderCancelled = SalesOrder::create([
            'order_number' => 'ORD-CANC-1',
            'customer_id' => $this->customer->id,
            'salesman_id' => $this->salesman->id,
            'warehouse_id' => $this->warehouse->id,
            'order_date' => now()->toDateString(),
            'status' => SalesOrder::STATUS_CANCELLED,
            'subtotal' => 5000,
            'total_amount' => 5000,
            'total_profit' => 1000,
            'created_by' => $this->salesman->id,
        ]);

        $response = $this->actingAs($this->salesman)->postJson("/api/v1/orders/{$orderCancelled->id}/status", [
            'status' => SalesOrder::STATUS_CONFIRMED
        ]);
        $response->assertStatus(422);
    }

    /** @test */
    public function it_calculates_price_tiers_and_snapshots_historical_prices_correctly()
    {
        // 1. Customer with tier N1
        $this->customer->update(['price_type' => 'N1']);

        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'discount_type' => 'FIXED',
            'discount_amount' => 10,
            'shared_key' => 'test-order-key-1',
            'version' => 1,
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 2,
                ]
            ]
        ];

        $response = $this->actingAs($this->salesman)->postJson('/api/v1/orders', $payload);
        $response->assertStatus(201);

        $order = SalesOrder::with('items')->latest('id')->first();
        $this->assertEquals(16000, $order->subtotal); // 2 * 8000 (price_n1)
        $this->assertEquals(16000, $order->total_amount);
        $this->assertEquals(6000, $order->total_profit); // (8000 - 5000) * 2

        $item = $order->items->first();
        $this->assertEquals(8000, $item->unit_price);
        $this->assertEquals(5000, $item->cost_price);
        $this->assertEquals(16000, $item->line_total);
        $this->assertEquals(6000, $item->profit);

        // Change product price now, old order and item must NOT change
        $this->product->update([
            'price_n1' => 12000,
            'cost_price' => 9000,
        ]);

        $order->refresh();
        $item->refresh();
        $this->assertEquals(16000, $order->subtotal);
        $this->assertEquals(8000, $item->unit_price);
        $this->assertEquals(5000, $item->cost_price);
    }

    /** @test */
    public function it_applies_active_special_customer_price_over_standard_tier()
    {
        // Add special price of 6500 for customer and product
        \App\Models\CustomerSpecialPrice::create([
            'customer_id' => $this->customer->id,
            'product_id' => $this->product->id,
            'price' => 6500,
            'start_date' => now()->subDay()->toDateString(),
            'end_date' => now()->addDay()->toDateString(),
            'is_active' => true,
        ]);

        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'discount_type' => 'FIXED',
            'discount_amount' => 10,
            'shared_key' => 'test-order-key-1',
            'version' => 1,
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 2,
                ]
            ]
        ];

        $response = $this->actingAs($this->salesman)->postJson('/api/v1/orders', $payload);
        $response->assertStatus(201);

        $order = SalesOrder::with('items')->latest('id')->first();
        $this->assertEquals(13000, $order->subtotal); // 2 * 6500
        $this->assertEquals(13000, $order->total_amount);
        $this->assertEquals(3000, $order->total_profit); // (6500 - 5000) * 2

        $item = $order->items->first();
        $this->assertEquals(6500, $item->unit_price);
        $this->assertEquals('SPECIAL', $item->price_type);
    }

    /** @test */
    public function it_calculates_permanent_discount_and_invoice_discount_in_proper_order()
    {
        // Customer has 10% permanent discount
        $this->customer->update([
            'price_type' => 'N2', // Unit price 7500
            'permanent_discount' => 10,
        ]);

        // Order has 5% invoice discount
        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'discount_percent' => 5,
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 2, // 2 * 7500 = 15,000 subtotal
                ]
            ]
        ];

        $response = $this->actingAs($this->salesman)->postJson('/api/v1/orders', $payload);
        $response->assertStatus(201);

        $order = SalesOrder::latest('id')->first();
        // Subtotal = 15,000
        // Permanent Discount 10% = 1,500
        // Remaining after Perm = 13,500
        // Invoice Discount 5% of 13,500 = 675
        // Final Total = 13,500 - 675 = 12,825
        $this->assertEquals(15000, $order->subtotal);
        $this->assertEquals(10, (float)$order->permanent_discount_percent);
        $this->assertEquals(1500, $order->permanent_discount_amount);
        $this->assertEquals(5, (float)$order->discount_percent);
        $this->assertEquals(675, $order->discount_amount);
        $this->assertEquals(12825, $order->total_amount);
        $this->assertEquals(5000, $order->total_profit); // Profit on items: (7500 - 5000) * 2
    }

    /**
     * Test dual-entry shared-order creation with unique shared_key.
     */
    public function test_dual_entry_shared_order_creation_and_reconciliation(): void
    {
        $sharedKey = 'shared_key_123';

        $payload1 = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'shared_key' => $sharedKey,
            'version' => 1,
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 2,
                ]
            ]
        ];

        // First device creates the order
        $response1 = $this->actingAs($this->salesman)->postJson('/api/v1/orders', $payload1);
        $response1->assertStatus(201);
        $orderId = $response1->json('data.id');

        // Check it has version 1 and shared_key in database
        $order = SalesOrder::findOrFail($orderId);
        $this->assertEquals($sharedKey, $order->shared_key);
        $this->assertEquals(1, $order->version);

        // Second device edits/reconciles the same order (increasing quantity to 5)
        $payload2 = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'shared_key' => $sharedKey,
            'version' => 1, // Correct matching version
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 5,
                ]
            ]
        ];

        $response2 = $this->actingAs($this->salesman)->postJson('/api/v1/orders', $payload2);
        $response2->assertStatus(200); // 200 OK because it updated the existing shared order
        $this->assertEquals($orderId, $response2->json('data.id'));

        // Verify version incremented to 2 and quantity recalculated on server
        $updatedOrder = SalesOrder::findOrFail($orderId);
        $this->assertEquals(2, $updatedOrder->version);
        $this->assertCount(1, $updatedOrder->items);
        $this->assertEquals(5, $updatedOrder->items->first()->quantity);
    }

    /**
     * Test optimistic locking and stale client data rejection.
     */
    public function test_dual_entry_stale_client_data_causes_conflict(): void
    {
        $sharedKey = 'shared_key_456';

        // 1. Initial creation
        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'shared_key' => $sharedKey,
            'version' => 1,
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 2,
                ]
            ]
        ];
        $this->actingAs($this->salesman)->postJson('/api/v1/orders', $payload)->assertStatus(201);

        // 2. First edit by device A (advances version to 2)
        $payloadDeviceA = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'shared_key' => $sharedKey,
            'version' => 1,
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 3,
                ]
            ]
        ];
        $this->actingAs($this->salesman)->postJson('/api/v1/orders', $payloadDeviceA)->assertStatus(200);

        // 3. Stale edit by device B sending version 1 (but database is already version 2)
        $payloadDeviceB = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'shared_key' => $sharedKey,
            'version' => 1, // Stale!
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 4,
                ]
            ]
        ];
        $response = $this->actingAs($this->salesman)->postJson('/api/v1/orders', $payloadDeviceB);
        $response->assertStatus(422); // Rejects stale client request with ValidationException error code
        $response->assertJsonValidationErrors('version');
    }

    /**
     * Test status consistency of shared orders. Editing processed order is forbidden.
     */
    public function test_editing_locked_shared_order_fails(): void
    {
        $sharedKey = 'shared_key_789';

        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'shared_key' => $sharedKey,
            'version' => 1,
            'status' => 'CONFIRMED', // Immediately confirmed
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 2,
                ]
            ]
        ];
        $this->actingAs($this->salesman)->postJson('/api/v1/orders', $payload)->assertStatus(201);

        // Try to edit the confirmed order cooperatively
        $payloadEdit = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'shared_key' => $sharedKey,
            'version' => 1,
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 10,
                ]
            ]
        ];

        // Should fail because status is CONFIRMED and not DRAFT
        $this->expectException(\RuntimeException::class);
        $service = resolve(\App\Services\SalesOrderService::class);
        $service->createOrder($payloadEdit, $this->salesman);
    }

    /** @test */
    public function it_persists_sales_order_item_total_price_correctly_on_creation_and_update()
    {
        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => 'DRAFT',
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 4,
                ]
            ]
        ];

        $response = $this->actingAs($this->salesman)->postJson('/api/v1/orders', $payload);
        $response->assertStatus(201);

        $order = SalesOrder::with('items')->latest('id')->first();
        $this->assertCount(1, $order->items);

        $item = $order->items->first();
        // Price N2 = 7500. Quantity = 4. line_total = 30000. total_price = 30000.
        $this->assertEquals(30000, $item->line_total);
        $this->assertEquals(30000, $item->total_price);
        $this->assertEquals(30000, $order->subtotal);
        $this->assertEquals(10000, $order->total_profit); // (7500 - 5000) * 4

        // Update draft order with new quantity
        $updatePayload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 6,
                ]
            ]
        ];

        $updateResponse = $this->actingAs($this->salesman)->putJson("/api/v1/orders/{$order->id}", $updatePayload);
        $updateResponse->assertStatus(200);

        $order->refresh();
        $updatedItem = $order->items()->first();

        // Price N2 = 7500. Quantity = 6. line_total = 45000. total_price = 45000.
        $this->assertEquals(45000, $updatedItem->line_total);
        $this->assertEquals(45000, $updatedItem->total_price);
        $this->assertEquals(45000, $order->subtotal);
        $this->assertEquals(15000, $order->total_profit); // (7500 - 5000) * 6
    }
}

