<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasColumn('purchase_orders', 'paid_amount')) {
            Schema::table('purchase_orders', function (Blueprint $table) {
                $table->unsignedBigInteger('paid_amount')->default(0)->after('total_amount');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('purchase_orders', 'paid_amount')) {
            Schema::table('purchase_orders', function (Blueprint $table) {
                $table->dropColumn('paid_amount');
            });
        }
    }
};
