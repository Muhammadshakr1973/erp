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
        Schema::create('audit_logs', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('user_id')->nullable()->index();
            $table->string('user_name', 255)->nullable();
            $table->string('user_role', 50)->nullable();
            $table->string('entity_type', 100)->index();
            $table->unsignedBigInteger('entity_id')->nullable()->index();
            $table->string('table_name', 100)->nullable()->index();
            $table->string('action', 50)->index(); // CREATE, UPDATE, DELETE, RESTORE, STATUS_CHANGE, STOCK_ADJUST, PAYMENT, etc.
            $table->json('old_values')->nullable();
            $table->json('new_values')->nullable();
            $table->text('description')->nullable();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->string('device_id', 255)->nullable()->index();
            $table->string('request_url', 500)->nullable();
            $table->string('request_method', 10)->nullable();
            $table->timestamp('created_at')->useCurrent()->index();

            $table->foreign('user_id')->references('id')->on('users')->nullOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('audit_logs');
    }
};
