<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table) {
            if (!Schema::hasColumn('products', 'parent_id')) {
                $table->unsignedBigInteger('parent_id')->nullable()->after('id');
            }
            if (!Schema::hasColumn('products', 'is_parent')) {
                $table->boolean('is_parent')->default(false)->after('parent_id');
            }
            if (!Schema::hasColumn('products', 'variant_name')) {
                $table->string('variant_name', 100)->nullable()->after('name');
            }
            if (!Schema::hasColumn('products', 'use_parent_price')) {
                $table->boolean('use_parent_price')->default(true)->after('price_n3');
            }

            $table->index('parent_id', 'products_parent_id_index');
            $table->index('is_parent', 'products_is_parent_index');
            $table->foreign('parent_id', 'products_parent_id_foreign')
                ->references('id')
                ->on('products')
                ->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('products', function (Blueprint $table) {
            $table->dropForeign('products_parent_id_foreign');
            $table->dropIndex('products_parent_id_index');
            $table->dropIndex('products_is_parent_index');
            $table->dropColumn(['parent_id', 'is_parent', 'variant_name', 'use_parent_price']);
        });
    }
};
