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
        Schema::table('idempotency_keys', function (Blueprint $table) {
            if (!Schema::hasColumn('idempotency_keys', 'user_id')) {
                $table->unsignedBigInteger('user_id')->nullable()->after('idempotency_key');
                $table->foreign('user_id')->references('id')->on('users')->onDelete('cascade');
            }
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('idempotency_keys', function (Blueprint $table) {
            if (Schema::hasColumn('idempotency_keys', 'user_id')) {
                $table->dropForeign(['user_id']);
                $table->dropColumn('user_id');
            }
        });
    }
};
