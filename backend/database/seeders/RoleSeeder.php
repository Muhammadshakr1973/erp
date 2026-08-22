<?php
namespace Database\Seeders;

use App\Models\Role;
use Illuminate\Database\Seeder;

class RoleSeeder extends Seeder
{
    public function run(): void
    {
        $roles = [
            ['name' => 'owner', 'display_name' => 'Owner', 'description' => 'Full access', 'is_system' => true, 'permissions' => json_encode(['*'])],
            ['name' => 'admin', 'display_name' => 'Admin', 'description' => 'Admin access', 'is_system' => true, 'permissions' => json_encode(['*'])],
            ['name' => 'salesman', 'display_name' => 'Salesman', 'description' => 'Salesman - POS', 'is_system' => true, 'permissions' => json_encode(['orders.create', 'customers.view'])],
            ['name' => 'warehouse', 'display_name' => 'Warehouse', 'description' => 'Warehouse staff', 'is_system' => true, 'permissions' => json_encode(['stock.view', 'stock.pack'])],
            ['name' => 'driver', 'display_name' => 'Driver', 'description' => 'Driver - Delivery', 'is_system' => true, 'permissions' => json_encode(['delivery.view', 'delivery.update'])],
        ];

        foreach ($roles as $role) {
            Role::firstOrCreate(['name' => $role['name']], $role);
        }
    }
}
