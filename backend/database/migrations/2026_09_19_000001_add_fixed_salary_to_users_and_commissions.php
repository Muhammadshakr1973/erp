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
            if (!Schema::hasColumn('users', 'fixed_salary')) {
                $table->unsignedBigInteger('fixed_salary')->default(0)->after('commission_rate');
            }
        });

        Schema::table('salesman_commissions', function (Blueprint $table) {
            if (!Schema::hasColumn('salesman_commissions', 'fixed_amount')) {
                $table->unsignedBigInteger('fixed_amount')->default(0)->after('commission_rate');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            if (Schema::hasColumn('users', 'fixed_salary')) {
                $table->dropColumn('fixed_salary');
            }
        });

        Schema::table('salesman_commissions', function (Blueprint $table) {
            if (Schema::hasColumn('salesman_commissions', 'fixed_amount')) {
                $table->dropColumn('fixed_amount');
            }
        });
    }
};
