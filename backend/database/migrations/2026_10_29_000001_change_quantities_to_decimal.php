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
        // 1. purchase_order_items
        Schema::table('purchase_order_items', function (Blueprint $table) {
            $table->decimal('quantity', 12, 3)->change();
            $table->decimal('received_quantity', 12, 3)->default(0)->change();
        });

        // 2. sales_order_items
        Schema::table('sales_order_items', function (Blueprint $table) {
            $table->decimal('quantity', 12, 3)->change();
        });

        // 3. sales_return_items
        Schema::table('sales_return_items', function (Blueprint $table) {
            $table->decimal('quantity', 12, 3)->change();
        });

        // 4. warehouse_stock
        Schema::table('warehouse_stock', function (Blueprint $table) {
            $table->decimal('quantity', 12, 3)->default(0)->change();
            $table->decimal('reserved_quantity', 12, 3)->default(0)->change();
        });

        // 5. stock_transactions
        Schema::table('stock_transactions', function (Blueprint $table) {
            $table->decimal('quantity_change', 12, 3)->change();
            $table->decimal('quantity_after', 12, 3)->nullable()->change();
        });

        // 6. stock_transfer_items
        if (Schema::hasTable('stock_transfer_items')) {
            Schema::table('stock_transfer_items', function (Blueprint $table) {
                $table->decimal('quantity', 12, 3)->change();
                $table->decimal('quantity_received', 12, 3)->default(0)->change();
            });
        }

        // 7. purchase_requirements
        if (Schema::hasTable('purchase_requirements')) {
            Schema::table('purchase_requirements', function (Blueprint $table) {
                $table->decimal('required_quantity', 12, 3)->change();
                $table->decimal('suggested_quantity', 12, 3)->nullable()->change();
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('purchase_order_items', function (Blueprint $table) {
            $table->unsignedInteger('quantity')->change();
            $table->unsignedInteger('received_quantity')->default(0)->change();
        });

        Schema::table('sales_order_items', function (Blueprint $table) {
            $table->unsignedInteger('quantity')->change();
        });

        Schema::table('sales_return_items', function (Blueprint $table) {
            $table->unsignedInteger('quantity')->change();
        });

        Schema::table('warehouse_stock', function (Blueprint $table) {
            $table->unsignedInteger('quantity')->default(0)->change();
            $table->unsignedInteger('reserved_quantity')->default(0)->change();
        });

        Schema::table('stock_transactions', function (Blueprint $table) {
            $table->integer('quantity_change')->change();
            $table->bigInteger('quantity_after')->nullable()->change();
        });
    }
};

