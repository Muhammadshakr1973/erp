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
        Schema::table('sales_orders', function (Blueprint $table) {
            if (!Schema::hasColumn('sales_orders', 'shared_key')) {
                $table->string('shared_key', 100)->nullable()->unique()->after('order_number');
            }
            if (!Schema::hasColumn('sales_orders', 'version')) {
                $table->unsignedInteger('version')->default(1)->after('shared_key');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('sales_orders', function (Blueprint $table) {
            $columnsToDrop = [];
            if (Schema::hasColumn('sales_orders', 'shared_key')) {
                $columnsToDrop[] = 'shared_key';
            }
            if (Schema::hasColumn('sales_orders', 'version')) {
                $columnsToDrop[] = 'version';
            }
            if (!empty($columnsToDrop)) {
                $table->dropColumn($columnsToDrop);
            }
        });
    }
};
