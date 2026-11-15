<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customers', function (Blueprint $table) {
            if (!Schema::hasColumn('customers', 'can_login')) {
                $table->boolean('can_login')->default(false)->after('is_active');
            }
            if (!Schema::hasColumn('customers', 'login_code')) {
                $table->string('login_code', 4)->nullable()->index()->after('can_login');
            }
            if (!Schema::hasColumn('customers', 'allowed_category_ids')) {
                $table->json('allowed_category_ids')->nullable()->after('login_code');
            }
            if (!Schema::hasColumn('customers', 'user_id')) {
                $table->foreignId('user_id')->nullable()->after('allowed_category_ids')->constrained('users')->nullOnDelete();
            }
        });

        DB::table('roles')->insertOrIgnore([
            'name' => 'customer',
            'display_name' => 'Customer',
            'permissions' => json_encode([
                'orders.create',
                'orders.view',
                'products.view',
                'customers.view',
            ]),
            'is_system' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function down(): void
    {
        Schema::table('customers', function (Blueprint $table) {
            if (Schema::hasColumn('customers', 'user_id')) {
                $table->dropForeign(['user_id']);
                $table->dropColumn('user_id');
            }
            if (Schema::hasColumn('customers', 'allowed_category_ids')) {
                $table->dropColumn('allowed_category_ids');
            }
            if (Schema::hasColumn('customers', 'login_code')) {
                $table->dropIndex(['login_code']);
                $table->dropColumn('login_code');
            }
            if (Schema::hasColumn('customers', 'can_login')) {
                $table->dropColumn('can_login');
            }
        });
    }
};
