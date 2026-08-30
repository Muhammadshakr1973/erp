<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Role;
use App\Models\Customer;
use App\Models\Warehouse;
use App\Models\Product;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class IdempotencyConcurrencyTest extends TestCase
{
    use RefreshDatabase;

    private User $user;
    private Customer $customer;
    private Warehouse $warehouse;
    private Product $product;

    protected function setUp(): void
    {
        parent::setUp();

        $role = Role::create([
            'name' => 'salesman',
            'permissions' => ['orders.create', 'customers.view']
        ]);

        $this->user = User::create([
            'name' => 'Salesman',
            'phone' => '07700000001',
            'password' => bcrypt('password'),
            'role_id' => $role->id,
            'is_active' => true
        ]);

        $route = \App\Models\Route::create([
            'name' => 'Route A',
            'is_active' => true,
        ]);

        // Assign salesman to route for today
        DB::table('route_salesmen')->insert([
            'route_id' => $route->id,
            'salesman_id' => $this->user->id,
            'work_date' => now()->toDateString(),
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->customer = Customer::create([
            'name' => 'Test Customer',
            'phone' => '07701111111',
            'route_id' => $route->id,
            'price_type' => 'N2',
            'current_balance' => 0,
            'is_active' => true
        ]);

        $this->warehouse = Warehouse::create([
            'name' => 'Main Warehouse',
            'is_main' => true,
            'is_active' => true,
        ]);

        $this->product = Product::create([
            'name' => 'Test Product',
            'sku' => 'TEST-SKU',
            'unit' => 'PCS',
            'cost_price' => 5000,
            'price_n1' => 8000,
            'price_n2' => 7500,
            'price_n3' => 7000,
            'is_active' => true,
        ]);

        DB::table('warehouse_stocks')->insert([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 100,
            'reserved_quantity' => 0,
            'created_at' => now(),
            'updated_at' => now()
        ]);
    }

    /**
     * Test that an identical duplicate request with the same idempotency key
     * yields the exact same cached response without duplicating business side effects.
     */
    public function test_duplicate_requests_with_same_key_returns_cached_response_and_does_not_duplicate_effect(): void
    {
        $idempotencyKey = 'test-idempotency-key-unique-123';

        // 1. Submit payment first time
        $payload = [
            'customer_id' => $this->customer->id,
            'amount' => 150,
            'payment_method' => 'CASH',
            'notes' => 'First submission'
        ];

        $response1 = $this->actingAs($this->user)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/payments', $payload);

        $response1->assertStatus(201);
        $response1->assertJsonPath('data.amount', 150);

        // Check database effects (Exactly 1 payment and ledger entries created)
        $this->assertEquals(1, DB::table('customer_payments')->count());
        $this->assertEquals(1, DB::table('customer_ledgers')->count());

        // 2. Resubmit with the same key
        $response2 = $this->actingAs($this->user)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/payments', $payload);

        // Should return cached response with identical structure and status
        $response2->assertStatus(201);
        $response2->assertHeader('X-Cache-Lookup', 'HIT');
        $response2->assertJsonPath('data.amount', 150);

        // Ensure database is safe - still only 1 record exists!
        $this->assertEquals(1, DB::table('customer_payments')->count());
        $this->assertEquals(1, DB::table('customer_ledgers')->count());
    }

    /**
     * Test that concurrent submissions (key is registered but status is 'processing')
     * are rejected with a 409 Conflict.
     */
    public function test_concurrent_requests_with_same_key_return_409_conflict(): void
    {
        $idempotencyKey = 'test-concurrent-key-999';

        // Pre-insert the key in database to simulate an active, ongoing concurrent request
        DB::table('idempotency_keys')->insert([
            'idempotency_key' => $idempotencyKey,
            'request_path' => 'api/v1/payments',
            'request_params' => json_encode([]),
            'status' => 'processing',
            'created_at' => now(),
            'updated_at' => now()
        ]);

        $payload = [
            'customer_id' => $this->customer->id,
            'amount' => 150,
            'payment_method' => 'CASH'
        ];

        $response = $this->actingAs($this->user)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/payments', $payload);

        // Assert 409 Conflict to prevent racing conditions
        $response->assertStatus(409);
        $response->assertJsonStructure(['message', 'error']);

        // Check that no payment was created
        $this->assertEquals(0, DB::table('customer_payments')->count());
    }

    /**
     * Test that a failed request (e.g. validation error) deletes the idempotency key,
     * allowing a corrected retry using the same key.
     */
    public function test_failed_requests_do_not_persist_idempotency_block_and_allow_retry(): void
    {
        $idempotencyKey = 'test-failed-retry-key';

        // Submit invalid payload (e.g. missing amount)
        $payload = [
            'customer_id' => $this->customer->id,
            'payment_method' => 'CASH'
        ];

        $response1 = $this->actingAs($this->user)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/payments', $payload);

        // Fails with 422 Unprocessable Entity
        $response1->assertStatus(422);

        // Ensure the key was purged so it is not blocked
        $this->assertEquals(0, DB::table('idempotency_keys')->where('idempotency_key', $idempotencyKey)->count());

        // Now submit valid payload using the SAME key
        $payload['amount'] = 200;
        $response2 = $this->actingAs($this->user)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/payments', $payload);

        $response2->assertStatus(201);
        $response2->assertJsonPath('data.amount', 200);
        $this->assertEquals(1, DB::table('customer_payments')->count());
    }

    /**
     * Scenario 1: First request of CREATE_ORDER creates a sales order and returns HTTP 201.
     */
    public function test_first_request_creates_sales_order_correctly(): void
    {
        $idempotencyKey = 'order-key-1';
        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 5]
            ]
        ];

        $response = $this->actingAs($this->user)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/orders', $payload);

        $response->assertStatus(201);
        $response->assertJsonPath('data.customer_id', $this->customer->id);

        $this->assertEquals(1, DB::table('sales_orders')->count());
    }

    /**
     * Scenario 2: Exact retry of CREATE_ORDER returns the original cached response without duplicate creation.
     */
    public function test_exact_retry_returns_cached_response_and_does_not_duplicate(): void
    {
        $idempotencyKey = 'order-key-2';
        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 3]
            ]
        ];

        // First attempt
        $response1 = $this->actingAs($this->user)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/orders', $payload);

        $response1->assertStatus(201);
        $orderId = $response1->json('data.id');

        // Retry attempt
        $response2 = $this->actingAs($this->user)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/orders', $payload);

        $response2->assertStatus(201);
        $response2->assertHeader('X-Cache-Lookup', 'HIT');
        $response2->assertJsonPath('data.id', $orderId);

        // Ensure database state is pristine and no duplicate records are generated
        $this->assertEquals(1, DB::table('sales_orders')->where('id', $orderId)->count());
    }

    /**
     * Scenario 3: Retry after hours returns the original cached response.
     */
    public function test_retry_after_hours_returns_original_cached_response(): void
    {
        $idempotencyKey = 'order-key-3';
        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 2]
            ]
        ];

        // Simulate an old response completed 5 hours ago
        DB::table('idempotency_keys')->insert([
            'idempotency_key' => $idempotencyKey,
            'user_id' => $this->user->id,
            'request_path' => 'api/v1/orders',
            'request_params' => json_encode($payload),
            'status' => 'completed',
            'response_status' => 201,
            'response_body' => json_encode(['replayed' => true, 'order_id' => 9999]),
            'created_at' => now()->subHours(5),
            'updated_at' => now()->subHours(5)
        ]);

        $response = $this->actingAs($this->user)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/orders', $payload);

        $response->assertStatus(201);
        $response->assertHeader('X-Cache-Lookup', 'HIT');
        $response->assertJsonPath('order_id', 9999);
    }

    /**
     * Scenario 4: Concurrent duplicate requests with the same key are blocked with HTTP 409.
     */
    public function test_concurrent_duplicate_order_requests_return_409_conflict(): void
    {
        $idempotencyKey = 'order-key-4';
        
        DB::table('idempotency_keys')->insert([
            'idempotency_key' => $idempotencyKey,
            'user_id' => $this->user->id,
            'request_path' => 'api/v1/orders',
            'request_params' => json_encode([]),
            'status' => 'processing',
            'created_at' => now(),
            'updated_at' => now()
        ]);

        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 1]
            ]
        ];

        $response = $this->actingAs($this->user)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/orders', $payload);

        $response->assertStatus(409);
        $response->assertJsonPath('error', 'Conflict. A request with this key is already being processed.');
    }

    /**
     * Scenario 5: Failed database transactions purge the idempotency key, allowing subsequent clean retries.
     */
    public function test_failed_transaction_purges_key_and_allows_subsequent_retry(): void
    {
        $idempotencyKey = 'order-key-5';
        
        // This payload will fail validation/database checks (e.g. non-existent warehouse id)
        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => 99999, // Non-existent warehouse to trigger DB foreign key/validation failure
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 1]
            ]
        ];

        $response1 = $this->actingAs($this->user)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/orders', $payload);

        // Fails due to validation/not found constraints
        $response1->assertStatus(422);

        // Key must have been cleanly deleted to make retry possible
        $this->assertEquals(0, DB::table('idempotency_keys')->where('idempotency_key', $idempotencyKey)->count());

        // Now try with a fully valid payload using the SAME key
        $payload['warehouse_id'] = $this->warehouse->id;
        $response2 = $this->actingAs($this->user)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/orders', $payload);

        $response2->assertStatus(201);
        $this->assertEquals(1, DB::table('sales_orders')->count());
    }

    /**
     * Scenario 6: Replaying a request with the same key but different payload returns original cached response.
     */
    public function test_same_key_with_different_payload_replays_original_cached_response(): void
    {
        $idempotencyKey = 'order-key-6';
        $payload1 = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 1]
            ]
        ];

        $response1 = $this->actingAs($this->user)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/orders', $payload1);

        $response1->assertStatus(201);
        $originalOrderId = $response1->json('data.id');

        // Send a different payload with the SAME key
        $payload2 = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 10] // different quantity
            ]
        ];

        $response2 = $this->actingAs($this->user)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/orders', $payload2);

        $response2->assertStatus(201);
        $response2->assertHeader('X-Cache-Lookup', 'HIT');
        $response2->assertJsonPath('data.id', $originalOrderId);
    }

    /**
     * Scenario 7: Different users using different keys do not collide.
     */
    public function test_different_users_using_different_keys_do_not_collide(): void
    {
        // 1. Create a second salesman user
        $role = Role::where('name', 'salesman')->first();
        $userB = User::create([
            'name' => 'Salesman B',
            'phone' => '07700000002',
            'password' => bcrypt('password'),
            'role_id' => $role->id,
            'is_active' => true
        ]);

        // Assign userB to route for today
        DB::table('route_salesmen')->insert([
            'route_id' => $this->customer->route_id,
            'salesman_id' => $userB->id,
            'work_date' => now()->toDateString(),
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $payloadA = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 1]
            ]
        ];

        $payloadB = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 2]
            ]
        ];

        // User A submits key A
        $responseA = $this->actingAs($this->user)
            ->withHeader('X-Idempotency-Key', 'user-a-key')
            ->postJson('/api/v1/orders', $payloadA);
        $responseA->assertStatus(201);

        // User B submits key B
        $responseB = $this->actingAs($userB)
            ->withHeader('X-Idempotency-Key', 'user-b-key')
            ->postJson('/api/v1/orders', $payloadB);
        $responseB->assertStatus(201);

        $this->assertEquals(2, DB::table('sales_orders')->count());
    }

    /**
     * Scenario 8: Different users using the same key are protected against cross-user replay (Forbidden 403).
     */
    public function test_different_users_using_same_key_rejected_with_403_forbidden(): void
    {
        // Create second salesman user
        $role = Role::where('name', 'salesman')->first();
        $userB = User::create([
            'name' => 'Salesman B',
            'phone' => '07700000002',
            'password' => bcrypt('password'),
            'role_id' => $role->id,
            'is_active' => true
        ]);

        // Assign userB to route for today
        DB::table('route_salesmen')->insert([
            'route_id' => $this->customer->route_id,
            'salesman_id' => $userB->id,
            'work_date' => now()->toDateString(),
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $idempotencyKey = 'shared-idempotency-key';
        $payload = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 1]
            ]
        ];

        // User A submits with the key first
        $responseA = $this->actingAs($this->user)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/orders', $payload);
        $responseA->assertStatus(201);

        // User B attempts to submit with the SAME key
        $responseB = $this->actingAs($userB)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/orders', $payload);

        // Rejected with 403 Forbidden to protect user privacy and cross-user replay security
        $responseB->assertStatus(403);
        $responseB->assertJsonPath('error', 'Forbidden. This idempotency key belongs to another user.');
    }
}
