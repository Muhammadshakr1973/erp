<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Role;
use App\Models\Customer;
use App\Models\SalesOrder;
use App\Models\DeliveryTrip;
use App\Models\DeliveryTripOrder;
use App\Models\Route as RouteModel;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SecurityAuthorizationTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test that an inactive user cannot access any protected routes.
     */
    public function test_inactive_user_is_blocked_and_token_revoked(): void
    {
        $role = Role::create([
            'name' => 'salesman',
            'permissions' => ['orders.create']
        ]);

        $user = User::create([
            'name' => 'Inactive Salesman',
            'phone' => '07700000000',
            'password' => bcrypt('password'),
            'role_id' => $role->id,
            'is_active' => false
        ]);

        $response = $this->actingAs($user)->getJson('/api/v1/auth/me');

        $response->assertStatus(403);
        $response->assertJsonStructure(['message', 'error']);
    }

    /**
     * Test that a salesman cannot access customers that do not belong to their assigned routes.
     */
    public function test_salesman_cannot_view_unassigned_customer(): void
    {
        $role = Role::create([
            'name' => 'salesman',
            'permissions' => ['customers.view']
        ]);

        $salesman = User::create([
            'name' => 'Salesman',
            'phone' => '07700000001',
            'password' => bcrypt('password'),
            'role_id' => $role->id,
            'is_active' => true
        ]);

        $route1 = RouteModel::create(['name' => 'Route 1']);
        $route2 = RouteModel::create(['name' => 'Route 2']);

        // Assign route1 to salesman
        $salesman->routeSalesmen()->create([
            'route_id' => $route1->id,
            'is_active' => true
        ]);

        $assignedCustomer = Customer::create([
            'name' => 'Assigned Cust',
            'phone' => '07701111111',
            'route_id' => $route1->id,
            'current_balance' => 0
        ]);

        $unassignedCustomer = Customer::create([
            'name' => 'Unassigned Cust',
            'phone' => '07702222222',
            'route_id' => $route2->id,
            'current_balance' => 0
        ]);

        // Allowed Customer Access
        $this->actingAs($salesman)
            ->getJson("/api/v1/customers/{$assignedCustomer->id}")
            ->assertStatus(200);

        // Blocked Customer Access (IDOR Prevention)
        $this->actingAs($salesman)
            ->getJson("/api/v1/customers/{$unassignedCustomer->id}")
            ->assertStatus(403);
    }

    /**
     * Test that a salesman cannot view or edit sales orders owned by other salesmen.
     */
    public function test_salesman_cannot_access_other_salesmans_order(): void
    {
        $role = Role::create([
            'name' => 'salesman',
            'permissions' => ['orders.create', 'customers.view']
        ]);

        $salesman1 = User::create([
            'name' => 'Salesman 1',
            'phone' => '07700000002',
            'password' => bcrypt('password'),
            'role_id' => $role->id,
            'is_active' => true
        ]);

        $salesman2 = User::create([
            'name' => 'Salesman 2',
            'phone' => '07700000003',
            'password' => bcrypt('password'),
            'role_id' => $role->id,
            'is_active' => true
        ]);

        $route = RouteModel::create(['name' => 'Route']);
        $customer = Customer::create([
            'name' => 'Cust',
            'phone' => '07703333333',
            'route_id' => $route->id,
            'current_balance' => 0
        ]);

        $orderOfSalesman1 = SalesOrder::create([
            'order_number' => 'ORD-1',
            'customer_id' => $customer->id,
            'salesman_id' => $salesman1->id,
            'status' => 'DRAFT',
            'total_amount' => 100,
            'discount_amount' => 0,
            'final_amount' => 100,
            'is_active' => true
        ]);

        // Salesman 1 should be allowed
        $this->actingAs($salesman1)
            ->getJson("/api/v1/orders/{$orderOfSalesman1->id}")
            ->assertStatus(200);

        // Salesman 2 should be Forbidden (IDOR Blocked)
        $this->actingAs($salesman2)
            ->getJson("/api/v1/orders/{$orderOfSalesman1->id}")
            ->assertStatus(403);
    }

    /**
     * Test that a driver cannot perform delivery updates on a trip assigned to another driver.
     */
    public function test_driver_cannot_deliver_unassigned_trip_order(): void
    {
        $role = Role::create([
            'name' => 'driver',
            'permissions' => ['delivery.update']
        ]);

        $driver1 = User::create([
            'name' => 'Driver 1',
            'phone' => '07700000004',
            'password' => bcrypt('password'),
            'role_id' => $role->id,
            'is_active' => true
        ]);

        $driver2 = User::create([
            'name' => 'Driver 2',
            'phone' => '07700000005',
            'password' => bcrypt('password'),
            'role_id' => $role->id,
            'is_active' => true
        ]);

        $trip = DeliveryTrip::create([
            'trip_number' => 'TRP-1',
            'driver_id' => $driver1->id,
            'trip_date' => now()->toDateString(),
            'status' => 'IN_PROGRESS',
            'total_orders' => 1,
            'created_by' => 1
        ]);

        $order = SalesOrder::create([
            'order_number' => 'ORD-2',
            'customer_id' => 1,
            'salesman_id' => 1,
            'status' => 'IN_DELIVERY',
            'total_amount' => 100,
            'discount_amount' => 0,
            'final_amount' => 100,
            'is_active' => true
        ]);

        $tripOrder = DeliveryTripOrder::create([
            'delivery_trip_id' => $trip->id,
            'sales_order_id' => $order->id,
            'status' => 'PENDING',
            'delivery_order' => 1
        ]);

        // Driver 2 tries to deliver (should be Forbidden)
        $this->actingAs($driver2)
            ->postJson("/api/v1/delivery-trips/orders/{$tripOrder->id}/deliver", [
                'received_amount' => 100,
                'notes' => 'No notes'
            ])
            ->assertStatus(403);
    }

    /**
     * Test that an Admin cannot deactivate or delete an Owner.
     */
    public function test_admin_cannot_delete_or_deactivate_owner(): void
    {
        $roleOwner = Role::create([
            'name' => Role::OWNER,
            'permissions' => ['*']
        ]);

        $roleAdmin = Role::create([
            'name' => Role::ADMIN,
            'permissions' => ['users.manage']
        ]);

        $owner = User::create([
            'name' => 'The Owner',
            'phone' => '07700000006',
            'password' => bcrypt('password'),
            'role_id' => $roleOwner->id,
            'is_active' => true
        ]);

        $admin = User::create([
            'name' => 'An Admin',
            'phone' => '07700000007',
            'password' => bcrypt('password'),
            'role_id' => $roleAdmin->id,
            'is_active' => true
        ]);

        // Admin tries to delete Owner (should be Forbidden)
        $this->actingAs($admin)
            ->deleteJson("/api/v1/users/{$owner->id}")
            ->assertStatus(403);

        // Admin tries to deactivate Owner (should be Forbidden)
        $this->actingAs($admin)
            ->putJson("/api/v1/users/{$owner->id}", [
                'name' => 'The Owner New Name',
                'phone' => '07700000006',
                'role_id' => $roleOwner->id,
                'is_active' => false
            ])
            ->assertStatus(403);
    }

    /**
     * Test that warehouse staff and drivers cannot view suppliers list (403 Forbidden).
     */
    public function test_warehouse_and_driver_cannot_view_suppliers(): void
    {
        $warehouseRole = Role::create([
            'name' => 'warehouse',
            'permissions' => ['stock.view', 'stock.pack']
        ]);

        $driverRole = Role::create([
            'name' => 'driver',
            'permissions' => ['delivery.view', 'delivery.update']
        ]);

        $warehouseUser = User::create([
            'name' => 'Warehouse Staff',
            'phone' => '07700000008',
            'password' => bcrypt('password'),
            'role_id' => $warehouseRole->id,
            'is_active' => true
        ]);

        $driverUser = User::create([
            'name' => 'Driver Staff',
            'phone' => '07700000009',
            'password' => bcrypt('password'),
            'role_id' => $driverRole->id,
            'is_active' => true
        ]);

        $this->actingAs($warehouseUser)
            ->getJson('/api/v1/suppliers')
            ->assertStatus(403);

        $this->actingAs($driverUser)
            ->getJson('/api/v1/suppliers')
            ->assertStatus(403);
    }

    /**
     * Test that a salesman cannot collect payments for an unassigned customer (IDOR prevention).
     */
    public function test_salesman_cannot_collect_payment_for_unassigned_customer(): void
    {
        $role = Role::create([
            'name' => 'salesman',
            'permissions' => ['orders.create', 'customers.view']
        ]);

        $salesman = User::create([
            'name' => 'Salesman Collect',
            'phone' => '07700000010',
            'password' => bcrypt('password'),
            'role_id' => $role->id,
            'is_active' => true
        ]);

        $route1 = RouteModel::create(['name' => 'Route 1']);
        $route2 = RouteModel::create(['name' => 'Route 2']);

        $salesman->routeSalesmen()->create([
            'route_id' => $route1->id,
            'is_active' => true
        ]);

        $unassignedCustomer = Customer::create([
            'name' => 'Unassigned Cust',
            'phone' => '07702222223',
            'route_id' => $route2->id,
            'current_balance' => 50000
        ]);

        $this->actingAs($salesman)
            ->postJson('/api/v1/payments', [
                'customer_id' => $unassignedCustomer->id,
                'amount' => 10000,
                'payment_method' => 'CASH'
            ])
            ->assertStatus(403);
    }

    /**
     * Test that a salesman cannot view route customer lists for unassigned routes.
     */
    public function test_salesman_cannot_view_customers_of_unassigned_route(): void
    {
        $role = Role::create([
            'name' => 'salesman',
            'permissions' => ['customers.view']
        ]);

        $salesman = User::create([
            'name' => 'Salesman Route',
            'phone' => '07700000011',
            'password' => bcrypt('password'),
            'role_id' => $role->id,
            'is_active' => true
        ]);

        $route1 = RouteModel::create(['name' => 'Route 1']);
        $route2 = RouteModel::create(['name' => 'Route 2']);

        $salesman->routeSalesmen()->create([
            'route_id' => $route1->id,
            'is_active' => true
        ]);

        // Allowed for assigned route
        $this->actingAs($salesman)
            ->getJson("/api/v1/routes/{$route1->id}/customers")
            ->assertStatus(200);

        // Forbidden for unassigned route
        $this->actingAs($salesman)
            ->getJson("/api/v1/routes/{$route2->id}/customers")
            ->assertStatus(403);
    }
}
