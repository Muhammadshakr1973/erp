<?php

namespace Tests\Feature;

use App\Models\Customer;
use App\Models\Product;
use App\Models\Role;
use App\Models\SalesOrder;
use App\Models\SalesOrderItem;
use App\Models\User;
use App\Models\Warehouse;
use App\Models\WarehouseStock;
use App\Models\StockTransaction;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class WarehousePackingTest extends TestCase
{
    use RefreshDatabase;

    protected User $packer;
    protected Customer $customer;
    protected Warehouse $warehouse;
    protected Product $product1;
    protected Product $product2;

    protected function setUp(): void
    {
        parent::setUp();

        // Create packer role with stock.pack permission
        $packerRole = Role::create([
            'name' => 'packer',
            'display_name' => 'Packer',
            'permissions' => ['stock.pack', 'stock.view']
        ]);

        // Create user
        $this->packer = User::factory()->create([
            'role_id' => $packerRole->id,
            'is_active' => true,
        ]);

        // Create route
        $route = \App\Models\Route::create([
            'name' => 'Route A',
            'is_active' => true,
        ]);

        // Assign salesman (same packer for testing routes) to route for today
        \DB::table('route_salesmen')->insert([
            'route_id' => $route->id,
            'salesman_id' => $this->packer->id,
            'work_date' => now()->toDateString(),
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Create customer
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

        // Create products
        $this->product1 = Product::create([
            'name' => 'Product One',
            'sku' => 'SKU-1',
            'unit' => 'PCS',
            'cost_price' => 5000,
            'price_n1' => 8000,
            'price_n2' => 7500,
            'price_n3' => 7000,
            'is_active' => true,
        ]);

        $this->product2 = Product::create([
            'name' => 'Product Two',
            'sku' => 'SKU-2',
            'unit' => 'PCS',
            'cost_price' => 3000,
            'price_n1' => 5000,
            'price_n2' => 4500,
            'price_n3' => 4000,
            'is_active' => true,
        ]);

        // Seed stock
        WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product1->id,
            'quantity' => 10,
            'reserved_quantity' => 0,
        ]);

        WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product2->id,
            'quantity' => 2, // Low stock for shortage test
            'reserved_quantity' => 0,
        ]);
    }

    /** @test */
    public function it_can_list_orders_waiting_for_packing()
    {
        // Create an order in CONFIRMED status
        $order = SalesOrder::create([
            'order_number' => 'ORD-12345',
            'customer_id' => $this->customer->id,
            'salesman_id' => $this->packer->id,
            'warehouse_id' => $this->warehouse->id,
            'order_date' => now()->toDateString(),
            'status' => SalesOrder::STATUS_CONFIRMED,
            'subtotal' => 15000,
            'total_amount' => 15000,
            'total_profit' => 5000,
            'created_by' => $this->packer->id,
        ]);

        $response = $this->actingAs($this->packer)
            ->getJson('/api/v1/warehouse/orders-to-pack');

        $response->assertStatus(200)
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $order->id);
    }

    /** @test */
    public function it_can_pack_item_and_auto_transitions_order_status_to_packing()
    {
        $order = SalesOrder::create([
            'order_number' => 'ORD-12345',
            'customer_id' => $this->customer->id,
            'salesman_id' => $this->packer->id,
            'warehouse_id' => $this->warehouse->id,
            'order_date' => now()->toDateString(),
            'status' => SalesOrder::STATUS_CONFIRMED,
            'subtotal' => 15000,
            'total_amount' => 15000,
            'total_profit' => 5000,
            'created_by' => $this->packer->id,
        ]);

        $item = SalesOrderItem::create([
            'sales_order_id' => $order->id,
            'product_id' => $this->product1->id,
            'quantity' => 2,
            'unit_price' => 7500,
            'cost_price' => 5000,
            'price_type' => 'N2',
            'line_total' => 15000,
            'profit' => 5000,
            'is_packed' => false,
        ]);

        // Reserve stock
        WarehouseStock::where('product_id', $this->product1->id)->update(['reserved_quantity' => 2]);

        $response = $this->actingAs($this->packer)
            ->postJson('/api/v1/warehouse/pack-item', [
                'order_item_id' => $item->id,
                'packed' => true
            ]);

        $response->assertStatus(200);

        // Assert item status
        $item->refresh();
        $this->assertTrue($item->is_packed);
        $this->assertEquals($this->packer->id, $item->packed_by);

        // Assert order auto transitioned to PACKING
        $order->refresh();
        $this->assertEquals(SalesOrder::STATUS_PACKING, $order->status);
    }

    /** @test */
    public function it_fails_packing_if_insufficient_stock_in_warehouse()
    {
        $order = SalesOrder::create([
            'order_number' => 'ORD-12345',
            'customer_id' => $this->customer->id,
            'salesman_id' => $this->packer->id,
            'warehouse_id' => $this->warehouse->id,
            'order_date' => now()->toDateString(),
            'status' => SalesOrder::STATUS_CONFIRMED,
            'subtotal' => 75000,
            'total_amount' => 75000,
            'total_profit' => 25000,
            'created_by' => $this->packer->id,
        ]);

        $item = SalesOrderItem::create([
            'sales_order_id' => $order->id,
            'product_id' => $this->product1->id,
            'quantity' => 15, // Warehouse only has 10
            'unit_price' => 7500,
            'cost_price' => 5000,
            'price_type' => 'N2',
            'line_total' => 112500,
            'profit' => 37500,
            'is_packed' => false,
        ]);

        $response = $this->actingAs($this->packer)
            ->postJson('/api/v1/warehouse/pack-item', [
                'order_item_id' => $item->id,
                'packed' => true
            ]);

        $response->assertStatus(422); // Validation fails because of insufficient stock
    }

    /** @test */
    public function it_recalculates_totals_and_releases_reservation_for_partial_packing_on_ready()
    {
        $order = SalesOrder::create([
            'order_number' => 'ORD-12345',
            'customer_id' => $this->customer->id,
            'salesman_id' => $this->packer->id,
            'warehouse_id' => $this->warehouse->id,
            'order_date' => now()->toDateString(),
            'status' => SalesOrder::STATUS_CONFIRMED,
            'subtotal' => 24000,
            'total_amount' => 24000,
            'total_profit' => 8000,
            'created_by' => $this->packer->id,
        ]);

        $item1 = SalesOrderItem::create([
            'sales_order_id' => $order->id,
            'product_id' => $this->product1->id,
            'quantity' => 2, // 2 * 7500 = 15000
            'unit_price' => 7500,
            'cost_price' => 5000,
            'price_type' => 'N2',
            'line_total' => 15000,
            'profit' => 5000,
            'is_packed' => true, // Packed
        ]);

        $item2 = SalesOrderItem::create([
            'sales_order_id' => $order->id,
            'product_id' => $this->product2->id,
            'quantity' => 2, // 2 * 4500 = 9000
            'unit_price' => 4500,
            'cost_price' => 3000,
            'price_type' => 'N2',
            'line_total' => 9000,
            'profit' => 3000,
            'is_packed' => false, // UNPACKED
        ]);

        // Reserve stock for both
        WarehouseStock::where('product_id', $this->product1->id)->update(['reserved_quantity' => 2]);
        WarehouseStock::where('product_id', $this->product2->id)->update(['reserved_quantity' => 2]);

        // Mark the order as READY
        $response = $this->actingAs($this->packer)
            ->postJson('/api/v1/warehouse/mark-ready', [
                'order_id' => $order->id
            ]);

        $response->assertStatus(200);

        // Assert order status is READY
        $order->refresh();
        $this->assertEquals(SalesOrder::STATUS_READY, $order->status);

        // Assert order totals recalculated (only contains item1)
        $this->assertEquals(15000, $order->subtotal);
        $this->assertEquals(15000, $order->total_amount);
        $this->assertEquals(5000, $order->total_profit);

        // Assert item2 was deleted/removed from order
        $this->assertEquals(1, $order->items()->count());
        $this->assertNull(SalesOrderItem::find($item2->id));

        // Assert reservation was released for item2
        $stock2 = WarehouseStock::where('product_id', $this->product2->id)->first();
        $this->assertEquals(0, $stock2->reserved_quantity);
    }

    /** @test */
    public function it_restricts_packer_to_assigned_warehouse_orders_only()
    {
        // Create another warehouse
        $otherWarehouse = Warehouse::create([
            'name' => 'Other Warehouse',
            'is_main' => false,
            'is_active' => true,
        ]);

        // Restrict packer to the other warehouse
        $this->packer->update(['warehouse_id' => $otherWarehouse->id]);

        // Create an order in CONFIRMED status assigned to Main Warehouse
        $orderInMain = SalesOrder::create([
            'order_number' => 'ORD-MAIN',
            'customer_id' => $this->customer->id,
            'salesman_id' => $this->packer->id,
            'warehouse_id' => $this->warehouse->id,
            'order_date' => now()->toDateString(),
            'status' => SalesOrder::STATUS_CONFIRMED,
            'subtotal' => 15000,
            'total_amount' => 15000,
            'total_profit' => 5000,
            'created_by' => $this->packer->id,
        ]);

        // List orders to pack - should be empty for this packer since they are assigned to otherWarehouse
        $response = $this->actingAs($this->packer)
            ->getJson('/api/v1/warehouse/orders-to-pack');

        $response->assertStatus(200)
            ->assertJsonCount(0, 'data');

        // Create item in Main Warehouse order
        $item = SalesOrderItem::create([
            'sales_order_id' => $orderInMain->id,
            'product_id' => $this->product1->id,
            'quantity' => 1,
            'unit_price' => 7500,
            'cost_price' => 5000,
            'price_type' => 'N2',
            'line_total' => 7500,
            'profit' => 2500,
            'is_packed' => false,
        ]);

        // Attempting to pack item from Main Warehouse order must be Forbidden (403)
        $responsePack = $this->actingAs($this->packer)
            ->postJson('/api/v1/warehouse/pack-item', [
                'order_item_id' => $item->id,
                'packed' => true
            ]);

        $responsePack->assertStatus(403);

        // Attempting to mark order in Main Warehouse as Ready must be Forbidden (403)
        $responseReady = $this->actingAs($this->packer)
            ->postJson('/api/v1/warehouse/mark-ready', [
                'order_id' => $orderInMain->id
            ]);

        $responseReady->assertStatus(403);
    }
}

