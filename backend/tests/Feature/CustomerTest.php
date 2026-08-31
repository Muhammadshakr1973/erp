<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Role;
use App\Models\Customer;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class CustomerTest extends TestCase
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
    public function it_can_create_a_customer()
    {
        $payload = [
            'name' => 'Test Customer',
            'phone' => '07501234567',
            'price_tier' => 'RETAIL'
        ];

        $response = $this->actingAs($this->admin)->postJson('/api/v1/customers', $payload);

        $response->assertStatus(201);
        $this->assertDatabaseHas('customers', ['name' => 'Test Customer']);
    }

    /** @test */
    public function it_can_update_a_customer()
    {
        $customer = Customer::create([
            'name' => 'Old Name',
            'phone' => '07501112233',
            'price_tier' => 'RETAIL'
        ]);

        $response = $this->actingAs($this->admin)->putJson('/api/v1/customers/' . $customer->id, [
            'name' => 'New Name',
            'price_tier' => 'WHOLESALE'
        ]);

        $response->assertStatus(200);
        $this->assertDatabaseHas('customers', ['name' => 'New Name', 'price_tier' => 'WHOLESALE']);
    }

    /** @test */
    public function create_customer_is_idempotent_with_same_key()
    {
        $idempotencyKey = 'cust-create-key-123';
        $payload = [
            'name' => 'Idempotent Customer',
            'phone' => '07509998877',
            'price_tier' => 'RETAIL'
        ];

        // First attempt
        $res1 = $this->actingAs($this->admin)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/customers', $payload);

        $res1->assertStatus(201);
        $customerId = $res1->json('data.id');

        // Retry attempt with SAME key
        $res2 = $this->actingAs($this->admin)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/customers', $payload);

        $res2->assertStatus(201);
        $res2->assertHeader('X-Cache-Lookup', 'HIT');
        $res2->assertJsonPath('data.id', $customerId);

        // Ensure exactly ONE customer record exists in DB
        $this->assertEquals(1, Customer::where('phone', '07509998877')->count());
    }

    /** @test */
    public function update_customer_is_idempotent_with_same_key()
    {
        $customer = Customer::create([
            'name' => 'Original Name',
            'phone' => '07505554433',
            'price_tier' => 'RETAIL'
        ]);

        $idempotencyKey = 'cust-update-key-456';
        $payload = [
            'name' => 'Updated Idempotent Name',
            'price_tier' => 'WHOLESALE'
        ];

        // First attempt
        $res1 = $this->actingAs($this->admin)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->putJson('/api/v1/customers/' . $customer->id, $payload);

        $res1->assertStatus(200);

        // Retry attempt with SAME key
        $res2 = $this->actingAs($this->admin)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->putJson('/api/v1/customers/' . $customer->id, $payload);

        $res2->assertStatus(200);
        $res2->assertHeader('X-Cache-Lookup', 'HIT');
    }
}
