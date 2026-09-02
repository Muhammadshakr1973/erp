<?php

namespace Tests\Feature;

use App\Models\Customer;
use App\Models\DeliveryTrip;
use App\Models\Product;
use App\Models\Role;
use App\Models\Route;
use App\Models\SalesOrder;
use App\Models\SalesOrderItem;
use App\Models\User;
use App\Models\Warehouse;
use App\Models\WarehouseStock;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DeliveryTripTest extends TestCase
{
    use RefreshDatabase;

    protected User $admin;
    protected User $driver;
    protected User $inactiveDriver;
    protected User $salesman;
    protected User $warehouseStaff;
    protected Customer $customer;
    protected Warehouse $warehouse;
    protected Product $product;

    protected function setUp(): void
    {
        parent::setUp();

        $adminRole = Role::firstOrCreate(['name' => 'admin'], ['display_name' => 'Admin', 'permissions' => ['*']]);
        $driverRole = Role::firstOrCreate(['name' => 'driver'], ['display_name' => 'Driver', 'permissions' => ['delivery.view', 'delivery.update']]);
        $salesmanRole = Role::firstOrCreate(['name' => 'salesman'], ['display_name' => 'Salesman', 'permissions' => ['orders.create', 'customers.view']]);
        $warehouseRole = Role::firstOrCreate(['name' => 'warehouse'], ['display_name' => 'Warehouse', 'permissions' => ['stock.view', 'stock.pack']]);

        $this->admin = User::factory()->create([
            'role_id'   => $adminRole->id,
            'is_active' => true,
        ]);

        $this->driver = User::factory()->create([
            'role_id'   => $driverRole->id,
            'name'      => 'Ahmad Driver',
            'phone'     => '07701112233',
            'is_active' => true,
        ]);

        $this->inactiveDriver = User::factory()->create([
            'role_id'   => $driverRole->id,
            'name'      => 'Inactive Driver',
            'phone'     => '07709998877',
            'is_active' => false,
        ]);

        $this->salesman = User::factory()->create([
            'role_id'   => $salesmanRole->id,
            'name'      => 'Karzan Salesman',
            'phone'     => '07702223344',
            'is_active' => true,
        ]);

        $this->warehouseStaff = User::factory()->create([
            'role_id'   => $warehouseRole->id,
            'name'      => 'Warehouse Worker',
            'is_active' => true,
        ]);

        $route = Route::create(['name' => 'Sulaymaniyah Central', 'is_active' => true]);

        $this->customer = Customer::create([
            'name'            => 'Bakhityar Market',
            'phone'           => '07501234567',
            'route_id'        => $route->id,
            'current_balance' => 0,
            'is_active'       => true,
        ]);

        $this->warehouse = Warehouse::create([
            'name'      => 'Main Depot',
            'code'      => 'DEPOT-1',
            'is_main'   => true,
            'is_active' => true,
        ]);

        $this->product = Product::create([
            'name'            => 'Premium Milk 1L',
            'sku'             => 'MILK-001',
            'cost_price'      => 1000,
            'price_n1'        => 1500,
            'price_n2'        => 1400,
            'price_n3'        => 1300,
            'min_stock_level' => 10,
        ]);

        WarehouseStock::create([
            'warehouse_id'      => $this->warehouse->id,
            'product_id'        => $this->product->id,
            'quantity'          => 100,
            'reserved_quantity' => 10,
        ]);
    }

    protected function createReadyOrder(): SalesOrder
    {
        $order = SalesOrder::create([
            'order_number'    => 'ORD-' . strtoupper(\Illuminate\Support\Str::random(8)),
            'customer_id'     => $this->customer->id,
            'salesman_id'     => $this->salesman->id,
            'warehouse_id'    => $this->warehouse->id,
            'order_date'      => now()->toDateString(),
            'status'          => SalesOrder::STATUS_READY,
            'subtotal'        => 15000,
            'total_amount'    => 15000,
            'total_profit'    => 5000,
            'discount_type'   => 'PERCENT',
            'discount_percent'=> 0,
            'discount_amount' => 0,
            'version'         => 1,
        ]);

        SalesOrderItem::create([
            'sales_order_id'  => $order->id,
            'product_id'      => $this->product->id,
            'quantity'        => 10,
            'unit_price'      => 1500,
            'cost_price'      => 1000,
            'price_type'      => 'N1',
            'discount_percent'=> 0,
            'discount_amount' => 0,
            'line_total'      => 15000,
            'total_price'     => 15000,
            'profit'          => 5000,
            'is_packed'       => true,
        ]);

        return $order;
    }

    /** @test */
    public function it_can_create_a_valid_delivery_trip_and_transitions_orders()
    {
        $readyOrder = $this->createReadyOrder();

        $payload = [
            'driver_id' => $this->driver->id,
            'trip_date' => now()->toDateString(),
            'notes'     => 'First morning dispatch',
            'order_ids' => [$readyOrder->id],
        ];

        $response = $this->actingAs($this->admin)->postJson('/api/v1/delivery-trips', $payload);

        $response->assertStatus(201)
            ->assertJsonPath('data.driver_id', $this->driver->id)
            ->assertJsonPath('data.total_orders', 1)
            ->assertJsonPath('data.driver.id', $this->driver->id);

        $this->assertDatabaseHas('delivery_trips', [
            'driver_id'    => $this->driver->id,
            'total_orders' => 1,
            'status'       => DeliveryTrip::STATUS_PLANNED,
        ]);

        $this->assertDatabaseHas('sales_orders', [
            'id'     => $readyOrder->id,
            'status' => SalesOrder::STATUS_IN_DELIVERY,
        ]);
    }

    /** @test */
    public function it_rejects_missing_or_invalid_order_ids_with_422()
    {
        // 1. Missing order_ids
        $response = $this->actingAs($this->admin)->postJson('/api/v1/delivery-trips', [
            'driver_id' => $this->driver->id,
            'trip_date' => now()->toDateString(),
        ]);
        $response->assertStatus(422)
            ->assertJsonValidationErrors(['order_ids']);

        // 2. Empty order_ids
        $response = $this->actingAs($this->admin)->postJson('/api/v1/delivery-trips', [
            'driver_id' => $this->driver->id,
            'trip_date' => now()->toDateString(),
            'order_ids' => [],
        ]);
        $response->assertStatus(422)
            ->assertJsonValidationErrors(['order_ids']);

        // 3. Non-existent order_id
        $response = $this->actingAs($this->admin)->postJson('/api/v1/delivery-trips', [
            'driver_id' => $this->driver->id,
            'trip_date' => now()->toDateString(),
            'order_ids' => [999999],
        ]);
        $response->assertStatus(422)
            ->assertJsonValidationErrors(['order_ids.0']);
    }

    /** @test */
    public function delivered_or_cancelled_orders_cannot_be_dispatched()
    {
        $deliveredOrder = $this->createReadyOrder();
        $deliveredOrder->update(['status' => SalesOrder::STATUS_DELIVERED]);

        $cancelledOrder = $this->createReadyOrder();
        $cancelledOrder->update(['status' => SalesOrder::STATUS_CANCELLED]);

        // Try dispatching delivered order
        $response = $this->actingAs($this->admin)->postJson('/api/v1/delivery-trips', [
            'driver_id' => $this->driver->id,
            'trip_date' => now()->toDateString(),
            'order_ids' => [$deliveredOrder->id],
        ]);
        $response->assertStatus(422)
            ->assertJsonValidationErrors(['orders']);

        // Try dispatching cancelled order
        $response = $this->actingAs($this->admin)->postJson('/api/v1/delivery-trips', [
            'driver_id' => $this->driver->id,
            'trip_date' => now()->toDateString(),
            'order_ids' => [$cancelledOrder->id],
        ]);
        $response->assertStatus(422)
            ->assertJsonValidationErrors(['orders']);
    }

    /** @test */
    public function driver_list_returns_active_drivers_only()
    {
        $response = $this->actingAs($this->admin)->getJson('/api/v1/delivery-trips/drivers');

        $response->assertStatus(200);

        $data = $response->json('data');
        $this->assertIsArray($data);

        // Contains active driver
        $driverIds = array_column($data, 'id');
        $this->assertContains($this->driver->id, $driverIds);

        // Excludes inactive driver
        $this->assertNotContains($this->inactiveDriver->id, $driverIds);

        // Excludes non-driver roles (salesman, admin)
        $this->assertNotContains($this->salesman->id, $driverIds);
        $this->assertNotContains($this->admin->id, $driverIds);

        // Returned fields strictly check id, name, phone
        $driverEntry = collect($data)->firstWhere('id', $this->driver->id);
        $this->assertEquals('Ahmad Driver', $driverEntry['name']);
        $this->assertEquals('07701112233', $driverEntry['phone']);
        $this->assertArrayNotHasKey('password', $driverEntry);
    }

    /** @test */
    public function unauthorized_roles_cannot_access_driver_list()
    {
        // Salesman lacks delivery.view
        $response = $this->actingAs($this->salesman)->getJson('/api/v1/delivery-trips/drivers');
        $response->assertStatus(403);

        // Warehouse lacks delivery.view
        $response = $this->actingAs($this->warehouseStaff)->getJson('/api/v1/delivery-trips/drivers');
        $response->assertStatus(403);
    }

    /** @test */
    public function duplicate_create_request_with_same_idempotency_key_is_handled_by_middleware()
    {
        $readyOrder = $this->createReadyOrder();

        $payload = [
            'driver_id' => $this->driver->id,
            'trip_date' => now()->toDateString(),
            'order_ids' => [$readyOrder->id],
            'notes'     => 'Idempotent delivery test',
        ];

        $idempotencyKey = 'idemp_trip_test_' . uniqid();

        // First attempt
        $response1 = $this->actingAs($this->admin)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/delivery-trips', $payload);

        $response1->assertStatus(201);
        $tripId1 = $response1->json('data.id');

        // Replay with identical key and payload
        $response2 = $this->actingAs($this->admin)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/delivery-trips', $payload);

        $response2->assertStatus(201)
            ->assertHeader('X-Cache-Lookup', 'HIT');
        $tripId2 = $response2->json('data.id');

        $this->assertEquals($tripId1, $tripId2);

        // Database only contains one trip
        $this->assertEquals(1, DeliveryTrip::where('driver_id', $this->driver->id)->count());
    }
}
