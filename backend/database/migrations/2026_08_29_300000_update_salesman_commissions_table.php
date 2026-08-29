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
        Schema::table('salesman_commissions', function (Blueprint $table) {
            $table->foreignId('approved_by')->nullable()->after('calculated_by')->constrained('users')->nullOnDelete();
            $table->timestamp('approved_at')->nullable()->after('paid_at');
            $table->string('payment_method', 50)->nullable()->after('approved_at');
            $table->text('notes')->nullable()->after('payment_method');
            $table->foreignId('cancelled_by')->nullable()->after('paid_by')->constrained('users')->nullOnDelete();
            $table->timestamp('cancelled_at')->nullable()->after('cancelled_by');
            $table->text('cancellation_reason')->nullable()->after('cancelled_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('salesman_commissions', function (Blueprint $table) {
            $table->dropForeign(['approved_by']);
            $table->dropForeign(['cancelled_by']);
            $table->dropColumn([
                'approved_by',
                'approved_at',
                'payment_method',
                'notes',
                'cancelled_by',
                'cancelled_at',
                'cancellation_reason',
            ]);
        });
    }
};
