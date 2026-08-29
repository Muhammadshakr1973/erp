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

        $this->customer = Customer::create([
            'name' => 'Test Customer',
            'phone' => '07701111111',
            'route_id' => 1,
            'current_balance' => 1000
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
}
