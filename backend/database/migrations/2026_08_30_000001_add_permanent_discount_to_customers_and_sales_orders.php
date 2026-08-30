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
        Schema::table('customers', function (Blueprint $table) {
            if (!Schema::hasColumn('customers', 'permanent_discount')) {
                $table->decimal('permanent_discount', 5, 2)->default(0)->after('price_type');
            }
        });

        Schema::table('sales_orders', function (Blueprint $table) {
            if (!Schema::hasColumn('sales_orders', 'permanent_discount_percent')) {
                $table->decimal('permanent_discount_percent', 5, 2)->default(0)->nullable()->after('subtotal');
            }
            if (!Schema::hasColumn('sales_orders', 'permanent_discount_amount')) {
                $table->unsignedBigInteger('permanent_discount_amount')->default(0)->after('permanent_discount_percent');
            }
            if (!Schema::hasColumn('sales_orders', 'discount_type')) {
                $table->string('discount_type', 10)->default('PERCENT')->nullable()->after('discount_percent');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('customers', function (Blueprint $table) {
            if (Schema::hasColumn('customers', 'permanent_discount')) {
                $table->dropColumn('permanent_discount');
            }
        });

        Schema::table('sales_orders', function (Blueprint $table) {
            $columnsToDrop = [];
            if (Schema::hasColumn('sales_orders', 'permanent_discount_percent')) {
                $columnsToDrop[] = 'permanent_discount_percent';
            }
            if (Schema::hasColumn('sales_orders', 'permanent_discount_amount')) {
                $columnsToDrop[] = 'permanent_discount_amount';
            }
            if (Schema::hasColumn('sales_orders', 'discount_type')) {
                $columnsToDrop[] = 'discount_type';
            }
            if (!empty($columnsToDrop)) {
                $table->dropColumn($columnsToDrop);
            }
        });
    }
};
