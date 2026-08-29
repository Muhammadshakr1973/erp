<?php

namespace Tests\Feature;

use App\Models\Customer;
use App\Models\Product;
use App\Models\Role;
use App\Models\SalesOrder;
use App\Models\User;
use App\Models\Warehouse;
use App\Models\WarehouseStock;
use App\Models\PurchaseRequirement;
use App\Models\PurchaseOrder;
use App\Models\Supplier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PurchaseRequirementTest extends TestCase
{
    use RefreshDatabase;

    protected User $admin;
    protected Customer $customer;
    protected Warehouse $warehouse;
    protected Product $product;
    protected Supplier $supplier;

    protected function setUp(): void
    {
        parent::setUp();

        // Create admin role
        $adminRole = Role::create([
            'name' => 'admin',
            'display_name' => 'Administrator',
            'permissions' => ['orders.create', 'suppliers.manage', 'stock.view']
        ]);

        // Create user
        $this->admin = User::factory()->create([
            'role_id' => $adminRole->id,
            'is_active' => true,
        ]);

        // Create route
        $route = \App\Models\Route::create([
            'name' => 'Route A',
            'is_active' => true,
        ]);

        // Create customer
        $this->customer = Customer::create([
            'name' => 'Customer A',
            'phone' => '07701234567',
            'route_id' => $route->id,
            'price_tier' => 'N1',
            'is_active' => true,
        ]);

        // Create supplier
        $this->supplier = Supplier::create([
            'name' => 'Supplier A',
            'phone' => '07501234567',
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
            'sku' => 'TP-001',
            'supplier_id' => $this->supplier->id,
            'cost_price' => 5000,
            'price_n1' => 8000,
            'price_n2' => 7500,
            'price_n3' => 7000,
            'is_active' => true,
        ]);
    }

    /** @test */
    public function it_does_not_create_purchase_requirement_when_there_is_enough_stock()
    {
        // Setup warehouse stock with enough physical quantity
        WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 10,
            'reserved_quantity' => 0,
        ]);

        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'items' => [[
                'product_id' => $this->product->id,
                'quantity' => 4,
            ]]
        ];

        // Create order (auto-confirmed, which triggers reserveStock)
        $response = $this->actingAs($this->admin)->postJson('/api/v1/orders', $payload);
        $response->assertStatus(201);

        // Verify no purchase requirements were created
        $this->assertEquals(0, PurchaseRequirement::count());

        // Verify stock is reserved
        $stock = WarehouseStock::first();
        $this->assertEquals(4, $stock->reserved_quantity);
    }

    /** @test */
    public function it_creates_purchase_requirement_when_there_is_insufficient_stock()
    {
        // Setup warehouse stock with 0 quantity
        WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 0,
            'reserved_quantity' => 0,
        ]);

        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'items' => [[
                'product_id' => $this->product->id,
                'quantity' => 5,
            ]]
        ];

        $response = $this->actingAs($this->admin)->postJson('/api/v1/orders', $payload);
        $response->assertStatus(201);

        // Verify purchase requirement is created with shortage = 5
        $this->assertEquals(1, PurchaseRequirement::count());
        $req = PurchaseRequirement::first();
        $this->assertEquals(5, $req->required_quantity);
        $this->assertEquals(0, $req->current_stock);
        $this->assertEquals('OPEN', $req->status);
        $this->assertEquals($this->supplier->id, $req->supplier_id);
    }

    /** @test */
    public function it_accounts_for_reserved_stock_correctly()
    {
        // 10 physical stock, but 8 are already reserved (available = 2)
        WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 10,
            'reserved_quantity' => 8,
        ]);

        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'items' => [[
                'product_id' => $this->product->id,
                'quantity' => 5, // Requires 5, available is 2, so shortage must be 3
            ]]
        ];

        $response = $this->actingAs($this->admin)->postJson('/api/v1/orders', $payload);
        $response->assertStatus(201);

        // Verify requirement shortage is exactly 3
        $this->assertEquals(1, PurchaseRequirement::count());
        $req = PurchaseRequirement::first();
        $this->assertEquals(3, $req->required_quantity);
    }

    /** @test */
    public function it_prevents_duplicate_requirements_and_updates_on_re_reservation()
    {
        WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 0,
            'reserved_quantity' => 0,
        ]);

        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'items' => [[
                'product_id' => $this->product->id,
                'quantity' => 5,
            ]]
        ];

        $response = $this->actingAs($this->admin)->postJson('/api/v1/orders', $payload);
        $orderId = $response->json('data.id');

        // Verify 1 requirement exists for this order
        $this->assertEquals(1, PurchaseRequirement::where('sales_order_id', $orderId)->count());

        // Re-post/trigger reservation for same order (simulate update/re-check if status changed)
        // Calling status update triggers transitions, let's call reserveStock directly on service or create another item
        $order = SalesOrder::find($orderId);
        $service = app(\App\Services\SalesOrderService::class);
        
        // This should update/keep the same requirement rather than duplicating it
        $this->actingAs($this->admin)->postJson("/api/v1/orders/{$orderId}/status", [
            'status' => 'CONFIRMED'
        ]);

        $this->assertEquals(1, PurchaseRequirement::where('sales_order_id', $orderId)->count());
    }

    /** @test */
    public function it_creates_multiple_requirements_separately_for_different_orders()
    {
        WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 0,
            'reserved_quantity' => 0,
        ]);

        // Order 1
        $this->actingAs($this->admin)->postJson('/api/v1/orders', [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'items' => [['product_id' => $this->product->id, 'quantity' => 3]]
        ]);

        // Order 2
        $this->actingAs($this->admin)->postJson('/api/v1/orders', [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'items' => [['product_id' => $this->product->id, 'quantity' => 7]]
        ]);

        // There should be exactly 2 separate requirements, preserving their sales order references
        $this->assertEquals(2, PurchaseRequirement::count());
        $reqs = PurchaseRequirement::orderBy('id', 'asc')->get();
        $this->assertEquals(3, $reqs[0]->required_quantity);
        $this->assertEquals(7, $reqs[1]->required_quantity);
    }

    /** @test */
    public function it_converts_requirements_to_purchase_orders_grouped_by_supplier_and_warehouse()
    {
        // Create 2 open requirements for the same supplier and warehouse
        $req1 = PurchaseRequirement::create([
            'product_id' => $this->product->id,
            'warehouse_id' => $this->warehouse->id,
            'supplier_id' => $this->supplier->id,
            'required_quantity' => 10,
            'current_stock' => 0,
            'status' => 'OPEN',
            'created_by' => $this->admin->id,
        ]);

        $product2 = Product::create([
            'name' => 'Product 2',
            'sku' => 'TP-002',
            'supplier_id' => $this->supplier->id,
            'cost_price' => 3000,
            'is_active' => true,
        ]);

        $req2 = PurchaseRequirement::create([
            'product_id' => $product2->id,
            'warehouse_id' => $this->warehouse->id,
            'supplier_id' => $this->supplier->id,
            'required_quantity' => 5,
            'current_stock' => 0,
            'status' => 'OPEN',
            'created_by' => $this->admin->id,
        ]);

        $payload = [
            'requirement_ids' => [$req1->id, $req2->id],
            'notes' => 'Bulk conversion test'
        ];

        $response = $this->actingAs($this->admin)->postJson('/api/v1/purchase-requirements/convert', $payload);
        $response->assertStatus(200);

        // Verify a single Purchase Order was created (since same supplier & warehouse)
        $this->assertEquals(1, PurchaseOrder::count());
        $po = PurchaseOrder::with('items')->first();
        $this->assertEquals($this->supplier->id, $po->supplier_id);
        $this->assertEquals($this->warehouse->id, $po->warehouse_id);
        $this->assertEquals('DRAFT', $po->status);

        // Items check: 2 items in PO
        $this->assertCount(2, $po->items);
        $this->assertEquals(10 * 5000 + 5 * 3000, $po->total_amount);

        // Requirements status check
        $req1->refresh();
        $req2->refresh();
        $this->assertEquals('ORDERED', $req1->status);
        $this->assertEquals('ORDERED', $req2->status);
    }

    /** @test */
    public function it_prevents_duplicate_conversion_of_same_purchase_requirement()
    {
        $req = PurchaseRequirement::create([
            'product_id' => $this->product->id,
            'warehouse_id' => $this->warehouse->id,
            'supplier_id' => $this->supplier->id,
            'required_quantity' => 10,
            'current_stock' => 0,
            'status' => 'OPEN',
            'created_by' => $this->admin->id,
        ]);

        $payload = [
            'requirement_ids' => [$req->id]
        ];

        // First conversion - succeeds
        $response1 = $this->actingAs($this->admin)->postJson('/api/v1/purchase-requirements/convert', $payload);
        $response1->assertStatus(200);

        // Second conversion of the same requirement - must fail
        $response2 = $this->actingAs($this->admin)->postJson('/api/v1/purchase-requirements/convert', $payload);
        $response2->assertStatus(422);
        $response2->assertJsonValidationErrors('requirement_ids');
    }
}
