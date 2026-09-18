<?php
namespace Database\Seeders;

use App\Models\Role;
use Illuminate\Database\Seeder;

class RoleSeeder extends Seeder
{
    public function run(): void
    {
        $roles = [
            ['name' => 'owner', 'display_name' => 'Owner', 'description' => 'Full access', 'is_system' => true, 'permissions' => ['*']],
            ['name' => 'admin', 'display_name' => 'Admin', 'description' => 'Admin access', 'is_system' => true, 'permissions' => ['*']],
            ['name' => 'salesman', 'display_name' => 'Salesman', 'description' => 'Salesman - POS', 'is_system' => true, 'permissions' => ['orders.create', 'orders.view', 'customers.view', 'customers.manage', 'products.view', 'commissions.view', 'suppliers.view']],
            ['name' => 'warehouse', 'display_name' => 'Warehouse', 'description' => 'Warehouse staff', 'is_system' => true, 'permissions' => ['stock.view', 'stock.pack', 'stock.reconcile', 'stock.transfer', 'stock.adjust', 'purchases.receive', 'orders.view']],
            ['name' => 'driver', 'display_name' => 'Driver', 'description' => 'Driver - Delivery', 'is_system' => true, 'permissions' => ['delivery.view', 'delivery.update', 'delivery.confirm', 'orders.view']],
        ];

        foreach ($roles as $role) {
            Role::firstOrCreate(['name' => $role['name']], $role);
        }
    }
}
