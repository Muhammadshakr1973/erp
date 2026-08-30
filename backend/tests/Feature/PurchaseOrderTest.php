<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Role;
use App\Models\Supplier;
use App\Models\Warehouse;
use App\Models\Product;
use App\Models\PurchaseOrder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PurchaseOrderTest extends TestCase
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
    public function it_can_create_a_purchase_order()
    {
        $supplier = Supplier::create(['name' => 'Supplier A']);
        $warehouse = Warehouse::create(['name' => 'Main WH']);
        $product = Product::create(['name' => 'Prod A', 'sku' => 'PA', 'cost_price' => 100]);

        $payload = [
            'supplier_id' => $supplier->id,
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 10, 'unit_cost' => 100]
            ]
        ];

        $response = $this->actingAs($this->admin)->postJson('/api/v1/purchase-orders', $payload);

        $response->assertStatus(201);
        $this->assertDatabaseHas('purchase_orders', ['supplier_id' => $supplier->id]);
    }
}
