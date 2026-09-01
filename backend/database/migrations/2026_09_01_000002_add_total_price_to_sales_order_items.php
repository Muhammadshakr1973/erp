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
        Schema::table('sales_order_items', function (Blueprint $table) {
            if (!Schema::hasColumn('sales_order_items', 'total_price')) {
                $table->unsignedBigInteger('total_price')->default(0)->after('line_total');
            }
        });

        if (Schema::hasColumn('sales_order_items', 'total_price') && Schema::hasColumn('sales_order_items', 'line_total')) {
            DB::table('sales_order_items')
                ->where('total_price', 0)
                ->update(['total_price' => DB::raw('line_total')]);
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('sales_order_items', function (Blueprint $table) {
            if (Schema::hasColumn('sales_order_items', 'total_price')) {
                $table->dropColumn('total_price');
            }
        });
    }
};
