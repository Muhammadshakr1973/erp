<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        $driver = DB::getDriverName();

        if (in_array($driver, ['mysql', 'mariadb'])) {
            DB::statement("ALTER TABLE `delivery_trips` MODIFY COLUMN `status` ENUM('DRAFT', 'PLANNED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED') NOT NULL DEFAULT 'DRAFT'");
        } else {
            Schema::table('delivery_trips', function (Blueprint $table) {
                $table->enum('status', [
                    'DRAFT', 'PLANNED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'
                ])->default('DRAFT')->change();
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        // Convert any PLANNED statuses to DRAFT before narrowing enum to prevent truncation
        DB::table('delivery_trips')
            ->where('status', 'PLANNED')
            ->update(['status' => 'DRAFT']);

        $driver = DB::getDriverName();

        if (in_array($driver, ['mysql', 'mariadb'])) {
            DB::statement("ALTER TABLE `delivery_trips` MODIFY COLUMN `status` ENUM('DRAFT', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED') NOT NULL DEFAULT 'DRAFT'");
        } else {
            Schema::table('delivery_trips', function (Blueprint $table) {
                $table->enum('status', [
                    'DRAFT', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'
                ])->default('DRAFT')->change();
            });
        }
    }
};
