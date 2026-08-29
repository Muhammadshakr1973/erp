<?php

namespace Tests\Feature;

use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Models\Warehouse;
use App\Models\WarehouseStock;
use App\Models\StockTransaction;
use App\Models\StockTransfer;
use App\Models\PurchaseOrder;
use App\Models\SalesOrder;
use App\Services\StockTransferService;
use App\Services\PurchaseOrderService;
use App\Services\SalesOrderService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class InventoryStockEngineTest extends TestCase
{
    use RefreshDatabase;

    protected User $admin;
    protected Warehouse $mainWarehouse;
    protected Warehouse $secondaryWarehouse;
    protected Product $product;

    protected function setUp(): void
    {
        parent::setUp();

        // Create admin role and user
        $adminRole = Role::create([
            'name' => Role::OWNER,
            'display_name' => 'Owner',
            'permissions' => ['*']
        ]);

        $this->admin = User::factory()->create([
            'role_id' => $adminRole->id,
            'is_active' => true,
        ]);

        // Create warehouses
        $this->mainWarehouse = Warehouse::create([
            'name' => 'کۆگای سەرەکی',
            'is_main' => true,
            'is_active' => true,
        ]);

        $this->secondaryWarehouse = Warehouse::create([
            'name' => 'کۆگای سلێمانی',
            'is_main' => false,
            'is_active' => true,
        ]);

        // Create product
        $this->product = Product::create([
            'name' => 'Test Item',
            'sku' => 'SKU-TEST-999',
            'cost_price' => 1500,
            'price_n1' => 2000,
            'is_active' => true,
        ]);
    }

    /** @test */
    public function test_initial_stock_creation_and_adjustment()
    {
        // 1. Initial creation via API
        $response = $this->actingAs($this->admin)->postJson('/api/v1/products', [
            'name' => 'New Product',
            'sku' => 'SKU-NEW-888',
            'initial_stock' => 100,
        ]);

        $response->assertStatus(201);

        $newProduct = Product::where('sku', 'SKU-NEW-888')->first();
        $this->assertNotNull($newProduct);

        $stock = WarehouseStock::where('product_id', $newProduct->id)
            ->where('warehouse_id', $this->mainWarehouse->id)
            ->first();

        $this->assertEquals(100, $stock->quantity);

        // Check transaction trace
        $tx = StockTransaction::where('product_id', $newProduct->id)->first();
        $this->assertNotNull($tx);
        $this->assertEquals('ADJUSTMENT', $tx->type);
        $this->assertEquals(100, $tx->quantity_change);
        $this->assertEquals(100, $tx->quantity_after);
    }

    /** @test */
    public function test_stock_mutation_guards_against_negatives()
    {
        $stock = WarehouseStock::create([
            'warehouse_id' => $this->mainWarehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 10,
            'reserved_quantity' => 0,
        ]);

        // Attempting to deduct 15 must throw an exception
        $this->expectException(\Exception::class);
        $stock->adjustStock(-15, 'ADJUSTMENT', $this->admin->id);
    }

    /** @test */
    public function test_reservation_and_release_flow()
    {
        $stock = WarehouseStock::create([
            'warehouse_id' => $this->mainWarehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 50,
            'reserved_quantity' => 0,
        ]);

        // Reserve 20
        $stock->reserveStock(20, $this->admin->id, 'manual', null, 'Reservation test');
        $this->assertEquals(30, $stock->fresh()->available);
        $this->assertEquals(20, $stock->fresh()->reserved_quantity);

        // Try to reserve 40 (only 30 available) -> should fail
        try {
            $stock->reserveStock(40, $this->admin->id);
            $this->fail('Should not be able to reserve more than available');
        } catch (\Exception $e) {
            $this->assertStringContainsString('بڕی پێویست لە ستۆکی بەردەست نییە', $e->getMessage());
        }

        // Release 10
        $stock->releaseStock(10, $this->admin->id);
        $this->assertEquals(40, $stock->fresh()->available);
        $this->assertEquals(10, $stock->fresh()->reserved_quantity);
    }

    /** @test */
    public function test_purchase_order_receiving_updates_stock()
    {
        $supplier = \App\Models\Supplier::create([
            'name' => 'Supplier ABC',
            'created_by' => $this->admin->id,
        ]);

        $po = PurchaseOrder::create([
            'order_number' => 'PO-1000',
            'supplier_id' => $supplier->id,
            'warehouse_id' => $this->mainWarehouse->id,
            'status' => 'DRAFT',
            'created_by' => $this->admin->id,
        ]);

        $po->items()->create([
            'product_id' => $this->product->id,
            'quantity' => 150,
            'price' => 1200,
        ]);

        $service = app(PurchaseOrderService::class);
        $service->receiveOrder($po, $this->admin);

        $stock = WarehouseStock::where('product_id', $this->product->id)
            ->where('warehouse_id', $this->mainWarehouse->id)
            ->first();

        $this->assertEquals(150, $stock->quantity);

        // Transaction check
        $tx = StockTransaction::where('product_id', $this->product->id)
            ->where('type', 'PURCHASE')
            ->first();

        $this->assertNotNull($tx);
        $this->assertEquals(150, $tx->quantity_change);
        $this->assertEquals(150, $tx->quantity_after);
    }

    /** @test */
    public function test_stock_transfer_flow_completes_safely()
    {
        // Give 50 starting quantity to main warehouse
        WarehouseStock::create([
            'warehouse_id' => $this->mainWarehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 50,
            'reserved_quantity' => 0,
        ]);

        $transferService = app(StockTransferService::class);
        $transfer = $transferService->createTransfer([
            'from_warehouse_id' => $this->mainWarehouse->id,
            'to_warehouse_id' => $this->secondaryWarehouse->id,
            'notes' => 'Transferring 20 items',
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 20,
                ]
            ]
        ], $this->admin);

        $transferService->completeTransfer($transfer, $this->admin);

        $sourceStock = WarehouseStock::where('warehouse_id', $this->mainWarehouse->id)->where('product_id', $this->product->id)->first();
        $destStock = WarehouseStock::where('warehouse_id', $this->secondaryWarehouse->id)->where('product_id', $this->product->id)->first();

        $this->assertEquals(30, $sourceStock->quantity);
        $this->assertEquals(20, $destStock->quantity);

        // Transaction checks
        $outTx = StockTransaction::where('warehouse_id', $this->mainWarehouse->id)->where('type', 'TRANSFER_OUT')->first();
        $inTx = StockTransaction::where('warehouse_id', $this->secondaryWarehouse->id)->where('type', 'TRANSFER_IN')->first();

        $this->assertNotNull($outTx);
        $this->assertEquals(-20, $outTx->quantity_change);
        $this->assertEquals(30, $outTx->quantity_after);

        $this->assertNotNull($inTx);
        $this->assertEquals(20, $inTx->quantity_change);
        $this->assertEquals(20, $inTx->quantity_after);
    }

    /** @test */
    public function test_reconciliation_detects_consistency_correctly()
    {
        $stock = WarehouseStock::create([
            'warehouse_id' => $this->mainWarehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 0,
            'reserved_quantity' => 0,
        ]);

        // Run multiple adjustments
        $stock->adjustStock(100, 'PURCHASE', $this->admin->id);
        $stock->reserveStock(20, $this->admin->id);
        $stock->adjustStock(-30, 'DELIVERY', $this->admin->id);

        $reconcileResult = $stock->fresh()->reconcile();

        $this->assertTrue($reconcileResult['is_consistent']);
        $this->assertEquals(70, $reconcileResult['stored_quantity']);
        $this->assertEquals(70, $reconcileResult['recalculated_quantity']);
        $this->assertEquals(0, $reconcileResult['stored_reserved']); // Delivery implicitly release-reduces reservation by the adjustment magnitude (max 0)
    }

    /** @test */
    public function test_immutability_of_stock_transactions()
    {
        $stock = WarehouseStock::create([
            'warehouse_id' => $this->mainWarehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 100,
        ]);

        $tx = $stock->adjustStock(50, 'PURCHASE', $this->admin->id);

        // Attempting to update the transaction must return false
        $this->assertFalse($tx->update(['quantity_change' => 999]));
        // Attempting to delete must return false
        $this->assertFalse($tx->delete());

        // Assert original record persists untouched
        $this->assertEquals(50, $tx->fresh()->quantity_change);
    }

    /** @test */
    public function test_idempotency_of_manual_adjustments()
    {
        $payload = [
            'quantity_change' => 25,
            'type' => 'ADJUSTMENT',
            'notes' => 'Duplicate check',
        ];

        // First adjustment request
        $response1 = $this->actingAs($this->admin)->postJson(
            "/api/v1/warehouses/{$this->mainWarehouse->id}/stock/{$this->product->id}/adjust",
            $payload
        );
        $response1->assertStatus(200);

        // Immediate identical adjustment request (should trigger idempotency hit)
        $response2 = $this->actingAs($this->admin)->postJson(
            "/api/v1/warehouses/{$this->mainWarehouse->id}/stock/{$this->product->id}/adjust",
            $payload
        );
        $response2->assertStatus(200);
        $response2->assertSee('ئەم گۆڕانکارییە پێشتر تۆمارکراوە');

        // Check stock is only incremented once
        $stock = WarehouseStock::where('warehouse_id', $this->mainWarehouse->id)->where('product_id', $this->product->id)->first();
        $this->assertEquals(25, $stock->quantity);
    }
}
