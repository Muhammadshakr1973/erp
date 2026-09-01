<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Role;
use App\Models\Product;
use App\Models\Category;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ProductTest extends TestCase
{
    use RefreshDatabase;

    protected $admin;

    protected function setUp(): void
    {
        parent::setUp();
        $role = Role::firstOrCreate(['name' => 'admin'], ['display_name' => 'Admin']);
        $this->admin = User::factory()->create(['role_id' => $role->id, 'is_active' => true]);
    }

    /** @test */
    public function it_can_create_a_product()
    {
        $category = Category::create(['name' => 'Test Category']);

        $payload = [
            'name' => 'Test Product',
            'sku' => 'TP-001',
            'category_id' => $category->id,
            'cost_price' => 1000,
            'price_n1' => 1500,
            'price_n2' => 1400,
            'price_n3' => 1300,
        ];

        $response = $this->actingAs($this->admin)->postJson('/api/v1/products', $payload);

        $response->assertStatus(201);
        $this->assertDatabaseHas('products', ['sku' => 'TP-001']);
    }
}
