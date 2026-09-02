<?php

namespace Tests\Feature;

use App\Models\Customer;
use App\Models\Product;
use App\Models\Role;
use App\Models\SalesOrder;
use App\Models\SalesOrderItem;
use App\Models\SalesReturn;
use App\Models\User;
use App\Models\Warehouse;
use App\Models\WarehouseStock;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SalesReturnMinStockTest extends TestCase
{
    use RefreshDatabase;

    protected User $salesman;
    protected Customer $customer;
    protected Warehouse $warehouse;
    protected Product $product;

    protected function setUp(): void
    {
        parent::setUp();

        $salesmanRole = Role::firstOrCreate(
            ['name' => Role::SALESMAN],
            [
                'display_name' => 'Salesman',
                'permissions' => ['orders.create', 'orders.view']
            ]
        );

        $this->salesman = User::factory()->create([
            'role_id' => $salesmanRole->id,
            'is_active' => true,
        ]);

        $route = \App\Models\Route::create([
            'name' => 'Route A',
            'is_active' => true,
        ]);

        $this->customer = Customer::create([
            'route_id' => $route->id,
            'name' => 'Test Customer',
            'price_type' => 'N2',
            'current_balance' => 15000,
            'is_active' => true,
        ]);

        $this->warehouse = Warehouse::create([
            'name' => 'Main Warehouse',
            'is_main' => true,
            'is_active' => true,
        ]);

        $this->product = Product::create([
            'name' => 'Test Product',
            'sku' => 'TEST-SKU-1',
            'unit' => 'PCS',
            'cost_price' => 5000,
            'price_n1' => 8000,
            'price_n2' => 7500,
            'price_n3' => 7000,
            'is_active' => true,
        ]);

        // Note: No WarehouseStock is seeded for this product/warehouse combination
    }

    /** @test */
    public function it_uses_database_default_min_stock_level_when_creating_stock_during_return()
    {
        // 1. Create a delivered order for the product
        $order = SalesOrder::create([
            'order_number' => 'SO-TEST-1',
            'customer_id' => $this->customer->id,
            'salesman_id' => $this->salesman->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => SalesOrder::STATUS_DELIVERED,
            'subtotal' => 7500,
            'total_amount' => 7500,
            'created_by' => $this->salesman->id,
            'order_date' => now()->toDateString(),
        ]);

        $orderItem = SalesOrderItem::create([
            'sales_order_id' => $order->id,
            'product_id' => $this->product->id,
            'quantity' => 1,
            'unit_price' => 7500,
            'cost_price' => 5000,
            'line_total' => 7500,
            'price_type' => 'N2',
        ]);

        // Verify stock doesn't exist yet
        $this->assertDatabaseMissing('warehouse_stock', [
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
        ]);

        // 2. Perform sales return
        $payload = [
            'sales_order_id' => $order->id,
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 1,
                ]
            ]
        ];

        $response = $this->actingAs($this->salesman)
            ->postJson('/api/v1/sales-returns', $payload);

        $response->assertStatus(201);

        // 3. Verify WarehouseStock was created with default min_stock_level (0), not hard-coded (5)
        $stock = WarehouseStock::where([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
        ])->first();

        $this->assertNotNull($stock, 'WarehouseStock should have been created');
        $this->assertEquals(0, $stock->min_stock_level, 'min_stock_level should be 0 (database default), not 5');
        $this->assertEquals(1, $stock->quantity);
    }

    /** @test */
    public function it_preserves_existing_min_stock_level_for_existing_stock_rows()
    {
        // 1. Pre-seed stock with a specific min_stock_level
        WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 10,
            'reserved_quantity' => 0,
            'min_stock_level' => 15, // Custom threshold
        ]);

        $order = SalesOrder::create([
            'order_number' => 'SO-TEST-2',
            'customer_id' => $this->customer->id,
            'salesman_id' => $this->salesman->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => SalesOrder::STATUS_DELIVERED,
            'subtotal' => 7500,
            'total_amount' => 7500,
            'created_by' => $this->salesman->id,
            'order_date' => now()->toDateString(),
        ]);

        $orderItem = SalesOrderItem::create([
            'sales_order_id' => $order->id,
            'product_id' => $this->product->id,
            'quantity' => 1,
            'unit_price' => 7500,
            'cost_price' => 5000,
            'line_total' => 7500,
            'price_type' => 'N2',
        ]);

        // 2. Perform sales return
        $payload = [
            'sales_order_id' => $order->id,
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 1,
                ]
            ]
        ];

        $this->actingAs($this->salesman)
            ->postJson('/api/v1/sales-returns', $payload)
            ->assertStatus(201);

        // 3. Verify existing min_stock_level is preserved
        $stock = WarehouseStock::where([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
        ])->first();

        $this->assertEquals(15, $stock->min_stock_level);
        $this->assertEquals(11, $stock->quantity);
    }

    /** @test */
    public function it_correctly_identifies_low_stock_based_on_min_stock_level()
    {
        // 1. Create stock with min_stock_level = 5
        $stock = WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 4,
            'reserved_quantity' => 0,
            'min_stock_level' => 5,
        ]);

        $this->assertTrue($stock->is_low, 'Stock with quantity 4 and min_stock_level 5 should be low');

        // 2. Adjust stock to 5
        $stock->quantity = 5;
        $stock->save();
        $this->assertTrue($stock->is_low, 'Stock with quantity 5 and min_stock_level 5 should be low (inclusive)');

        // 3. Adjust stock to 6
        $stock->quantity = 6;
        $stock->save();
        $this->assertFalse($stock->is_low, 'Stock with quantity 6 and min_stock_level 5 should NOT be low');
    }
}
