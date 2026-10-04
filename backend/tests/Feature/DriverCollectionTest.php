<?php

namespace Tests\Feature;

use App\Models\Role;
use App\Models\User;
use App\Models\DriverCollection;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DriverCollectionTest extends TestCase
{
    use RefreshDatabase;

    protected User $admin;
    protected User $driver;

    protected function setUp(): void
    {
        parent::setUp();

        $adminRole = Role::firstOrCreate(['name' => 'admin'], [
            'display_name' => 'Admin',
            'permissions' => ['*']
        ]);

        $driverRole = Role::firstOrCreate(['name' => 'driver'], [
            'display_name' => 'Driver',
            'permissions' => ['delivery.view']
        ]);

        $this->admin = User::factory()->create([
            'role_id'   => $adminRole->id,
            'is_active' => true,
        ]);

        $this->driver = User::factory()->create([
            'role_id'   => $driverRole->id,
            'name'      => 'Dana Driver',
            'phone'     => '07705554433',
            'is_active' => true,
        ]);
    }

    public function test_admin_can_view_driver_collections_and_summaries()
    {
        $response = $this->actingAs($this->admin)
            ->getJson('/api/v1/driver-collections/summary');

        $response->assertStatus(200);
        $response->assertJsonStructure([
            'message',
            'data' => [
                '*' => [
                    'driver',
                    'total_collected',
                    'total_paid',
                    'remaining_amount',
                ]
            ]
        ]);
    }

    public function test_admin_can_store_driver_collection()
    {
        $payload = [
            'driver_id' => $this->driver->id,
            'amount' => 500000,
            'collected_at' => now()->toDateString(),
            'notes' => 'Received cash for today trips',
        ];

        $response = $this->actingAs($this->admin)
            ->postJson('/api/v1/driver-collections', $payload);

        $response->assertStatus(201);
        $this->assertDatabaseHas('driver_collections', [
            'driver_id' => $this->driver->id,
            'amount' => 500000,
        ]);
    }

    public function test_driver_cannot_store_driver_collection()
    {
        $payload = [
            'driver_id' => $this->driver->id,
            'amount' => 500000,
            'collected_at' => now()->toDateString(),
        ];

        $response = $this->actingAs($this->driver)
            ->postJson('/api/v1/driver-collections', $payload);

        $response->assertStatus(403);
    }
}
