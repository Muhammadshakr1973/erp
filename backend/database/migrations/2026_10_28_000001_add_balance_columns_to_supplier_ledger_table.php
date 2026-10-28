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
        Schema::table('supplier_ledger', function (Blueprint $table) {
            if (!Schema::hasColumn('supplier_ledger', 'balance_before')) {
                $table->bigInteger('balance_before')->default(0)->after('amount');
            }
            if (!Schema::hasColumn('supplier_ledger', 'balance_after')) {
                $table->bigInteger('balance_after')->default(0)->after('balance_before');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('supplier_ledger', function (Blueprint $table) {
            if (Schema::hasColumn('supplier_ledger', 'balance_before')) {
                $table->dropColumn('balance_before');
            }
            if (Schema::hasColumn('supplier_ledger', 'balance_after')) {
                $table->dropColumn('balance_after');
            }
        });
    }
};
