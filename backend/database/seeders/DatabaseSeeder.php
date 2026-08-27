<?php
namespace Database\Seeders;

use App\Models\Role;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        // 1. Roles first - پێویستە بۆ User role_id
        $this->call(RoleSeeder::class);

        // 2. Owner user - بۆ test
        $ownerRole = Role::where('name', 'owner')->first();
        
        User::firstOrCreate(
            ['phone' => '07500000001'],
            [
                'name' => 'Owner',
                'password' => Hash::make('password'),
                'role_id' => $ownerRole?->id,
                'commission_rate' => 0,
                'is_active' => true,
            ]
        );

        // 3. Admin user
        $adminRole = Role::where('name', 'admin')->first();
        User::firstOrCreate(
            ['phone' => '07500000002'],
            [
                'name' => 'Admin',
                'password' => Hash::make('password'),
                'role_id' => $adminRole?->id,
                'is_active' => true,
            ]
        );

        // 4. Test User - ئەوەی هەڵەی دەدا - ئێستا phone و role_id هەیە
        $salesmanRole = Role::where('name', 'salesman')->first();
        User::firstOrCreate(
            ['phone' => '07500000003'],
            [
                'name' => 'Test User',
                'password' => Hash::make('password'),
                'role_id' => $salesmanRole?->id,
                'commission_rate' => 10,
                'barcode' => 'SM-0001',
                'is_active' => true,
            ]
        );

        // ئەگەر دەتەوێت Factory بەکاربهێنیت:
        // User::factory(5)->salesman()->create();
    }
}
