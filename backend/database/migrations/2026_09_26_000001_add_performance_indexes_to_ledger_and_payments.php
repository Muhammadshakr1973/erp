<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Add indexes to customer_ledger for fast report filtering & joins
        Schema::table('customer_ledger', function (Blueprint $table) {
            $table->index('entry_type');
            $table->index('created_at');
            $table->index(['reference_type', 'reference_id']);
        });

        // 2. Add indexes to supplier_ledger for fast report filtering & joins
        Schema::table('supplier_ledger', function (Blueprint $table) {
            $table->index('entry_type');
            $table->index('created_at');
            $table->index(['reference_type', 'reference_id']);
        });

        // 3. Add indexes to stock_transactions for fast stock movements reports
        Schema::table('stock_transactions', function (Blueprint $table) {
            $table->index('type');
            $table->index('created_at');
            $table->index(['reference_type', 'reference_id']);
        });

        // 4. Add indexes to customer_payments for fast payments history reports
        Schema::table('customer_payments', function (Blueprint $table) {
            $table->index('paid_at');
            $table->index('payment_method');
        });

        // 5. Add indexes to supplier_payments for fast supplier payment history reports
        Schema::table('supplier_payments', function (Blueprint $table) {
            $table->index('paid_at');
        });
    }

    public function down(): void
    {
        Schema::table('customer_ledger', function (Blueprint $table) {
            $table->dropIndex(['entry_type']);
            $table->dropIndex(['created_at']);
            $table->dropIndex(['reference_type', 'reference_id']);
        });

        Schema::table('supplier_ledger', function (Blueprint $table) {
            $table->dropIndex(['entry_type']);
            $table->dropIndex(['created_at']);
            $table->dropIndex(['reference_type', 'reference_id']);
        });

        Schema::table('stock_transactions', function (Blueprint $table) {
            $table->dropIndex(['type']);
            $table->dropIndex(['created_at']);
            $table->dropIndex(['reference_type', 'reference_id']);
        });

        Schema::table('customer_payments', function (Blueprint $table) {
            $table->dropIndex(['paid_at']);
            $table->dropIndex(['payment_method']);
        });

        Schema::table('supplier_payments', function (Blueprint $table) {
            $table->dropIndex(['paid_at']);
        });
    }
};
