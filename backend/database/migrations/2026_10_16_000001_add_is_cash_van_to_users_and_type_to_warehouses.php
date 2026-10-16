<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            if (!Schema::hasColumn('users', 'is_cash_van')) {
                $table->boolean('is_cash_van')->default(false)->after('warehouse_id');
            }
        });

        Schema::table('warehouses', function (Blueprint $table) {
            if (!Schema::hasColumn('warehouses', 'type')) {
                $table->string('type', 20)->default('PHYSICAL')->after('name');
            }
            if (!Schema::hasColumn('warehouses', 'phone')) {
                $table->string('phone', 20)->nullable()->after('address');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            if (Schema::hasColumn('users', 'is_cash_van')) {
                $table->dropColumn('is_cash_van');
            }
        });

        Schema::table('warehouses', function (Blueprint $table) {
            if (Schema::hasColumn('warehouses', 'type')) {
                $table->dropColumn('type');
            }
            if (Schema::hasColumn('warehouses', 'phone')) {
                $table->dropColumn('phone');
            }
        });
    }
};
