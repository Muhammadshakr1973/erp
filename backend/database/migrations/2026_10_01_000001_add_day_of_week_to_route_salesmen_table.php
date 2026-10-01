<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Add routing_cycle to users table
        Schema::table('users', function (Blueprint $table) {
            if (!Schema::hasColumn('users', 'routing_cycle')) {
                $table->string('routing_cycle', 15)->default('1_week')->after('is_active');
            }
        });

        // Modify route_salesmen table
        Schema::table('route_salesmen', function (Blueprint $table) {
            // Make work_date nullable to allow recurring day-of-week routes
            $table->date('work_date')->nullable()->change();
            
            // Add day_of_week column
            if (!Schema::hasColumn('route_salesmen', 'day_of_week')) {
                $table->string('day_of_week', 15)->nullable()->after('work_date');
            }
            
            // Add week_number column
            if (!Schema::hasColumn('route_salesmen', 'week_number')) {
                $table->unsignedTinyInteger('week_number')->default(1)->after('day_of_week');
            }

            // Drop any old salesman_day_unique index if exists
            try {
                $table->dropUnique('salesman_day_unique');
            } catch (\Exception $e) {}

            // Add the multi-week unique constraint
            $table->unique(['salesman_id', 'day_of_week', 'week_number'], 'salesman_day_week_unique');
        });
    }

    public function down(): void
    {
        Schema::table('route_salesmen', function (Blueprint $table) {
            $table->dropUnique('salesman_day_week_unique');
            $table->dropColumn(['day_of_week', 'week_number']);
            $table->date('work_date')->nullable(false)->change();
        });

        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('routing_cycle');
        });
    }
};
