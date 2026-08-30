<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Role;
use App\Models\Supplier;
use App\Models\Warehouse;
use App\Models\Product;
use App\Models\PurchaseOrder;
use App\Models\PurchaseRequirement;
use App\Models\WarehouseStock;
use App\Models\SupplierLedger;
use App\Models\StockTransaction;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class PurchaseOrderTest extends TestCase
{
    use RefreshDatabase;

    protected $admin;
    protected $supplier;
    protected $warehouse;
    protected $product;

    protected function setUp(): void
    {
        parent::setUp();
        $role = Role::firstOrCreate(['name' => 'admin']);
        $this->admin = User::factory()->create(['role_id' => $role->id, 'is_active' => true]);
        
        $this->supplier = Supplier::create(['name' => 'Supplier A']);
        $this->warehouse = Warehouse::create(['name' => 'Main WH']);
        $this->product = Product::create(['name' => 'Prod A', 'sku' => 'PA', 'cost_price' => 100]);
    }

    /** @test */
    public function it_can_create_a_purchase_order()
    {
        $payload = [
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 10, 'unit_cost' => 100]
            ]
        ];

        $response = $this->actingAs($this->admin)->postJson('/api/v1/purchase-orders', $payload);

        $response->assertStatus(201);
        $this->assertDatabaseHas('purchase_orders', ['supplier_id' => $this->supplier->id, 'total_amount' => 1000]);
    }

    /** @test */
    public function it_receives_purchase_order_updates_stock_and_supplier_debt_transactionally()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-TEST-1',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => 'DRAFT',
            'created_by' => $this->admin->id,
            'total_amount' => 2000,
        ]);

        $order->items()->create([
            'product_id' => $this->product->id,
            'quantity' => 20,
            'unit_cost' => 100,
            'total_cost' => 2000,
        ]);

        $requirement = PurchaseRequirement::create([
            'product_id' => $this->product->id,
            'warehouse_id' => $this->warehouse->id,
            'supplier_id' => $this->supplier->id,
            'purchase_order_id' => $order->id,
            'required_quantity' => 20,
            'current_stock' => 0,
            'status' => 'ORDERED',
            'created_by' => $this->admin->id,
        ]);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive");
        
        $response->assertStatus(200);

        // Verify status
        $order->refresh();
        $this->assertEquals('RECEIVED', $order->status);
        $this->assertNotNull($order->received_at);

        // Verify requirements are closed
        $requirement->refresh();
        $this->assertEquals('CLOSED', $requirement->status);

        // Verify stock updated exactly once
        $stock = WarehouseStock::where('warehouse_id', $this->warehouse->id)
            ->where('product_id', $this->product->id)
            ->first();
        $this->assertEquals(20, $stock->quantity);
        $this->assertEquals(20, $stock->available);

        // Verify inventory transaction was created
        $transaction = StockTransaction::where('reference_type', 'purchase_order')->where('reference_id', $order->id)->first();
        $this->assertNotNull($transaction);
        $this->assertEquals('PURCHASE', $transaction->type);
        $this->assertEquals(20, $transaction->quantity_change);

        // Verify supplier ledger updated correctly
        $ledger = SupplierLedger::where('reference_type', 'purchase_order')->where('reference_id', $order->id)->first();
        $this->assertNotNull($ledger);
        $this->assertEquals('PURCHASE', $ledger->entry_type);
        $this->assertEquals('credit', $ledger->type);
        $this->assertEquals(2000, $ledger->amount);
        $this->assertEquals(2000, $ledger->balance_after);

        // Verify supplier debt helper returns correctly
        $this->assertEquals(2000, $this->supplier->debt);
    }

    /** @test */
    public function it_prevents_duplicate_receiving_of_same_purchase_order()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-TEST-2',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => 'RECEIVED', // Already received
            'created_by' => $this->admin->id,
            'total_amount' => 1000,
        ]);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive");
        
        $response->assertStatus(422);
        $response->assertJsonValidationErrors('status');
    }

    /** @test */
    public function it_can_cancel_a_purchase_order_and_reset_requirements()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-TEST-3',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => 'DRAFT',
            'created_by' => $this->admin->id,
            'total_amount' => 1000,
        ]);

        $requirement = PurchaseRequirement::create([
            'product_id' => $this->product->id,
            'warehouse_id' => $this->warehouse->id,
            'supplier_id' => $this->supplier->id,
            'purchase_order_id' => $order->id,
            'required_quantity' => 10,
            'current_stock' => 0,
            'status' => 'ORDERED',
            'created_by' => $this->admin->id,
        ]);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/cancel");
        
        $response->assertStatus(200);

        $order->refresh();
        $this->assertEquals('CANCELLED', $order->status);

        $requirement->refresh();
        $this->assertEquals('OPEN', $requirement->status);
        $this->assertNull($requirement->purchase_order_id);
    }
}
