<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('route_salesmen', function (Blueprint $table) {
            // Make work_date nullable to allow recurring day-of-week routes
            $table->date('work_date')->nullable()->change();
            
            // Add day_of_week string column (Saturday, Sunday, Monday, etc.)
            $table->string('day_of_week', 15)->nullable()->after('work_date');
            
            // Add unique constraint so a salesman only has one route assigned per day of the week
            $table->unique(['salesman_id', 'day_of_week'], 'salesman_day_unique');
        });
    }

    public function down(): void
    {
        Schema::table('route_salesmen', function (Blueprint $table) {
            $table->dropUnique('salesman_day_unique');
            $table->dropColumn('day_of_week');
            $table->date('work_date')->nullable(false)->change();
        });
    }
};
