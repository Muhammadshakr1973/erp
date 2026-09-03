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
        $this->assertDatabaseHas('purchase_orders', ['supplier_id' => $this->supplier->id, 'total_amount' => 1000, 'status' => PurchaseOrder::STATUS_DRAFT]);
    }

    /** @test */
    public function test_1_draft_purchase_order_cannot_receive()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-DRAFT-1',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => PurchaseOrder::STATUS_DRAFT,
            'created_by' => $this->admin->id,
            'total_amount' => 1000,
        ]);

        $order->items()->create([
            'product_id' => $this->product->id,
            'quantity' => 10,
            'unit_cost' => 100,
            'total_cost' => 1000,
            'received_quantity' => 0,
        ]);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive");

        $response->assertStatus(422);
        $response->assertJsonValidationErrors('status');

        // Assert NO side effects occurred
        $this->assertEquals(0, WarehouseStock::where('warehouse_id', $this->warehouse->id)->where('product_id', $this->product->id)->sum('quantity'));
        $this->assertEquals(0, SupplierLedger::where('supplier_id', $this->supplier->id)->count());
        $this->assertEquals(0, $this->supplier->refresh()->debt);
    }

    /** @test */
    public function test_2_draft_purchase_order_can_be_explicitly_confirmed()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-DRAFT-2',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => PurchaseOrder::STATUS_DRAFT,
            'created_by' => $this->admin->id,
            'total_amount' => 1000,
        ]);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/confirm");

        $response->assertStatus(200);
        $this->assertEquals(PurchaseOrder::STATUS_CONFIRMED, $order->fresh()->status);
    }

    /** @test */
    public function test_3_confirmed_purchase_order_can_partially_receive()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-CONFIRMED-PARTIAL',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => PurchaseOrder::STATUS_CONFIRMED,
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
                ['product_id' => $this->product->id, 'quantity' => 40]
            ]
        ]);

        $response->assertStatus(200);
        $this->assertEquals(40, $item->fresh()->received_quantity);
    }

    /** @test */
    public function test_4_partial_receive_keeps_order_confirmed()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-PARTIAL-STATUS',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => PurchaseOrder::STATUS_CONFIRMED,
            'created_by' => $this->admin->id,
            'total_amount' => 10000,
        ]);

        $order->items()->create([
            'product_id' => $this->product->id,
            'quantity' => 100,
            'unit_cost' => 100,
            'total_cost' => 10000,
            'received_quantity' => 0,
        ]);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive", [
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 40]
            ]
        ]);

        $response->assertStatus(200);
        $this->assertEquals(PurchaseOrder::STATUS_CONFIRMED, $order->fresh()->status);
    }

    /** @test */
    public function test_5_confirmed_purchase_order_can_receive_remaining_quantity()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-RECEIVE-REMAINING',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => PurchaseOrder::STATUS_CONFIRMED,
            'created_by' => $this->admin->id,
            'total_amount' => 10000,
        ]);

        $item = $order->items()->create([
            'product_id' => $this->product->id,
            'quantity' => 100,
            'unit_cost' => 100,
            'total_cost' => 10000,
            'received_quantity' => 40,
        ]);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive", [
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 60]
            ]
        ]);

        $response->assertStatus(200);
        $this->assertEquals(100, $item->fresh()->received_quantity);
    }

    /** @test */
    public function test_6_full_receive_changes_status_to_received()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-FULL-RECEIVE',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => PurchaseOrder::STATUS_CONFIRMED,
            'created_by' => $this->admin->id,
            'total_amount' => 10000,
        ]);

        $order->items()->create([
            'product_id' => $this->product->id,
            'quantity' => 100,
            'unit_cost' => 100,
            'total_cost' => 10000,
            'received_quantity' => 0,
        ]);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive");

        $response->assertStatus(200);
        $this->assertEquals(PurchaseOrder::STATUS_RECEIVED, $order->fresh()->status);
        $this->assertNotNull($order->fresh()->received_at);
    }

    /** @test */
    public function test_7_received_purchase_order_cannot_receive_again()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-RECEIVED-RETRY',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => PurchaseOrder::STATUS_RECEIVED,
            'created_by' => $this->admin->id,
            'total_amount' => 1000,
        ]);

        $order->items()->create([
            'product_id' => $this->product->id,
            'quantity' => 10,
            'unit_cost' => 100,
            'total_cost' => 1000,
            'received_quantity' => 10,
        ]);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive");

        $response->assertStatus(422);
        $response->assertJsonValidationErrors('status');
    }

    /** @test */
    public function test_8_cancelled_purchase_order_cannot_receive()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-CANCELLED-RECEIVE',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => PurchaseOrder::STATUS_CANCELLED,
            'created_by' => $this->admin->id,
            'total_amount' => 1000,
        ]);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive");

        $response->assertStatus(422);
        $response->assertJsonValidationErrors('status');
    }

    /** @test */
    public function test_9_partially_received_po_cannot_be_cancelled()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-PARTIAL-CANCEL-2',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => PurchaseOrder::STATUS_CONFIRMED,
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
        $this->assertEquals(PurchaseOrder::STATUS_CONFIRMED, $order->fresh()->status);
    }

    /** @test */
    public function test_10_repeated_receive_cannot_double_stock()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-DOUBLE-STOCK',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => PurchaseOrder::STATUS_CONFIRMED,
            'created_by' => $this->admin->id,
            'total_amount' => 2000,
        ]);

        $order->items()->create([
            'product_id' => $this->product->id,
            'quantity' => 20,
            'unit_cost' => 100,
            'total_cost' => 2000,
            'received_quantity' => 0,
        ]);

        // First receive
        $r1 = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive");
        $r1->assertStatus(200);

        $stock1 = WarehouseStock::where('warehouse_id', $this->warehouse->id)->where('product_id', $this->product->id)->first();
        $this->assertEquals(20, $stock1->quantity);

        // Second receive attempt
        $r2 = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive");
        $r2->assertStatus(422);

        $stock2 = WarehouseStock::where('warehouse_id', $this->warehouse->id)->where('product_id', $this->product->id)->first();
        $this->assertEquals(20, $stock2->quantity); // Stock remains 20, not 40
    }

    /** @test */
    public function test_11_repeated_receive_cannot_double_supplier_debt()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-DOUBLE-DEBT',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => PurchaseOrder::STATUS_CONFIRMED,
            'created_by' => $this->admin->id,
            'total_amount' => 2000,
        ]);

        $order->items()->create([
            'product_id' => $this->product->id,
            'quantity' => 20,
            'unit_cost' => 100,
            'total_cost' => 2000,
            'received_quantity' => 0,
        ]);

        // First receive
        $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive");
        $this->assertEquals(2000, $this->supplier->refresh()->debt);

        // Second receive attempt
        $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive");
        $this->assertEquals(2000, $this->supplier->refresh()->debt); // Debt remains 2000, not 4000
    }

    /** @test */
    public function test_12_supplier_ledger_amount_exactly_matches_actually_received_quantity()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-EXACT-LEDGER',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => PurchaseOrder::STATUS_CONFIRMED,
            'created_by' => $this->admin->id,
            'total_amount' => 10000,
        ]);

        $order->items()->create([
            'product_id' => $this->product->id,
            'quantity' => 100,
            'unit_cost' => 100,
            'total_cost' => 10000,
            'received_quantity' => 0,
        ]);

        // Receive 40 units out of 100
        $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive", [
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 40]
            ]
        ]);

        $ledger1 = SupplierLedger::where('reference_type', 'purchase_order')
            ->where('reference_id', $order->id)
            ->latest('id')
            ->first();

        $this->assertEquals(4000, $ledger1->amount);
        $this->assertEquals(4000, $this->supplier->refresh()->debt);

        // Receive remaining 60 units
        $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/receive", [
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 60]
            ]
        ]);

        $ledgers = SupplierLedger::where('reference_type', 'purchase_order')
            ->where('reference_id', $order->id)
            ->get();

        $this->assertCount(2, $ledgers);
        $this->assertEquals(10000, $ledgers->sum('amount'));
        $this->assertEquals(10000, $this->supplier->refresh()->debt);
    }

    /** @test */
    public function it_receives_purchase_order_updates_stock_and_supplier_debt_transactionally()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-TEST-1',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => PurchaseOrder::STATUS_CONFIRMED,
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
    public function it_rejects_receiving_greater_than_remaining_quantity()
    {
        $order = PurchaseOrder::create([
            'order_number' => 'PO-TEST-OVER',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => PurchaseOrder::STATUS_CONFIRMED,
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
            'status' => PurchaseOrder::STATUS_CONFIRMED,
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
            'status' => PurchaseOrder::STATUS_CONFIRMED,
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
            'status' => PurchaseOrder::STATUS_CONFIRMED,
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
            'status' => PurchaseOrder::STATUS_CONFIRMED,
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
            'status' => PurchaseOrder::STATUS_CONFIRMED,
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
            'status' => PurchaseOrder::STATUS_CONFIRMED,
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
            'status' => PurchaseOrder::STATUS_CONFIRMED,
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
            'status' => PurchaseOrder::STATUS_CONFIRMED,
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
    public function test_po_cancellation_lifecycle_requirements()
    {
        // Scenario A, C, D, H: Single ordered requirement, preserve sales order / other attributes, check audit trail
        $order = PurchaseOrder::create([
            'order_number' => 'PO-CANCEL-A',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => 'CONFIRMED',
            'created_by' => $this->admin->id,
            'total_amount' => 1000,
        ]);

        $route = \App\Models\Route::create([
            'name' => 'Route A',
            'is_active' => true,
        ]);

        $customer = \App\Models\Customer::create([
            'name' => 'Customer A',
            'phone' => '07701234567',
            'route_id' => $route->id,
            'price_tier' => 'N1',
            'is_active' => true,
        ]);

        $salesOrder = \App\Models\SalesOrder::create([
            'order_number' => 'SO-123',
            'customer_id' => $customer->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => 'PENDING',
            'created_by' => $this->admin->id,
            'total_amount' => 5000,
        ]);

        $requirement = PurchaseRequirement::create([
            'product_id' => $this->product->id,
            'warehouse_id' => $this->warehouse->id,
            'supplier_id' => $this->supplier->id,
            'purchase_order_id' => $order->id,
            'sales_order_id' => $salesOrder->id,
            'required_quantity' => 10,
            'current_stock' => 5,
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

        // Assert attributes are preserved
        $this->assertEquals($salesOrder->id, $requirement->sales_order_id);
        $this->assertEquals($this->product->id, $requirement->product_id);
        $this->assertEquals($this->warehouse->id, $requirement->warehouse_id);
        $this->assertEquals($this->supplier->id, $requirement->supplier_id);
        $this->assertEquals(10, $requirement->required_quantity);
        $this->assertEquals(5, $requirement->current_stock);

        // Assert audit trail
        $this->assertDatabaseHas('audit_logs', [
            'action' => 'REOPENED',
            'entity_type' => 'PurchaseRequirement',
            'entity_id' => $requirement->id,
        ]);
    }

    /** @test */
    public function test_po_cancellation_multiple_requirements()
    {
        // Scenario B: Multiple requirements linked to the same PO
        $order = PurchaseOrder::create([
            'order_number' => 'PO-CANCEL-B',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => 'CONFIRMED',
            'created_by' => $this->admin->id,
            'total_amount' => 2000,
        ]);

        $req1 = PurchaseRequirement::create([
            'product_id' => $this->product->id,
            'warehouse_id' => $this->warehouse->id,
            'supplier_id' => $this->supplier->id,
            'purchase_order_id' => $order->id,
            'required_quantity' => 10,
            'current_stock' => 0,
            'status' => 'ORDERED',
            'created_by' => $this->admin->id,
        ]);

        $req2 = PurchaseRequirement::create([
            'product_id' => $this->product->id,
            'warehouse_id' => $this->warehouse->id,
            'supplier_id' => $this->supplier->id,
            'purchase_order_id' => $order->id,
            'required_quantity' => 5,
            'current_stock' => 0,
            'status' => 'ORDERED',
            'created_by' => $this->admin->id,
        ]);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/cancel");
        $response->assertStatus(200);

        $req1->refresh();
        $req2->refresh();

        $this->assertEquals('OPEN', $req1->status);
        $this->assertNull($req1->purchase_order_id);

        $this->assertEquals('OPEN', $req2->status);
        $this->assertNull($req2->purchase_order_id);
    }

    /** @test */
    public function test_po_cancellation_received_po_cannot_be_cancelled()
    {
        // Scenario E: RECEIVED PO cannot be cancelled
        $order = PurchaseOrder::create([
            'order_number' => 'PO-CANCEL-E',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => 'RECEIVED',
            'created_by' => $this->admin->id,
            'total_amount' => 1000,
        ]);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/cancel");
        $response->assertStatus(422);
    }

    /** @test */
    public function test_po_cancellation_idempotency()
    {
        // Scenario F: Cancelling an already CANCELLED PO remains idempotent/no duplicate side effects
        $order = PurchaseOrder::create([
            'order_number' => 'PO-CANCEL-F',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => 'CANCELLED',
            'created_by' => $this->admin->id,
            'total_amount' => 1000,
        ]);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/purchase-orders/{$order->id}/cancel");
        $response->assertStatus(200);

        $order->refresh();
        $this->assertEquals('CANCELLED', $order->status);
    }

    /** @test */
    public function test_po_cancellation_rollback_on_exception()
    {
        // Scenario G: Transaction rollback leaves both PO and requirements unchanged if an exception occurs
        $order = PurchaseOrder::create([
            'order_number' => 'PO-CANCEL-G',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => 'CONFIRMED',
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

        $this->mock(\App\Services\AuditService::class, function ($mock) {
            $mock->shouldReceive('log')
                ->with(\Mockery::on(function ($argument) {
                    return isset($argument['action']) && $argument['action'] === 'REOPENED';
                }))
                ->andThrow(new \Exception('Database error'));
            
            $mock->shouldReceive('log')->byDefault();
        });

        try {
            app(\App\Services\PurchaseOrderService::class)->cancelOrder($order, $this->admin);
            $this->fail('Expected exception was not thrown');
        } catch (\Exception $e) {
            $this->assertEquals('Database error', $e->getMessage());
        }

        $order->refresh();
        $this->assertEquals('CONFIRMED', $order->status);

        $requirement->refresh();
        $this->assertEquals('ORDERED', $requirement->status);
        $this->assertEquals($order->id, $requirement->purchase_order_id);
    }
}
