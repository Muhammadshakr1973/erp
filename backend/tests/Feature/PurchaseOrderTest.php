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
        $role = Role::firstOrCreate(['name' => 'admin'], ['display_name' => 'Admin']);
        $this->admin = User::factory()->create(['role_id' => $role->id, 'is_active' => true]);
        
        $this->supplier = Supplier::create(['name' => 'Supplier A']);
        $this->warehouse = Warehouse::create(['name' => 'Main WH']);
        $this->product = Product::create([
            'name' => 'Prod A',
            'sku' => 'PA',
            'cost_price' => 100,
            'price_n1' => 150,
            'price_n2' => 140,
            'price_n3' => 130,
        ]);
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
        $this->assertEquals(2000, $this->supplier->refresh()->debt);
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

    /** @test */
    public function it_supports_partial_receiving_of_purchase_order()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-TEST-PARTIAL',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => 'DRAFT',
            'created_by' => $this->admin->id,
            'total_amount' => 10000,
        ]);

        $item = $order->items()->create([
            'product_id' => $this->product->id,
            'quantity' => 100,
            'unit_cost' => 100,
            'total_cost' => 10000,
            'received_quantity' => 0,
        ]);

        $requirement = PurchaseRequirement::create([
            'product_id' => $this->product->id,
            'warehouse_id' => $this->warehouse->id,
            'supplier_id' => $this->supplier->id,
            'purchase_order_id' => $order->id,
            'required_quantity' => 100,
            'current_stock' => 0,
            'status' => 'ORDERED',
            'created_by' => $this->admin->id,
        ]);

        // First partial receive: 40 units
        $response1 = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive", [
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 40]
            ]
        ]);

        $response1->assertStatus(200);

        $order->refresh();
        $item->refresh();
        $this->assertEquals('DRAFT', $order->status); // Still DRAFT since 60 remain
        $this->assertEquals(40, $item->received_quantity);

        $stock1 = WarehouseStock::where('warehouse_id', $this->warehouse->id)->where('product_id', $this->product->id)->first();
        $this->assertEquals(40, $stock1->quantity);

        $this->assertEquals(4000, $this->supplier->refresh()->debt);

        // Second partial receive: 60 units (completes order)
        $response2 = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive", [
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 60]
            ]
        ]);

        $response2->assertStatus(200);

        $order->refresh();
        $item->refresh();
        $requirement->refresh();

        $this->assertEquals('RECEIVED', $order->status);
        $this->assertEquals(100, $item->received_quantity);
        $this->assertEquals('CLOSED', $requirement->status);

        $stock2 = WarehouseStock::where('warehouse_id', $this->warehouse->id)->where('product_id', $this->product->id)->first();
        $this->assertEquals(100, $stock2->quantity);

        $this->assertEquals(10000, $this->supplier->refresh()->debt);
    }

    /** @test */
    public function it_rejects_receiving_greater_than_remaining_quantity()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-TEST-OVER',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => 'DRAFT',
            'created_by' => $this->admin->id,
            'total_amount' => 5000,
        ]);

        $order->items()->create([
            'product_id' => $this->product->id,
            'quantity' => 50,
            'unit_cost' => 100,
            'total_cost' => 5000,
            'received_quantity' => 0,
        ]);

        // Attempting to receive 60 when only 50 ordered
        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive", [
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 60]
            ]
        ]);

        $response->assertStatus(422);
    }

    /** @test */
    public function it_rejects_zero_or_negative_receiving_quantity()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-TEST-ZERO',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => 'DRAFT',
            'created_by' => $this->admin->id,
            'total_amount' => 5000,
        ]);

        $order->items()->create([
            'product_id' => $this->product->id,
            'quantity' => 50,
            'unit_cost' => 100,
            'total_cost' => 5000,
            'received_quantity' => 0,
        ]);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive", [
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 0]
            ]
        ]);

        $response->assertStatus(422);
    }

    /** @test */
    public function it_preserves_historical_unit_cost_when_product_cost_changes()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-TEST-HISTORICAL',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => 'DRAFT',
            'created_by' => $this->admin->id,
            'total_amount' => 1000,
        ]);

        // Agreed unit cost on PO is 100
        $order->items()->create([
            'product_id' => $this->product->id,
            'quantity' => 10,
            'unit_cost' => 100,
            'total_cost' => 1000,
            'received_quantity' => 0,
        ]);

        // Product cost changes later in product master table
        $this->product->update(['cost_price' => 200]);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive");
        $response->assertStatus(200);

        // Supplier debt should be calculated using historical unit_cost (100 * 10 = 1000), not 200 * 10 = 2000
        $this->assertEquals(1000, $this->supplier->refresh()->debt);

        $ledger = SupplierLedger::where('reference_type', 'purchase_order')->where('reference_id', $order->id)->first();
        $this->assertEquals(1000, $ledger->amount);
    }

    /** @test */
    public function it_aggregates_requirements_for_same_product_when_converting()
    {
        $req1 = PurchaseRequirement::create([
            'product_id' => $this->product->id,
            'warehouse_id' => $this->warehouse->id,
            'supplier_id' => $this->supplier->id,
            'required_quantity' => 10,
            'current_stock' => 0,
            'status' => 'OPEN',
            'created_by' => $this->admin->id,
        ]);

        $req2 = PurchaseRequirement::create([
            'product_id' => $this->product->id,
            'warehouse_id' => $this->warehouse->id,
            'supplier_id' => $this->supplier->id,
            'required_quantity' => 15,
            'current_stock' => 0,
            'status' => 'OPEN',
            'created_by' => $this->admin->id,
        ]);

        $response = $this->actingAs($this->admin)->postJson('/api/v1/purchase-requirements/convert', [
            'requirement_ids' => [$req1->id, $req2->id]
        ]);

        $response->assertStatus(200);

        $po = PurchaseOrder::where('supplier_id', $this->supplier->id)->first();
        $this->assertNotNull($po);
        $this->assertCount(1, $po->items); // Aggregated into single item
        $this->assertEquals(25, $po->items->first()->quantity);

        $req1->refresh();
        $req2->refresh();
        $this->assertEquals('ORDERED', $req1->status);
        $this->assertEquals('ORDERED', $req2->status);
    }

    /** @test */
    public function test_a_it_rejects_same_request_duplicate_items_when_total_exceeds_ordered_quantity()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-TEST-DUP-A',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => 'DRAFT',
            'created_by' => $this->admin->id,
            'total_amount' => 10000,
        ]);

        $item = $order->items()->create([
            'product_id' => $this->product->id,
            'quantity' => 100,
            'unit_cost' => 100,
            'total_cost' => 10000,
            'received_quantity' => 0,
        ]);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive", [
            'items' => [
                ['item_id' => $item->id, 'product_id' => $this->product->id, 'quantity' => 60],
                ['item_id' => $item->id, 'product_id' => $this->product->id, 'quantity' => 60],
            ]
        ]);

        $response->assertStatus(422);
        $this->assertEquals(0, $item->fresh()->received_quantity);
        $stock = WarehouseStock::where('warehouse_id', $this->warehouse->id)->where('product_id', $this->product->id)->first();
        $this->assertNull($stock);
        $this->assertEquals(0, SupplierLedger::where('reference_type', 'purchase_order')->where('reference_id', $order->id)->count());
    }

    /** @test */
    public function test_b_it_accepts_same_request_duplicate_items_when_total_is_within_ordered_quantity()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-TEST-DUP-B',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => 'DRAFT',
            'created_by' => $this->admin->id,
            'total_amount' => 10000,
        ]);

        $item = $order->items()->create([
            'product_id' => $this->product->id,
            'quantity' => 100,
            'unit_cost' => 100,
            'total_cost' => 10000,
            'received_quantity' => 0,
        ]);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive", [
            'items' => [
                ['item_id' => $item->id, 'product_id' => $this->product->id, 'quantity' => 40],
                ['item_id' => $item->id, 'product_id' => $this->product->id, 'quantity' => 60],
            ]
        ]);

        $response->assertStatus(200);
        $this->assertEquals(100, $item->fresh()->received_quantity);
        $stock = WarehouseStock::where('warehouse_id', $this->warehouse->id)->where('product_id', $this->product->id)->first();
        $this->assertEquals(100, $stock->quantity);
        $this->assertEquals(10000, $this->supplier->refresh()->debt);
        $this->assertEquals('RECEIVED', $order->fresh()->status);
    }

    /** @test */
    public function test_c_it_accepts_valid_duplicate_items_when_already_partially_received()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-TEST-DUP-C',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => 'DRAFT',
            'created_by' => $this->admin->id,
            'total_amount' => 10000,
        ]);

        $item = $order->items()->create([
            'product_id' => $this->product->id,
            'quantity' => 100,
            'unit_cost' => 100,
            'total_cost' => 10000,
            'received_quantity' => 20,
        ]);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive", [
            'items' => [
                ['item_id' => $item->id, 'product_id' => $this->product->id, 'quantity' => 40],
                ['item_id' => $item->id, 'product_id' => $this->product->id, 'quantity' => 40],
            ]
        ]);

        $response->assertStatus(200);
        $this->assertEquals(100, $item->fresh()->received_quantity);
        $this->assertEquals('RECEIVED', $order->fresh()->status);
    }

    /** @test */
    public function test_d_it_rejects_duplicate_items_exceeding_remaining_when_already_partially_received()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-TEST-DUP-D',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => 'DRAFT',
            'created_by' => $this->admin->id,
            'total_amount' => 10000,
        ]);

        $item = $order->items()->create([
            'product_id' => $this->product->id,
            'quantity' => 100,
            'unit_cost' => 100,
            'total_cost' => 10000,
            'received_quantity' => 20,
        ]);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive", [
            'items' => [
                ['item_id' => $item->id, 'product_id' => $this->product->id, 'quantity' => 50],
                ['item_id' => $item->id, 'product_id' => $this->product->id, 'quantity' => 40],
            ]
        ]);

        $response->assertStatus(422);
        $this->assertEquals(20, $item->fresh()->received_quantity);
    }

    /** @test */
    public function test_e_it_handles_multiple_different_purchase_order_items_in_same_request()
    {
        $productB = Product::create([
            'name' => 'Prod B',
            'sku' => 'PB',
            'cost_price' => 200,
            'price_n1' => 300,
            'price_n2' => 280,
            'price_n3' => 260,
        ]);

        $order = PurchaseOrder::create([
            'order_number' => 'PO-TEST-DIFF-ITEMS',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => 'DRAFT',
            'created_by' => $this->admin->id,
            'total_amount' => 30000,
        ]);

        $itemA = $order->items()->create([
            'product_id' => $this->product->id,
            'quantity' => 100,
            'unit_cost' => 100,
            'total_cost' => 10000,
            'received_quantity' => 0,
        ]);

        $itemB = $order->items()->create([
            'product_id' => $productB->id,
            'quantity' => 100,
            'unit_cost' => 200,
            'total_cost' => 20000,
            'received_quantity' => 0,
        ]);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive", [
            'items' => [
                ['item_id' => $itemA->id, 'product_id' => $this->product->id, 'quantity' => 50],
                ['item_id' => $itemB->id, 'product_id' => $productB->id, 'quantity' => 70],
            ]
        ]);

        $response->assertStatus(200);
        $this->assertEquals(50, $itemA->fresh()->received_quantity);
        $this->assertEquals(70, $itemB->fresh()->received_quantity);
    }

    /** @test */
    public function test_f_it_keeps_item_identity_distinct_for_different_products_across_multiple_po_lines()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-TEST-MULTI-LINES-DIFF-PROD',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => 'DRAFT',
            'created_by' => $this->admin->id,
            'total_amount' => 10000,
        ]);

        $productB = Product::create([
            'name' => 'Prod B',
            'sku' => 'PB',
            'cost_price' => 100,
            'price_n1' => 150,
        ]);

        $line1 = $order->items()->create([
            'product_id' => $this->product->id,
            'quantity' => 50,
            'unit_cost' => 100,
            'total_cost' => 5000,
            'received_quantity' => 0,
        ]);

        $line2 = $order->items()->create([
            'product_id' => $productB->id,
            'quantity' => 50,
            'unit_cost' => 100,
            'total_cost' => 5000,
            'received_quantity' => 0,
        ]);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive", [
            'items' => [
                ['item_id' => $line1->id, 'quantity' => 30],
                ['item_id' => $line2->id, 'quantity' => 40],
            ]
        ]);

        $response->assertStatus(200);
        $this->assertEquals(30, $line1->fresh()->received_quantity);
        $this->assertEquals(40, $line2->fresh()->received_quantity);
    }

    /** @test */
    public function it_prevents_cancelling_partially_received_purchase_order()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-TEST-PARTIAL-CANCEL',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => 'DRAFT',
            'created_by' => $this->admin->id,
            'total_amount' => 10000,
        ]);

        $item = $order->items()->create([
            'product_id' => $this->product->id,
            'quantity' => 100,
            'unit_cost' => 100,
            'total_cost' => 10000,
            'received_quantity' => 0,
        ]);

        // Partially receive 20 items
        $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive", [
            'items' => [
                ['item_id' => $item->id, 'product_id' => $this->product->id, 'quantity' => 20]
            ]
        ]);

        // Attempt cancellation
        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/cancel");

        $response->assertStatus(422);
        $this->assertNotEquals('CANCELLED', $order->fresh()->status);
    }
}
