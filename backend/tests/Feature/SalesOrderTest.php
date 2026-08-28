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
            'discount_percent' => 10, // 10% discount
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
        $order = SalesOrder::first();
        $this->assertNotNull($order);
        $this->assertEquals(SalesOrder::STATUS_CONFIRMED, $order->status);
        $this->assertEquals(37500, $order->subtotal); // 7500 * 5 = 37500
        $this->assertEquals(3750, $order->discount_amount); // 10% of 37500 = 3750
        $this->assertEquals(33750, $order->total_amount); // 37500 - 3750 = 33750
        $this->assertEquals(12500, $order->total_profit); // (7500 - 5000) * 5 = 12500

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
        // 1. Create order (auto-confirmed)
        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
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
}
