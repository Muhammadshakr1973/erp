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
        Schema::table('customer_ledger', function (Blueprint $table) {
            if (!Schema::hasColumn('customer_ledger', 'balance_before')) {
                $table->bigInteger('balance_before')->default(0)->after('amount');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('customer_ledger', function (Blueprint $table) {
            if (Schema::hasColumn('customer_ledger', 'balance_before')) {
                $table->dropColumn('balance_before');
            }
        });
    }
};
