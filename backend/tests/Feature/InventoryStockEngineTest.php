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

    /** @test */
    public function test_sales_order_stock_reservation_uses_deterministic_lock_ordering()
    {
        // 1. Create multiple products with descending IDs or unsorted order to enforce deterministic locking
        $product2 = Product::create([
            'name' => 'Product 2',
            'sku' => 'SKU-2',
            'cost_price' => 1000,
            'price_n1' => 1500,
            'is_active' => true,
        ]);

        $product1 = Product::create([
            'name' => 'Product 1',
            'sku' => 'SKU-1',
            'cost_price' => 1000,
            'price_n1' => 1500,
            'is_active' => true,
        ]);

        // Setup stock
        WarehouseStock::create([
            'warehouse_id' => $this->mainWarehouse->id,
            'product_id' => $product2->id,
            'quantity' => 100,
            'reserved_quantity' => 0,
        ]);

        WarehouseStock::create([
            'warehouse_id' => $this->mainWarehouse->id,
            'product_id' => $product1->id,
            'quantity' => 100,
            'reserved_quantity' => 0,
        ]);

        // Create a customer & route
        $route = \App\Models\Route::create(['name' => 'Route Z', 'is_active' => true]);
        DB::table('route_salesmen')->insert([
            'route_id' => $route->id,
            'salesman_id' => $this->admin->id,
            'work_date' => now()->toDateString(),
            'is_active' => true,
        ]);

        $customer = \App\Models\Customer::create([
            'name' => 'Test Customer Z',
            'phone' => '07700000003',
            'route_id' => $route->id,
            'price_type' => 'N1',
            'current_balance' => 0,
            'is_active' => true
        ]);

        // Create Sales Order with items in unsorted/reversed order: [product2, product1]
        $order = SalesOrder::create([
            'order_number' => 'SO-CONCUR-1',
            'customer_id' => $customer->id,
            'warehouse_id' => $this->mainWarehouse->id,
            'status' => 'DRAFT',
            'created_by' => $this->admin->id,
        ]);

        $order->items()->create([
            'product_id' => $product2->id,
            'quantity' => 5,
            'unit_price' => 1500,
            'cost_price' => 1000,
            'price_type' => 'N1',
            'line_total' => 7500,
            'profit' => 2500,
            'is_packed' => false,
        ]);

        $order->items()->create([
            'product_id' => $product1->id,
            'quantity' => 5,
            'unit_price' => 1500,
            'cost_price' => 1000,
            'price_type' => 'N1',
            'line_total' => 7500,
            'profit' => 2500,
            'is_packed' => false,
        ]);

        // Run reserveStock under SalesOrderService
        $service = app(SalesOrderService::class);
        $service->transitionTo($order, SalesOrder::STATUS_CONFIRMED, $this->admin);

        // Verify reservations are correct
        $this->assertEquals(5, WarehouseStock::where('product_id', $product1->id)->first()->reserved_quantity);
        $this->assertEquals(5, WarehouseStock::where('product_id', $product2->id)->first()->reserved_quantity);
    }

    /** @test */
    public function test_stock_exact_and_less_and_greater_than_available()
    {
        $stock = WarehouseStock::create([
            'warehouse_id' => $this->mainWarehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 10,
            'reserved_quantity' => 2,
        ]);

        // Available quantity is 10 - 2 = 8

        // 1. Less than available: deducting 5 should succeed (physical qty becomes 5, reserved becomes 0 since max(0, 2 - 5) is 0)
        $stock->adjustStock(-5, 'DELIVERY', $this->admin->id);
        $this->assertEquals(5, $stock->fresh()->quantity);
        $this->assertEquals(0, $stock->fresh()->reserved_quantity);

        // Reset
        $stock->update(['quantity' => 10, 'reserved_quantity' => 2]);

        // 2. Exact available: deducting 10 (which is the physical quantity) should succeed (physical qty becomes 0, reserved becomes 0)
        $stock->fresh()->adjustStock(-10, 'DELIVERY', $this->admin->id);
        $this->assertEquals(0, $stock->fresh()->quantity);
        $this->assertEquals(0, $stock->fresh()->reserved_quantity);

        // Reset
        $stock->update(['quantity' => 10, 'reserved_quantity' => 2]);

        // 3. Greater than available physical quantity: deducting 11 should fail
        try {
            $stock->fresh()->adjustStock(-11, 'DELIVERY', $this->admin->id);
            $this->fail('Should have thrown ValidationException for exceeding physical stock');
        } catch (\Illuminate\Validation\ValidationException $e) {
            $this->assertArrayHasKey('stock', $e->errors());
        }
    }

    /** @test */
    public function test_concurrent_deduction_and_rollback()
    {
        $stock = WarehouseStock::create([
            'warehouse_id' => $this->mainWarehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 15,
            'reserved_quantity' => 0,
        ]);

        // Scenario: Two transactions try to deduct stock concurrently.
        // We simulate a rollback inside a transaction when deduction exceeds available stock.
        DB::transaction(function () use ($stock) {
            $lockedStock = WarehouseStock::lockForUpdate()->find($stock->id);
            $lockedStock->adjustStock(-10, 'DELIVERY', $this->admin->id);
            $this->assertEquals(5, $lockedStock->fresh()->quantity);
        });

        // The above deduction succeeded. Now we start another transaction that attempts to deduct more than remaining.
        try {
            DB::transaction(function () use ($stock) {
                $lockedStock = WarehouseStock::lockForUpdate()->find($stock->id);
                // Attempting to deduct 10 when only 5 is remaining must throw validation exception and roll back
                $lockedStock->adjustStock(-10, 'DELIVERY', $this->admin->id);
            });
            $this->fail('Deduction should have thrown ValidationException');
        } catch (\Illuminate\Validation\ValidationException $e) {
            $this->assertArrayHasKey('stock', $e->errors());
        }

        // Assert that the second transaction rolled back and quantity remained 5
        $this->assertEquals(5, $stock->fresh()->quantity);
    }

    /** @test */
    public function test_adjustment_bounds_prevents_reducing_below_reserved_quantity()
    {
        $stock = WarehouseStock::create([
            'warehouse_id' => $this->mainWarehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 20,
            'reserved_quantity' => 15,
        ]);

        // Attempting to adjust down by 10 (resulting in physical qty 10, which is < reserved 15) must fail
        try {
            $stock->adjustStock(-10, 'ADJUSTMENT', $this->admin->id, 'manual', null, 'Testing reservation bounds');
            $this->fail('Should have thrown ValidationException when adjusting below reserved quantity');
        } catch (\Illuminate\Validation\ValidationException $e) {
            $this->assertArrayHasKey('stock', $e->errors());
            $this->assertStringContainsString('ناتوانرێت ستۆک کەمبکرێتەوە بۆ خوار بڕی حجزکراو', $e->errors()['stock'][0]);
        }

        // Adjusting down by 5 (resulting in physical qty 15 == reserved 15) must succeed
        $stock->adjustStock(-5, 'ADJUSTMENT', $this->admin->id, 'manual', null, 'Testing valid boundary');
        $this->assertEquals(15, $stock->fresh()->quantity);
        $this->assertEquals(15, $stock->fresh()->reserved_quantity);
    }

    /** @test */
    public function test_sales_return_movement_flow_updates_stock_and_creates_transaction()
    {
        $stock = WarehouseStock::create([
            'warehouse_id' => $this->mainWarehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 10,
            'reserved_quantity' => 0,
        ]);

        $tx = $stock->adjustStock(
            5,
            StockTransaction::TYPE_RETURN,
            $this->admin->id,
            'sales_return',
            123,
            'Customer returned undamaged goods'
        );

        $this->assertEquals(15, $stock->fresh()->quantity);
        $this->assertEquals(15, $stock->fresh()->available);
        $this->assertEquals('RETURN', $tx->type);
        $this->assertEquals(5, $tx->quantity_change);
        $this->assertEquals(15, $tx->quantity_after);
        $this->assertEquals('sales_return', $tx->reference_type);
        $this->assertEquals(123, $tx->reference_id);
    }

    /** @test */
    public function test_partial_packing_preserves_historical_records_via_soft_deletes()
    {
        $customer = \App\Models\Customer::create([
            'name' => 'Partial Pack Customer',
            'phone' => '07700000004',
            'route_id' => \App\Models\Route::create(['name' => 'Route P', 'is_active' => true])->id,
            'price_type' => 'N1',
            'current_balance' => 0,
            'is_active' => true
        ]);

        $productPacked = Product::create([
            'name' => 'Packed Product',
            'sku' => 'SKU-PACKED',
            'cost_price' => 1000,
            'price_n1' => 1500,
            'is_active' => true,
        ]);

        $productUnpacked = Product::create([
            'name' => 'Unpacked Product',
            'sku' => 'SKU-UNPACKED',
            'cost_price' => 2000,
            'price_n1' => 3000,
            'is_active' => true,
        ]);

        WarehouseStock::create([
            'warehouse_id' => $this->mainWarehouse->id,
            'product_id' => $productPacked->id,
            'quantity' => 50,
            'reserved_quantity' => 0,
        ]);

        WarehouseStock::create([
            'warehouse_id' => $this->mainWarehouse->id,
            'product_id' => $productUnpacked->id,
            'quantity' => 50,
            'reserved_quantity' => 0,
        ]);

        $order = SalesOrder::create([
            'order_number' => 'SO-PARTIAL-1',
            'customer_id' => $customer->id,
            'salesman_id' => $this->admin->id,
            'warehouse_id' => $this->mainWarehouse->id,
            'order_date' => now()->toDateString(),
            'status' => SalesOrder::STATUS_CONFIRMED,
            'subtotal' => 7500,
            'total_amount' => 7500,
            'total_profit' => 2500,
            'created_by' => $this->admin->id,
        ]);

        $item1 = $order->items()->create([
            'product_id' => $productPacked->id,
            'quantity' => 3,
            'unit_price' => 1500,
            'cost_price' => 1000,
            'price_type' => 'N1',
            'line_total' => 4500,
            'profit' => 1500,
            'is_packed' => true,
        ]);

        $item2 = $order->items()->create([
            'product_id' => $productUnpacked->id,
            'quantity' => 1,
            'unit_price' => 3000,
            'cost_price' => 2000,
            'price_type' => 'N1',
            'line_total' => 3000,
            'profit' => 1000,
            'is_packed' => false,
        ]);

        WarehouseStock::where('product_id', $productPacked->id)->update(['reserved_quantity' => 3]);
        WarehouseStock::where('product_id', $productUnpacked->id)->update(['reserved_quantity' => 1]);

        $service = app(SalesOrderService::class);
        $service->transitionTo($order, SalesOrder::STATUS_READY, $this->admin);

        // 1. Order status is READY
        $order->refresh();
        $this->assertEquals(SalesOrder::STATUS_READY, $order->status);

        // 2. Unpacked item reservation was released
        $this->assertEquals(0, WarehouseStock::where('product_id', $productUnpacked->id)->first()->reserved_quantity);
        $this->assertEquals(3, WarehouseStock::where('product_id', $productPacked->id)->first()->reserved_quantity);

        // 3. Active order items only count the packed item
        $this->assertEquals(1, $order->items()->count());
        $this->assertEquals(4500, $order->subtotal);
        $this->assertEquals(4500, $order->total_amount);

        // 4. Historical record is PRESERVED via soft delete
        $this->assertEquals(2, $order->items()->withTrashed()->count());
        $deletedItem = \App\Models\SalesOrderItem::withTrashed()->find($item2->id);
        $this->assertNotNull($deletedItem);
        $this->assertNotNull($deletedItem->deleted_at);
    }

    /** @test */
    public function test_manual_adjustment_accepts_adjustment_only_and_rejects_disallowed_types()
    {
        // 1. ADJUSTMENT is accepted
        $response = $this->actingAs($this->admin)->postJson(
            "/api/v1/warehouses/{$this->mainWarehouse->id}/stock/{$this->product->id}/adjust",
            ['quantity_change' => 10, 'type' => 'ADJUSTMENT', 'notes' => 'Manual adj test']
        );
        $response->assertStatus(200);

        // Disallowed movement types must be rejected with 422
        $disallowedTypes = [
            'RETURN',
            'PURCHASE',
            'DELIVERY',
            'SALE',
            'TRANSFER_IN',
            'TRANSFER_OUT',
            'RESERVE',
            'RELEASE',
        ];

        foreach ($disallowedTypes as $disallowedType) {
            $errResponse = $this->actingAs($this->admin)->postJson(
                "/api/v1/warehouses/{$this->mainWarehouse->id}/stock/{$this->product->id}/adjust",
                ['quantity_change' => 5, 'type' => $disallowedType, 'notes' => 'Unauthorized attempt']
            );
            $errResponse->assertStatus(422);
            $errResponse->assertJsonValidationErrors(['type']);
        }

        // Verify stock transaction history records ADJUSTMENT only
        $transactions = StockTransaction::where('warehouse_id', $this->mainWarehouse->id)
            ->where('product_id', $this->product->id)
            ->where('reference_type', 'manual_adjustment')
            ->get();

        $this->assertNotEmpty($transactions);
        foreach ($transactions as $tx) {
            $this->assertEquals('ADJUSTMENT', $tx->type);
        }
    }

    /** @test */
    public function test_manual_adjustment_durable_idempotency_and_different_key_behavior()
    {
        $payload = [
            'quantity_change' => 15,
            'type' => 'ADJUSTMENT',
            'notes' => 'Durable Idempotency Test',
        ];

        $key = 'IDEM-KEY-UNIQUE-1001';

        // First request with idempotency key
        $res1 = $this->actingAs($this->admin)->postJson(
            "/api/v1/warehouses/{$this->mainWarehouse->id}/stock/{$this->product->id}/adjust",
            $payload,
            ['X-Idempotency-Key' => $key]
        );
        $res1->assertStatus(200);

        $stockAfterFirst = WarehouseStock::where('warehouse_id', $this->mainWarehouse->id)
            ->where('product_id', $this->product->id)
            ->first()->quantity;

        // Repeat request with exact same idempotency key
        $res2 = $this->actingAs($this->admin)->postJson(
            "/api/v1/warehouses/{$this->mainWarehouse->id}/stock/{$this->product->id}/adjust",
            $payload,
            ['X-Idempotency-Key' => $key]
        );
        $res2->assertStatus(200);

        $stockAfterRepeat = WarehouseStock::where('warehouse_id', $this->mainWarehouse->id)
            ->where('product_id', $this->product->id)
            ->first()->quantity;

        // Repeated same key must produce ONLY ONE stock effect
        $this->assertEquals($stockAfterFirst, $stockAfterRepeat);

        // Same payload with a DIFFERENT idempotency key remains a DIFFERENT legitimate operation
        $differentKey = 'IDEM-KEY-UNIQUE-1002';
        $res3 = $this->actingAs($this->admin)->postJson(
            "/api/v1/warehouses/{$this->mainWarehouse->id}/stock/{$this->product->id}/adjust",
            $payload,
            ['X-Idempotency-Key' => $differentKey]
        );
        $res3->assertStatus(200);

        $stockAfterDifferentKey = WarehouseStock::where('warehouse_id', $this->mainWarehouse->id)
            ->where('product_id', $this->product->id)
            ->first()->quantity;

        // Different key must execute a second legitimate adjustment (+15)
        $this->assertEquals($stockAfterRepeat + 15, $stockAfterDifferentKey);
    }
}
