<?php

namespace Tests\Feature;

use App\Events\SalesOrderUpdated;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Role;
use App\Models\SalesOrder;
use App\Models\User;
use App\Models\Warehouse;
use App\Models\WarehouseStock;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Broadcast;
use Tests\TestCase;

class PusherRealtimeTest extends TestCase
{
    use RefreshDatabase;

    protected User $salesman;
    protected User $otherSalesman;
    protected Customer $customer;
    protected Warehouse $warehouse;
    protected Product $product;

    protected function setUp(): void
    {
        parent::setUp();

        // Create roles
        $salesmanRole = Role::create([
            'name' => Role::SALESMAN,
            'display_name' => 'Salesman',
            'permissions' => ['orders.create', 'orders.view', 'orders.update']
        ]);

        // Create salesman
        $this->salesman = User::factory()->create([
            'role_id' => $salesmanRole->id,
            'is_active' => true,
        ]);

        // Create other salesman
        $this->otherSalesman = User::factory()->create([
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
    public function channel_authorization_allows_authorized_user()
    {
        // Setup shared order
        $order = SalesOrder::create([
            'order_number' => 'ORD-12345',
            'customer_id' => $this->customer->id,
            'salesman_id' => $this->salesman->id,
            'warehouse_id' => $this->warehouse->id,
            'order_date' => now()->toDateString(),
            'status' => SalesOrder::STATUS_DRAFT,
            'version' => 1,
            'shared_key' => 'shared-key-1',
        ]);

        // Verify that the authorized salesman can subscribe
        $this->assertTrue(
            Broadcast::auth($this->salesman, 'sales-order.' . $order->id, 'sales-order.' . $order->id)
        );
    }

    /** @test */
    public function channel_authorization_rejects_unauthorized_user()
    {
        // Setup shared order
        $order = SalesOrder::create([
            'order_number' => 'ORD-12345',
            'customer_id' => $this->customer->id,
            'salesman_id' => $this->salesman->id,
            'warehouse_id' => $this->warehouse->id,
            'order_date' => now()->toDateString(),
            'status' => SalesOrder::STATUS_DRAFT,
            'version' => 1,
            'shared_key' => 'shared-key-1',
        ]);

        // Verify that the unauthorized other salesman is rejected
        $this->assertFalse(
            Broadcast::auth($this->otherSalesman, 'sales-order.' . $order->id, 'sales-order.' . $order->id)
        );
    }

    /** @test */
    public function successful_shared_order_mutation_produces_correct_event_payload()
    {
        Event::fake([SalesOrderUpdated::class]);

        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'shared_key' => 'shared-key-123',
            'version' => 1,
            'status' => SalesOrder::STATUS_DRAFT,
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 2,
                ]
            ]
        ];

        $response = $this->actingAs($this->salesman)
            ->postJson('/api/v1/orders', $payload);

        $response->assertStatus(200);

        Event::assertDispatched(SalesOrderUpdated::class, function ($event) {
            $this->assertEquals('create', $event->actionType);
            $this->assertEquals('shared-key-123', $event->order->shared_key);
            $this->assertEquals(1, $event->order->version);
            
            $broadcastWith = $event->broadcastWith();
            $this->assertEquals('create', $broadcastWith['event_type']);
            $this->assertEquals('shared-key-123', $broadcastWith['shared_key']);
            $this->assertEquals(1, $broadcastWith['version']);
            $this->assertEquals('refetch', $broadcastWith['authoritative_signal']);
            return true;
        });
    }

    /** @test */
    public function event_contains_authoritative_server_version()
    {
        Event::fake([SalesOrderUpdated::class]);

        // Create order
        $order = SalesOrder::create([
            'order_number' => 'ORD-54321',
            'customer_id' => $this->customer->id,
            'salesman_id' => $this->salesman->id,
            'warehouse_id' => $this->warehouse->id,
            'order_date' => now()->toDateString(),
            'status' => SalesOrder::STATUS_DRAFT,
            'version' => 1,
            'shared_key' => 'shared-key-789',
        ]);

        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'shared_key' => 'shared-key-789',
            'version' => 1,
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 3,
                ]
            ]
        ];

        $response = $this->actingAs($this->salesman)
            ->putJson('/api/v1/orders/' . $order->id, $payload);

        $response->assertStatus(200);

        Event::assertDispatched(SalesOrderUpdated::class, function ($event) {
            $this->assertEquals(2, $event->order->version);
            $broadcastWith = $event->broadcastWith();
            $this->assertEquals(2, $broadcastWith['version']);
            return true;
        });
    }

    /** @test */
    public function stale_version_returns_existing_409_conflict_version_behavior()
    {
        Event::fake([SalesOrderUpdated::class]);

        // Create order with version 2
        $order = SalesOrder::create([
            'order_number' => 'ORD-99999',
            'customer_id' => $this->customer->id,
            'salesman_id' => $this->salesman->id,
            'warehouse_id' => $this->warehouse->id,
            'order_date' => now()->toDateString(),
            'status' => SalesOrder::STATUS_DRAFT,
            'version' => 2,
            'shared_key' => 'shared-key-conflict',
        ]);

        // Submit client payload with stale version 1
        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'shared_key' => 'shared-key-conflict',
            'version' => 1,
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 3,
                ]
            ]
        ];

        $response = $this->actingAs($this->salesman)
            ->putJson('/api/v1/orders/' . $order->id, $payload);

        $response->assertStatus(409);
        $response->assertJson([
            'error' => 'CONFLICT_VERSION'
        ]);

        Event::assertNotDispatched(SalesOrderUpdated::class);
    }
}
