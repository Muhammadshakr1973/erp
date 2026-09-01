<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Role;
use App\Models\Warehouse;
use App\Models\WarehouseStock;
use App\Models\Product;
use App\Models\StockTransfer;
use App\Models\StockTransferItem;
use App\Models\StockTransaction;
use App\Models\AuditLog;
use App\Services\StockTransferService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

class StockTransferTest extends TestCase
{
    use RefreshDatabase;

    protected $admin;
    protected $warehouse1;
    protected $warehouse2;
    protected $warehouse3;
    protected $productA;
    protected $productB;

    protected function setUp(): void
    {
        parent::setUp();

        $role = Role::firstOrCreate(['name' => 'admin'], [
            'display_name' => 'Admin',
            'permissions'  => json_encode(['*']),
        ]);

        $this->admin = User::factory()->create([
            'role_id'   => $role->id,
            'is_active' => true,
        ]);

        $this->warehouse1 = Warehouse::create(['name' => 'Warehouse Alpha', 'is_active' => true]);
        $this->warehouse2 = Warehouse::create(['name' => 'Warehouse Beta', 'is_active' => true]);
        $this->warehouse3 = Warehouse::create(['name' => 'Warehouse Gamma', 'is_active' => true]);

        $this->productA = Product::create([
            'name'       => 'Product Alpha',
            'sku'        => 'SKU-A',
            'cost_price' => 1000,
            'is_active'  => true,
        ]);

        $this->productB = Product::create([
            'name'       => 'Product Beta',
            'sku'        => 'SKU-B',
            'cost_price' => 2000,
            'is_active'  => true,
        ]);
    }

    /** @test */
    public function test_1_create_valid_stock_transfer()
    {
        $payload = [
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'notes'             => 'Initial transfer request',
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 10],
            ],
        ];

        $response = $this->actingAs($this->admin)->postJson('/api/v1/stock-transfers', $payload);

        $response->assertStatus(201);
        $response->assertJsonPath('data.from_warehouse_id', $this->warehouse1->id);
        $response->assertJsonPath('data.to_warehouse_id', $this->warehouse2->id);
        $response->assertJsonPath('data.status', StockTransfer::STATUS_DRAFT);

        $this->assertDatabaseHas('stock_transfers', [
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'status'            => StockTransfer::STATUS_DRAFT,
        ]);

        $this->assertDatabaseHas('stock_transfer_items', [
            'product_id' => $this->productA->id,
            'quantity'   => 10,
        ]);
    }

    /** @test */
    public function test_2_reject_source_equals_destination_warehouse()
    {
        $payload = [
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse1->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 5],
            ],
        ];

        $response = $this->actingAs($this->admin)->postJson('/api/v1/stock-transfers', $payload);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors(['to_warehouse_id']);
    }

    /** @test */
    public function test_3_reject_nonexistent_product()
    {
        $payload = [
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => 999999, 'quantity' => 5],
            ],
        ];

        $response = $this->actingAs($this->admin)->postJson('/api/v1/stock-transfers', $payload);

        $response->assertStatus(422);
    }

    /** @test */
    public function test_4_reject_zero_quantity()
    {
        $payload = [
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 0],
            ],
        ];

        $response = $this->actingAs($this->admin)->postJson('/api/v1/stock-transfers', $payload);

        $response->assertStatus(422);
    }

    /** @test */
    public function test_5_reject_negative_quantity()
    {
        $payload = [
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => -10],
            ],
        ];

        $response = $this->actingAs($this->admin)->postJson('/api/v1/stock-transfers', $payload);

        $response->assertStatus(422);
    }

    /** @test */
    public function test_6_reject_transfer_quantity_greater_than_available_source_stock()
    {
        WarehouseStock::create([
            'warehouse_id'      => $this->warehouse1->id,
            'product_id'        => $this->productA->id,
            'quantity'          => 20,
            'reserved_quantity' => 5, // available = 15
        ]);

        $service = app(StockTransferService::class);
        $transfer = $service->createTransfer([
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 20],
            ],
        ], $this->admin);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/stock-transfers/{$transfer->id}/complete");

        $response->assertStatus(422);
        $this->assertEquals(StockTransfer::STATUS_DRAFT, $transfer->fresh()->status);
    }

    /** @test */
    public function test_7_successful_completion_decreases_source_stock()
    {
        WarehouseStock::create([
            'warehouse_id'      => $this->warehouse1->id,
            'product_id'        => $this->productA->id,
            'quantity'          => 50,
            'reserved_quantity' => 0,
        ]);

        $service = app(StockTransferService::class);
        $transfer = $service->createTransfer([
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 15],
            ],
        ], $this->admin);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/stock-transfers/{$transfer->id}/complete");

        $response->assertStatus(200);
        $sourceStock = WarehouseStock::where('warehouse_id', $this->warehouse1->id)
            ->where('product_id', $this->productA->id)
            ->first();

        $this->assertEquals(35, $sourceStock->quantity);
    }

    /** @test */
    public function test_8_successful_completion_increases_destination_stock()
    {
        WarehouseStock::create([
            'warehouse_id'      => $this->warehouse1->id,
            'product_id'        => $this->productA->id,
            'quantity'          => 50,
            'reserved_quantity' => 0,
        ]);

        $service = app(StockTransferService::class);
        $transfer = $service->createTransfer([
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 15],
            ],
        ], $this->admin);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/stock-transfers/{$transfer->id}/complete");

        $response->assertStatus(200);
        $destStock = WarehouseStock::where('warehouse_id', $this->warehouse2->id)
            ->where('product_id', $this->productA->id)
            ->first();

        $this->assertNotNull($destStock);
        $this->assertEquals(15, $destStock->quantity);
    }

    /** @test */
    public function test_9_transfer_out_stock_transaction_is_created()
    {
        WarehouseStock::create([
            'warehouse_id'      => $this->warehouse1->id,
            'product_id'        => $this->productA->id,
            'quantity'          => 40,
            'reserved_quantity' => 0,
        ]);

        $service = app(StockTransferService::class);
        $transfer = $service->createTransfer([
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 10],
            ],
        ], $this->admin);

        $this->actingAs($this->admin)->postJson("/api/v1/stock-transfers/{$transfer->id}/complete");

        $this->assertDatabaseHas('stock_transactions', [
            'warehouse_id'    => $this->warehouse1->id,
            'product_id'      => $this->productA->id,
            'type'            => 'TRANSFER_OUT',
            'quantity_change' => -10,
            'reference_type'  => 'stock_transfer',
            'reference_id'    => $transfer->id,
        ]);
    }

    /** @test */
    public function test_10_transfer_in_stock_transaction_is_created()
    {
        WarehouseStock::create([
            'warehouse_id'      => $this->warehouse1->id,
            'product_id'        => $this->productA->id,
            'quantity'          => 40,
            'reserved_quantity' => 0,
        ]);

        $service = app(StockTransferService::class);
        $transfer = $service->createTransfer([
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 10],
            ],
        ], $this->admin);

        $this->actingAs($this->admin)->postJson("/api/v1/stock-transfers/{$transfer->id}/complete");

        $this->assertDatabaseHas('stock_transactions', [
            'warehouse_id'    => $this->warehouse2->id,
            'product_id'      => $this->productA->id,
            'type'            => 'TRANSFER_IN',
            'quantity_change' => 10,
            'reference_type'  => 'stock_transfer',
            'reference_id'    => $transfer->id,
        ]);
    }

    /** @test */
    public function test_11_completion_is_atomic_all_or_nothing()
    {
        WarehouseStock::create([
            'warehouse_id'      => $this->warehouse1->id,
            'product_id'        => $this->productA->id,
            'quantity'          => 50,
            'reserved_quantity' => 0,
        ]);
        WarehouseStock::create([
            'warehouse_id'      => $this->warehouse1->id,
            'product_id'        => $this->productB->id,
            'quantity'          => 5,
            'reserved_quantity' => 0,
        ]);

        $service = app(StockTransferService::class);
        $transfer = $service->createTransfer([
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 10], // has stock
                ['product_id' => $this->productB->id, 'quantity' => 20], // exceeds available (5)
            ],
        ], $this->admin);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/stock-transfers/{$transfer->id}/complete");

        $response->assertStatus(422);

        // Assert atomicity: neither product moved
        $this->assertEquals(50, WarehouseStock::where('warehouse_id', $this->warehouse1->id)->where('product_id', $this->productA->id)->first()->quantity);
        $this->assertEquals(5, WarehouseStock::where('warehouse_id', $this->warehouse1->id)->where('product_id', $this->productB->id)->first()->quantity);
        $this->assertNull(WarehouseStock::where('warehouse_id', $this->warehouse2->id)->where('product_id', $this->productA->id)->first());
    }

    /** @test */
    public function test_12_destination_stock_failure_rolls_back_source_mutation()
    {
        WarehouseStock::create([
            'warehouse_id'      => $this->warehouse1->id,
            'product_id'        => $this->productA->id,
            'quantity'          => 30,
            'reserved_quantity' => 0,
        ]);

        $service = app(StockTransferService::class);
        $transfer = $service->createTransfer([
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 10],
            ],
        ], $this->admin);

        // Verify initial state
        $this->assertEquals(30, WarehouseStock::where('warehouse_id', $this->warehouse1->id)->where('product_id', $this->productA->id)->first()->quantity);
    }

    /** @test */
    public function test_13_source_stock_failure_rolls_back_all_mutations()
    {
        WarehouseStock::create([
            'warehouse_id'      => $this->warehouse1->id,
            'product_id'        => $this->productA->id,
            'quantity'          => 2,
            'reserved_quantity' => 0,
        ]);

        $service = app(StockTransferService::class);
        $transfer = $service->createTransfer([
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 10],
            ],
        ], $this->admin);

        $response = $this->actingAs($this->admin)->postJson("/api/v1/stock-transfers/{$transfer->id}/complete");
        $response->assertStatus(422);

        $this->assertEquals(2, WarehouseStock::where('warehouse_id', $this->warehouse1->id)->where('product_id', $this->productA->id)->first()->quantity);
        $this->assertEquals(0, StockTransaction::where('reference_type', 'stock_transfer')->where('reference_id', $transfer->id)->count());
    }

    /** @test */
    public function test_14_concurrent_transfers_cannot_produce_negative_source_stock()
    {
        WarehouseStock::create([
            'warehouse_id'      => $this->warehouse1->id,
            'product_id'        => $this->productA->id,
            'quantity'          => 15,
            'reserved_quantity' => 0,
        ]);

        $service = app(StockTransferService::class);
        $transfer1 = $service->createTransfer([
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 10],
            ],
        ], $this->admin);

        $transfer2 = $service->createTransfer([
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 10],
            ],
        ], $this->admin);

        $res1 = $this->actingAs($this->admin)->postJson("/api/v1/stock-transfers/{$transfer1->id}/complete");
        $res1->assertStatus(200);

        $res2 = $this->actingAs($this->admin)->postJson("/api/v1/stock-transfers/{$transfer2->id}/complete");
        $res2->assertStatus(422);

        $this->assertEquals(5, WarehouseStock::where('warehouse_id', $this->warehouse1->id)->where('product_id', $this->productA->id)->first()->quantity);
    }

    /** @test */
    public function test_15_same_request_duplicate_product_lines_are_safely_normalized()
    {
        WarehouseStock::create([
            'warehouse_id'      => $this->warehouse1->id,
            'product_id'        => $this->productA->id,
            'quantity'          => 30,
            'reserved_quantity' => 0,
        ]);

        $payload = [
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 4],
                ['product_id' => $this->productA->id, 'quantity' => 6],
            ],
        ];

        $response = $this->actingAs($this->admin)->postJson('/api/v1/stock-transfers', $payload);
        $response->assertStatus(201);

        $transferId = $response->json('data.id');
        $completeRes = $this->actingAs($this->admin)->postJson("/api/v1/stock-transfers/{$transferId}/complete");
        $completeRes->assertStatus(200);

        $this->assertEquals(20, WarehouseStock::where('warehouse_id', $this->warehouse1->id)->where('product_id', $this->productA->id)->first()->quantity);
        $this->assertEquals(10, WarehouseStock::where('warehouse_id', $this->warehouse2->id)->where('product_id', $this->productA->id)->first()->quantity);
    }

    /** @test */
    public function test_16_already_completed_transfer_cannot_be_completed_twice()
    {
        WarehouseStock::create([
            'warehouse_id'      => $this->warehouse1->id,
            'product_id'        => $this->productA->id,
            'quantity'          => 50,
            'reserved_quantity' => 0,
        ]);

        $service = app(StockTransferService::class);
        $transfer = $service->createTransfer([
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 10],
            ],
        ], $this->admin);

        $res1 = $this->actingAs($this->admin)->postJson("/api/v1/stock-transfers/{$transfer->id}/complete");
        $res1->assertStatus(200);

        // Second completion should be idempotent and not re-deduct
        $res2 = $this->actingAs($this->admin)->postJson("/api/v1/stock-transfers/{$transfer->id}/complete");
        $res2->assertStatus(200);

        $this->assertEquals(40, WarehouseStock::where('warehouse_id', $this->warehouse1->id)->where('product_id', $this->productA->id)->first()->quantity);
        $this->assertEquals(10, WarehouseStock::where('warehouse_id', $this->warehouse2->id)->where('product_id', $this->productA->id)->first()->quantity);
        $this->assertEquals(1, StockTransaction::where('reference_type', 'stock_transfer')->where('type', 'TRANSFER_OUT')->count());
    }

    /** @test */
    public function test_17_completed_transfer_cannot_be_cancelled()
    {
        WarehouseStock::create([
            'warehouse_id'      => $this->warehouse1->id,
            'product_id'        => $this->productA->id,
            'quantity'          => 50,
            'reserved_quantity' => 0,
        ]);

        $service = app(StockTransferService::class);
        $transfer = $service->createTransfer([
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 10],
            ],
        ], $this->admin);

        $this->actingAs($this->admin)->postJson("/api/v1/stock-transfers/{$transfer->id}/complete");

        $cancelRes = $this->actingAs($this->admin)->postJson("/api/v1/stock-transfers/{$transfer->id}/cancel");
        $cancelRes->assertStatus(422);

        $this->assertEquals(StockTransfer::STATUS_COMPLETED, $transfer->fresh()->status);
    }

    /** @test */
    public function test_18_pending_transfer_can_be_cancelled_according_to_existing_rules()
    {
        $service = app(StockTransferService::class);
        $transfer = $service->createTransfer([
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 10],
            ],
        ], $this->admin);

        $cancelRes = $this->actingAs($this->admin)->postJson("/api/v1/stock-transfers/{$transfer->id}/cancel");
        $cancelRes->assertStatus(200);

        $this->assertEquals(StockTransfer::STATUS_CANCELLED, $transfer->fresh()->status);
    }

    /** @test */
    public function test_19_same_idempotency_key_same_payload_returns_cached_response()
    {
        $key = (string)Str::uuid();
        $payload = [
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 5],
            ],
        ];

        $res1 = $this->actingAs($this->admin)
            ->withHeaders(['X-Idempotency-Key' => $key])
            ->postJson('/api/v1/stock-transfers', $payload);
        $res1->assertStatus(201);

        $res2 = $this->actingAs($this->admin)
            ->withHeaders(['X-Idempotency-Key' => $key])
            ->postJson('/api/v1/stock-transfers', $payload);
        $res2->assertStatus(201);

        $this->assertEquals(1, StockTransfer::where('from_warehouse_id', $this->warehouse1->id)->count());
    }

    /** @test */
    public function test_20_same_idempotency_key_changed_payload_returns_422()
    {
        $key = (string)Str::uuid();
        $payload1 = [
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 5],
            ],
        ];

        $payload2 = [
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 15],
            ],
        ];

        $res1 = $this->actingAs($this->admin)
            ->withHeaders(['X-Idempotency-Key' => $key])
            ->postJson('/api/v1/stock-transfers', $payload1);
        $res1->assertStatus(201);

        $res2 = $this->actingAs($this->admin)
            ->withHeaders(['X-Idempotency-Key' => $key])
            ->postJson('/api/v1/stock-transfers', $payload2);
        $res2->assertStatus(422);
    }

    /** @test */
    public function test_21_different_idempotency_keys_remain_distinct_operations()
    {
        $key1 = (string)Str::uuid();
        $key2 = (string)Str::uuid();

        $payload = [
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 5],
            ],
        ];

        $res1 = $this->actingAs($this->admin)
            ->withHeaders(['X-Idempotency-Key' => $key1])
            ->postJson('/api/v1/stock-transfers', $payload);
        $res1->assertStatus(201);

        $res2 = $this->actingAs($this->admin)
            ->withHeaders(['X-Idempotency-Key' => $key2])
            ->postJson('/api/v1/stock-transfers', $payload);
        $res2->assertStatus(201);

        $this->assertEquals(2, StockTransfer::where('from_warehouse_id', $this->warehouse1->id)->count());
    }

    /** @test */
    public function test_22_unauthorized_user_cannot_complete_restricted_transfer()
    {
        $whRole = Role::firstOrCreate(['name' => 'warehouse'], [
            'display_name' => 'Warehouse',
            'permissions'  => json_encode(['stock.view', 'stock.pack']),
        ]);

        $restrictedUser = User::factory()->create([
            'role_id'      => $whRole->id,
            'warehouse_id' => $this->warehouse3->id, // belongs to warehouse 3
            'is_active'    => true,
        ]);

        $service = app(StockTransferService::class);
        $transfer = $service->createTransfer([
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 5],
            ],
        ], $this->admin);

        $response = $this->actingAs($restrictedUser)->postJson("/api/v1/stock-transfers/{$transfer->id}/complete");
        $response->assertStatus(403);
    }

    /** @test */
    public function test_23_offline_stock_transfer_create_remains_compatible()
    {
        $key = 'local_sync_' . Str::uuid();
        $payload = [
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'notes'             => 'Offline sync transfer',
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 8],
            ],
        ];

        $response = $this->actingAs($this->admin)
            ->withHeaders(['X-Idempotency-Key' => $key])
            ->postJson('/api/v1/stock-transfers', $payload);

        $response->assertStatus(201);
        $this->assertDatabaseHas('stock_transfers', [
            'notes'  => 'Offline sync transfer',
            'status' => StockTransfer::STATUS_DRAFT,
        ]);
    }

    /** @test */
    public function test_24_offline_stock_transfer_complete_remains_idempotent()
    {
        WarehouseStock::create([
            'warehouse_id'      => $this->warehouse1->id,
            'product_id'        => $this->productA->id,
            'quantity'          => 40,
            'reserved_quantity' => 0,
        ]);

        $service = app(StockTransferService::class);
        $transfer = $service->createTransfer([
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 12],
            ],
        ], $this->admin);

        $key = 'offline_complete_' . Str::uuid();

        $res1 = $this->actingAs($this->admin)
            ->withHeaders(['X-Idempotency-Key' => $key])
            ->postJson("/api/v1/stock-transfers/{$transfer->id}/complete", []);
        $res1->assertStatus(200);

        $res2 = $this->actingAs($this->admin)
            ->withHeaders(['X-Idempotency-Key' => $key])
            ->postJson("/api/v1/stock-transfers/{$transfer->id}/complete", []);
        $res2->assertStatus(200);

        $this->assertEquals(28, WarehouseStock::where('warehouse_id', $this->warehouse1->id)->where('product_id', $this->productA->id)->first()->quantity);
        $this->assertEquals(12, WarehouseStock::where('warehouse_id', $this->warehouse2->id)->where('product_id', $this->productA->id)->first()->quantity);
    }

    /** @test */
    public function test_25_offline_stock_transfer_cancel_remains_safe()
    {
        $service = app(StockTransferService::class);
        $transfer = $service->createTransfer([
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 10],
            ],
        ], $this->admin);

        $key = 'offline_cancel_' . Str::uuid();

        $res1 = $this->actingAs($this->admin)
            ->withHeaders(['X-Idempotency-Key' => $key])
            ->postJson("/api/v1/stock-transfers/{$transfer->id}/cancel", []);
        $res1->assertStatus(200);

        $res2 = $this->actingAs($this->admin)
            ->withHeaders(['X-Idempotency-Key' => $key])
            ->postJson("/api/v1/stock-transfers/{$transfer->id}/cancel", []);
        $res2->assertStatus(200);

        $this->assertEquals(StockTransfer::STATUS_CANCELLED, $transfer->fresh()->status);
    }

    /** @test */
    public function test_26_audit_event_is_created_exactly_once_per_effective_operation()
    {
        WarehouseStock::create([
            'warehouse_id'      => $this->warehouse1->id,
            'product_id'        => $this->productA->id,
            'quantity'          => 50,
            'reserved_quantity' => 0,
        ]);

        $service = app(StockTransferService::class);
        $transfer = $service->createTransfer([
            'from_warehouse_id' => $this->warehouse1->id,
            'to_warehouse_id'   => $this->warehouse2->id,
            'items'             => [
                ['product_id' => $this->productA->id, 'quantity' => 10],
            ],
        ], $this->admin);

        $this->actingAs($this->admin)->postJson("/api/v1/stock-transfers/{$transfer->id}/complete");

        $this->assertDatabaseHas('audit_logs', [
            'action'      => 'CREATE',
            'entity_type' => 'StockTransfer',
            'entity_id'   => $transfer->id,
        ]);

        $this->assertDatabaseHas('audit_logs', [
            'action'      => 'STOCK_TRANSFER_COMPLETE',
            'entity_type' => 'StockTransfer',
            'entity_id'   => $transfer->id,
        ]);
    }
}

