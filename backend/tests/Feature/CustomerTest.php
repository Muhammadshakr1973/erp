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
}
