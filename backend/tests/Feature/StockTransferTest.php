<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Role;
use App\Models\Warehouse;
use App\Models\WarehouseStock;
use App\Models\Product;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class StockTransferTest extends TestCase
{
    use RefreshDatabase;

    protected $admin;

    protected function setUp(): void
    {
        parent::setUp();
        $role = Role::firstOrCreate(['name' => 'admin']);
        $this->admin = User::factory()->create(['role_id' => $role->id, 'is_active' => true]);
    }

    /** @test */
    public function it_can_transfer_stock_between_warehouses()
    {
        $warehouse1 = Warehouse::create(['name' => 'WH 1']);
        $warehouse2 = Warehouse::create(['name' => 'WH 2']);
        $product = Product::create(['name' => 'Prod A', 'sku' => 'PA', 'cost_price' => 100]);
        
        WarehouseStock::create([
            'warehouse_id' => $warehouse1->id,
            'product_id' => $product->id,
            'quantity' => 50,
            'reserved_quantity' => 0
        ]);

        $payload = [
            'from_warehouse_id' => $warehouse1->id,
            'to_warehouse_id' => $warehouse2->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 10]
            ]
        ];

        $response = $this->actingAs($this->admin)->postJson('/api/v1/stock-transfers', $payload);

        $response->assertStatus(201);
        
        $this->assertEquals(40, WarehouseStock::where('warehouse_id', $warehouse1->id)->where('product_id', $product->id)->first()->quantity);
        $this->assertEquals(10, WarehouseStock::where('warehouse_id', $warehouse2->id)->where('product_id', $product->id)->first()->quantity);
    }
}
