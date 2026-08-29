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
        Schema::create('whatsapp_notification_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('customer_id')->nullable()->constrained('customers')->nullOnDelete();
            $table->foreignId('supplier_id')->nullable()->constrained('suppliers')->nullOnDelete();
            $table->string('recipient_phone', 30);
            $table->string('recipient_name', 150)->nullable();
            $table->string('notification_type', 50); // PAYMENT_RECEIVED, DELIVERY_DEBT, PURCHASE_DEBT, ORDER_COMPLETED, etc.
            $table->string('reference_type', 50)->nullable(); // customer_payment, sales_order, supplier_payment, etc.
            $table->unsignedBigInteger('reference_id')->nullable();
            $table->string('idempotency_key', 100)->nullable()->index();
            $table->text('message');
            $table->string('status', 30)->default('PENDING'); // PENDING, SENT, FAILED, SIMULATED
            $table->string('provider', 50)->nullable(); // meta_cloud, twilio, infobip, ultramsg, unconfigured
            $table->string('provider_message_id', 150)->nullable();
            $table->text('error_message')->nullable();
            $table->json('payload')->nullable();
            $table->json('response')->nullable();
            $table->unsignedInteger('retry_count')->default(0);
            $table->timestamp('last_attempt_at')->nullable();
            $table->timestamp('sent_at')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->index(['reference_type', 'reference_id']);
            $table->index('status');
            $table->index('created_at');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('whatsapp_notification_logs');
    }
};
