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
            if (!Schema::hasColumn('users', 'warehouse_id')) {
                $table->foreignId('warehouse_id')
                    ->nullable()
                    ->after('role_id')
                    ->constrained('warehouses')
                    ->nullOnDelete();
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            if (Schema::hasColumn('users', 'warehouse_id')) {
                $table->dropForeign(['warehouse_id']);
                $table->dropColumn('warehouse_id');
            }
        });
    }
};
