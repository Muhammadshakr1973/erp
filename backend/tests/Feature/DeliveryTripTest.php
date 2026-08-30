<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Role;
use App\Models\Route;
use App\Models\DeliveryTrip;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DeliveryTripTest extends TestCase
{
    use RefreshDatabase;

    protected $driver;

    protected function setUp(): void
    {
        parent::setUp();
        $role = Role::firstOrCreate(['name' => 'driver']);
        $this->driver = User::factory()->create(['role_id' => $role->id, 'is_active' => true]);
    }

    /** @test */
    public function it_can_create_and_manage_a_delivery_trip()
    {
        $adminRole = Role::firstOrCreate(['name' => 'admin']);
        $admin = User::factory()->create(['role_id' => $adminRole->id, 'is_active' => true]);
        $route = Route::create(['name' => 'Route A']);

        $payload = [
            'driver_id' => $this->driver->id,
            'route_id' => $route->id,
            'trip_date' => now()->toDateString()
        ];

        $response = $this->actingAs($admin)->postJson('/api/v1/delivery-trips', $payload);
        $response->assertStatus(201);
    }
}
