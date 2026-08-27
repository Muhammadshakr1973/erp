<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Full Schema FINAL V6.1 - بۆ migrate:fresh
 * هەموو فێڵدەکان هەیە جگە لە:
 * - delivery_trip_orders.latitude/longitude (EXCLUDED)
 * - customer_special_prices.start_date/end_date (EXCLUDED)
 * ئەمە بۆ داتابەیسێکی بەتاڵ و نوێ
 */

return new class extends Migration
{
    public function up(): void
    {
        // roles
        Schema::create('roles', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();
            $table->string('display_name');
            $table->json('permissions')->nullable();
            $table->boolean('is_system')->default(false);
            $table->timestamps();
        });

        // users - table already exists from 0001, so we alter it
        Schema::table('users', function (Blueprint $table) {
            if (!Schema::hasColumn('users', 'role_id')) {
                $table->foreignId('role_id')->nullable()->after('id')->constrained()->restrictOnDelete();
            }
            if (!Schema::hasColumn('users', 'commission_rate')) {
                $table->unsignedTinyInteger('commission_rate')->default(0)->comment('40=40%')->after('role_id');
            }
            if (!Schema::hasColumn('users', 'barcode')) {
                $table->string('barcode')->nullable()->unique()->after('commission_rate');
            }
            if (!Schema::hasColumn('users', 'is_active')) {
                $table->boolean('is_active')->default(true)->index()->after('barcode');
            }
            if (!Schema::hasColumn('users', 'last_login_at')) {
                $table->timestamp('last_login_at')->nullable()->after('is_active');
            }
            if (!Schema::hasColumn('users', 'created_by')) {
                $table->foreignId('created_by')->nullable()->after('last_login_at')->constrained('users')->nullOnDelete();
            }
        });

        Schema::create('device_tokens', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('token')->unique();
            $table->string('device_type', 20);
            $table->string('device_name')->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestamp('last_used_at')->nullable();
            $table->timestamps();
        });

        Schema::create('notifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('type', 30)->index();
            $table->string('title');
            $table->text('body');
            $table->json('data')->nullable();
            $table->boolean('is_read')->default(false)->index();
            $table->timestamp('read_at')->nullable();
            $table->timestamps();
        });

        Schema::create('routes', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();
            $table->string('color', 7)->nullable();
            $table->boolean('is_active')->default(true)->index();
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('customers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('route_id')->constrained()->restrictOnDelete();
            $table->string('name')->index();
            $table->string('image_url')->nullable();
            $table->string('phone', 20)->nullable()->index();
            $table->string('phone2', 20)->nullable();
            $table->string('address')->nullable();
            $table->decimal('latitude', 10, 8)->nullable();
            $table->decimal('longitude', 11, 8)->nullable();
            $table->enum('price_type', ['N1', 'N2', 'N3'])->default('N2');
            $table->bigInteger('current_balance')->default(0);
            $table->boolean('is_active')->default(true)->index();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('customer_assignments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('customer_id')->constrained()->cascadeOnDelete();
            $table->foreignId('salesman_id')->constrained('users')->restrictOnDelete();
            $table->date('assigned_from');
            $table->date('assigned_until')->nullable();
            $table->foreignId('assigned_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        Schema::create('route_salesmen', function (Blueprint $table) {
            $table->id();
            $table->foreignId('route_id')->constrained()->cascadeOnDelete();
            $table->foreignId('salesman_id')->constrained('users')->restrictOnDelete();
            $table->date('work_date');
            $table->boolean('is_active')->default(true);
            $table->foreignId('assigned_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->unique(['route_id', 'work_date']);
        });

        Schema::create('categories', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();
            $table->foreignId('parent_id')->nullable()->constrained('categories')->nullOnDelete();
            $table->boolean('is_active')->default(true)->index();
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('products', function (Blueprint $table) {
            $table->id();
            $table->foreignId('category_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('supplier_id')->nullable()->constrained()->nullOnDelete();
            $table->string('name')->index();
            $table->string('sku')->unique();
            $table->string('barcode')->nullable()->unique();
            $table->string('unit', 20)->default('PCS');
            $table->unsignedInteger('units_per_carton')->nullable();
            $table->unsignedBigInteger('cost_price');
            $table->unsignedBigInteger('price_n1');
            $table->unsignedBigInteger('price_n2');
            $table->unsignedBigInteger('price_n3');
            $table->string('image_path')->nullable();
            $table->boolean('is_active')->default(true)->index();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('customer_special_prices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('customer_id')->constrained()->cascadeOnDelete();
            $table->foreignId('product_id')->constrained()->cascadeOnDelete();
            $table->unsignedBigInteger('price');
            // start_date/end_date EXCLUDED per request
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->unique(['customer_id', 'product_id']);
        });

        Schema::create('restock_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('customer_id')->constrained()->restrictOnDelete();
            $table->foreignId('product_id')->constrained()->restrictOnDelete();
            $table->unsignedInteger('requested_quantity');
            $table->unsignedInteger('quantity')->default(1);
            $table->foreignId('salesman_id')->nullable()->constrained('users')->restrictOnDelete();
            $table->enum('status', ['OPEN', 'ORDERED', 'CLOSED'])->default('OPEN')->index();
            $table->text('notes')->nullable();
            $table->foreignId('created_by')->constrained('users')->restrictOnDelete();
            $table->timestamps();
        });

        Schema::create('warehouses', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();
            $table->string('address')->nullable();
            $table->boolean('is_main')->default(false);
            $table->boolean('is_active')->default(true)->index();
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('warehouse_stock', function (Blueprint $table) {
            $table->id();
            $table->foreignId('warehouse_id')->constrained()->cascadeOnDelete();
            $table->foreignId('product_id')->constrained()->restrictOnDelete();
            $table->unsignedInteger('quantity')->default(0);
            $table->unsignedInteger('reserved_quantity')->default(0);
            $table->unsignedInteger('min_stock_level')->default(0);
            $table->unsignedInteger('max_stock_level')->default(1000);
            $table->unsignedBigInteger('average_cost')->default(0);
            $table->timestamps();
            $table->unique(['warehouse_id', 'product_id']);
        });

        Schema::create('stock_transactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('warehouse_id')->constrained()->restrictOnDelete();
            $table->foreignId('product_id')->constrained()->restrictOnDelete();
            $table->enum('type', ['PURCHASE', 'RESERVE', 'RELEASE', 'DELIVERY', 'RETURN', 'TRANSFER_OUT', 'TRANSFER_IN', 'ADJUSTMENT', 'in', 'out', 'reserved', 'unreserved', 'packed']);
            $table->integer('quantity_change');
            $table->bigInteger('quantity_after')->nullable();
            $table->string('reference_type', 50)->nullable();
            $table->unsignedBigInteger('reference_id')->nullable();
            $table->text('notes')->nullable();
            $table->foreignId('created_by')->constrained('users')->restrictOnDelete();
            $table->timestamps();
        });

        Schema::create('stock_transfers', function (Blueprint $table) {
            $table->id();
            $table->string('transfer_number')->unique()->nullable();
            $table->foreignId('from_warehouse_id')->constrained('warehouses')->restrictOnDelete();
            $table->foreignId('to_warehouse_id')->constrained('warehouses')->restrictOnDelete();
            $table->enum('status', ['DRAFT', 'COMPLETED', 'CANCELLED', 'in_transit'])->default('DRAFT')->index();
            $table->text('notes')->nullable();
            $table->foreignId('created_by')->constrained('users')->restrictOnDelete();
            $table->foreignId('approved_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('transferred_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();
        });

        Schema::create('stock_transfer_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('stock_transfer_id')->constrained()->cascadeOnDelete();
            $table->foreignId('product_id')->constrained()->restrictOnDelete();
            $table->unsignedInteger('quantity');
            $table->unsignedInteger('quantity_received')->default(0);
            $table->text('notes')->nullable();
            $table->timestamps();
            $table->unique(['stock_transfer_id', 'product_id']);
        });

        Schema::create('suppliers', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();
            $table->string('phone', 20)->nullable()->index();
            $table->string('address')->nullable();
            $table->string('contact_person')->nullable();
            $table->boolean('is_active')->default(true)->index();
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('purchase_orders', function (Blueprint $table) {
            $table->id();
            $table->string('order_number')->unique();
            $table->foreignId('supplier_id')->constrained()->restrictOnDelete();
            $table->foreignId('warehouse_id')->constrained()->restrictOnDelete();
            $table->enum('status', ['DRAFT', 'CONFIRMED', 'RECEIVED', 'CANCELLED'])->default('DRAFT')->index();
            $table->unsignedBigInteger('total_amount')->default(0);
            $table->text('notes')->nullable();
            $table->foreignId('created_by')->constrained('users')->restrictOnDelete();
            $table->timestamp('received_at')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('purchase_order_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('purchase_order_id')->constrained()->cascadeOnDelete();
            $table->foreignId('product_id')->constrained()->restrictOnDelete();
            $table->unsignedInteger('quantity');
            $table->unsignedBigInteger('unit_cost');
            $table->unsignedBigInteger('total_cost');
            $table->unsignedInteger('received_quantity')->default(0);
            $table->timestamps();
            $table->unique(['purchase_order_id', 'product_id']);
        });

        Schema::create('purchase_requirements', function (Blueprint $table) {
            $table->id();
            $table->foreignId('product_id')->constrained()->restrictOnDelete();
            $table->foreignId('warehouse_id')->constrained()->restrictOnDelete();
            $table->foreignId('supplier_id')->nullable()->constrained()->nullOnDelete();
            $table->unsignedInteger('required_quantity');
            $table->unsignedInteger('current_stock')->default(0);
            $table->unsignedInteger('suggested_quantity')->nullable();
            $table->boolean('is_urgent')->default(false)->index();
            $table->enum('status', ['OPEN', 'ORDERED', 'CLOSED'])->default('OPEN')->index();
            $table->foreignId('created_by')->constrained('users')->restrictOnDelete();
            $table->timestamps();
        });

        Schema::create('supplier_ledger', function (Blueprint $table) {
            $table->id();
            $table->foreignId('supplier_id')->constrained()->restrictOnDelete();
            $table->enum('entry_type', ['PURCHASE', 'PAYMENT', 'ADJUSTMENT']);
            $table->string('type', 10)->nullable();
            $table->unsignedBigInteger('debit')->default(0);
            $table->unsignedBigInteger('credit')->default(0);
            $table->unsignedBigInteger('amount')->default(0);
            $table->bigInteger('balance_after')->default(0);
            $table->string('reference_type', 50)->nullable();
            $table->unsignedBigInteger('reference_id')->nullable();
            $table->string('description')->nullable();
            $table->foreignId('created_by')->constrained('users')->restrictOnDelete();
            $table->timestamps();
        });

        Schema::create('supplier_payments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('supplier_id')->constrained()->restrictOnDelete();
            $table->foreignId('purchase_order_id')->nullable()->constrained()->nullOnDelete();
            $table->unsignedBigInteger('amount');
            $table->enum('payment_method', ['cash', 'bank', 'transfer'])->default('cash');
            $table->date('paid_at');
            $table->text('notes')->nullable();
            $table->foreignId('created_by')->constrained('users')->restrictOnDelete();
            $table->timestamps();
        });

        Schema::create('sales_orders', function (Blueprint $table) {
            $table->id();
            $table->string('order_number')->unique();
            $table->foreignId('customer_id')->constrained()->restrictOnDelete();
            $table->foreignId('salesman_id')->constrained('users')->restrictOnDelete();
            $table->foreignId('warehouse_id')->constrained()->restrictOnDelete();
            $table->date('order_date')->index();
            $table->enum('status', ['DRAFT', 'CONFIRMED', 'PACKING', 'READY', 'IN_DELIVERY', 'DELIVERED', 'CANCELLED'])->default('DRAFT')->index();
            $table->unsignedBigInteger('subtotal')->default(0);
            $table->decimal('discount_percent', 5, 2)->default(0)->nullable();
            $table->unsignedBigInteger('discount_amount')->default(0);
            $table->unsignedBigInteger('total_amount')->default(0);
            $table->bigInteger('total_profit')->default(0)->comment('بۆ کۆمسیۆن');
            $table->text('notes')->nullable();
            $table->timestamp('confirmed_at')->nullable();
            $table->timestamp('ready_at')->nullable();
            $table->timestamp('delivered_at')->nullable();
            $table->foreignId('created_by')->constrained('users')->restrictOnDelete();
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('sales_order_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('sales_order_id')->constrained()->cascadeOnDelete();
            $table->foreignId('product_id')->constrained()->restrictOnDelete();
            $table->unsignedInteger('quantity');
            $table->unsignedBigInteger('unit_price');
            $table->unsignedBigInteger('cost_price');
            $table->string('price_type', 10)->default('N1');
            $table->decimal('discount_percent', 5, 2)->default(0);
            $table->unsignedBigInteger('discount_amount')->default(0);
            $table->unsignedBigInteger('line_total');
            $table->bigInteger('profit')->default(0);
            $table->boolean('is_packed')->default(false)->index();
            $table->timestamp('packed_at')->nullable();
            $table->foreignId('packed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->unique(['sales_order_id', 'product_id']);
        });

        Schema::create('sales_returns', function (Blueprint $table) {
            $table->id();
            $table->string('return_number')->unique();
            $table->foreignId('sales_order_id')->constrained()->restrictOnDelete();
            $table->foreignId('customer_id')->constrained()->restrictOnDelete();
            $table->text('reason')->nullable();
            $table->enum('status', ['pending', 'approved', 'rejected', 'completed'])->default('pending')->index();
            $table->unsignedBigInteger('total_return_amount')->default(0);
            $table->foreignId('created_by')->constrained('users')->restrictOnDelete();
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('sales_return_items', function (Blueprint $table) {
            $table->id();
            $table->foreignId('sales_return_id')->constrained()->cascadeOnDelete();
            $table->foreignId('sales_order_item_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('product_id')->constrained()->restrictOnDelete();
            $table->unsignedInteger('quantity');
            $table->unsignedBigInteger('unit_price');
            $table->unsignedBigInteger('total')->default(0);
            $table->string('reason')->nullable();
            $table->timestamps();
            $table->unique(['sales_return_id', 'product_id']);
        });

        Schema::create('delivery_trips', function (Blueprint $table) {
            $table->id();
            $table->string('trip_number')->unique();
            $table->foreignId('driver_id')->constrained('users')->restrictOnDelete();
            $table->date('trip_date')->index();
            $table->enum('status', ['DRAFT', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED'])->default('DRAFT')->index();
            $table->unsignedInteger('total_orders')->default(0);
            $table->unsignedBigInteger('total_amount_collected')->default(0);
            $table->text('notes')->nullable();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->foreignId('created_by')->constrained('users')->restrictOnDelete();
            $table->timestamps();
            $table->softDeletes();
        });

        Schema::create('delivery_trip_orders', function (Blueprint $table) {
            $table->id();
            $table->foreignId('delivery_trip_id')->constrained()->cascadeOnDelete();
            $table->foreignId('sales_order_id')->constrained()->restrictOnDelete();
            $table->unsignedBigInteger('received_amount')->default(0);
            $table->timestamp('delivered_at')->nullable();
            $table->enum('status', ['PENDING', 'DELIVERED', 'FAILED'])->default('PENDING')->index();
            $table->integer('delivery_order')->default(0);
            // latitude/longitude EXCLUDED per request
            $table->text('failed_reason')->nullable();
            $table->text('notes')->nullable();
            $table->timestamps();
            $table->unique(['delivery_trip_id', 'sales_order_id']);
        });

        Schema::create('customer_ledger', function (Blueprint $table) {
            $table->id();
            $table->foreignId('customer_id')->constrained()->restrictOnDelete();
            $table->enum('entry_type', ['SALE', 'PAYMENT', 'RETURN', 'ADJUSTMENT']);
            $table->string('type', 10)->nullable();
            $table->unsignedBigInteger('debit')->default(0);
            $table->unsignedBigInteger('credit')->default(0);
            $table->unsignedBigInteger('amount')->default(0);
            $table->bigInteger('balance_after')->default(0);
            $table->string('reference_type', 50)->nullable();
            $table->unsignedBigInteger('reference_id')->nullable();
            $table->string('description')->nullable();
            $table->foreignId('created_by')->constrained('users')->restrictOnDelete();
            $table->timestamps();
        });

        Schema::create('customer_payments', function (Blueprint $table) {
            $table->id();
            $table->string('payment_number')->unique()->nullable();
            $table->foreignId('customer_id')->constrained()->restrictOnDelete();
            $table->foreignId('sales_order_id')->nullable()->constrained()->nullOnDelete();
            $table->unsignedBigInteger('amount');
            $table->enum('payment_method', ['CASH', 'BANK'])->default('CASH');
            $table->date('paid_at');
            $table->foreignId('collected_by')->nullable()->constrained('users')->nullOnDelete();
            $table->foreignId('received_by')->constrained('users')->restrictOnDelete();
            $table->text('notes')->nullable();
            $table->timestamps();
        });

        Schema::create('salesman_commissions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('salesman_id')->constrained('users')->restrictOnDelete();
            $table->date('period_from');
            $table->date('period_to');
            $table->unsignedBigInteger('total_sales')->default(0);
            $table->unsignedBigInteger('profit_amount')->default(0);
            $table->unsignedBigInteger('total_profit')->default(0);
            $table->decimal('commission_rate', 5, 2)->default(0);
            $table->unsignedBigInteger('commission_amount')->default(0);
            $table->enum('status', ['calculated', 'approved', 'paid'])->default('calculated')->index();
            $table->timestamp('paid_at')->nullable();
            $table->foreignId('calculated_by')->constrained('users')->restrictOnDelete();
            $table->foreignId('paid_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
            $table->unique(['salesman_id', 'period_from', 'period_to']);
        });

        Schema::create('salesman_commission_details', function (Blueprint $table) {
            $table->id();
            $table->foreignId('salesman_commission_id')->constrained()->cascadeOnDelete();
            $table->foreignId('sales_order_id')->constrained()->restrictOnDelete();
            $table->unsignedBigInteger('sales_amount')->default(0);
            $table->unsignedBigInteger('profit_amount');
            $table->unsignedBigInteger('commission_amount');
            $table->timestamps();
            $table->unique(['salesman_commission_id', 'sales_order_id'], 'commission_detail_order_unique');
        });

        Schema::create('settings', function (Blueprint $table) {
            $table->id();
            $table->string('key')->unique();
            $table->json('value')->nullable();
            $table->foreignId('updated_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        Schema::create('sync_logs', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->string('device_id')->nullable()->index();
            $table->string('entity_type', 50)->index();
            $table->unsignedBigInteger('entity_id')->nullable();
            $table->string('table_name', 50)->nullable();
            $table->enum('action', ['CREATE', 'UPDATE', 'DELETE', 'CONFLICT'])->index();
            $table->string('sync_type', 20)->nullable();
            $table->unsignedInteger('records_synced')->default(0);
            $table->string('status', 20)->default('success')->index();
            $table->text('error_message')->nullable();
            $table->json('payload')->nullable();
            $table->timestamp('synced_at')->useCurrent();
            $table->timestamp('started_at')->nullable();
            $table->timestamp('completed_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::disableForeignKeyConstraints();
        foreach ([
            'sync_logs', 'settings', 'salesman_commission_details', 'salesman_commissions',
            'customer_payments', 'customer_ledger', 'delivery_trip_orders', 'delivery_trips',
            'sales_return_items', 'sales_returns', 'sales_order_items', 'sales_orders',
            'supplier_payments', 'supplier_ledger', 'purchase_requirements', 'purchase_order_items',
            'purchase_orders', 'suppliers', 'stock_transfer_items', 'stock_transfers',
            'stock_transactions', 'warehouse_stock', 'warehouses', 'restock_requests',
            'customer_special_prices', 'products', 'categories', 'route_salesmen',
            'customer_assignments', 'customers', 'routes', 'notifications', 'device_tokens', 'roles',
        ] as $table) {
            if ($table === 'roles') continue;
            Schema::dropIfExists($table);
        }
        Schema::table('users', function (Blueprint $table) {
            $table->dropForeign(['role_id']);
            $table->dropForeign(['created_by']);
            $table->dropColumn(['role_id', 'commission_rate', 'barcode', 'is_active', 'last_login_at', 'created_by']);
        });
        Schema::dropIfExists('roles');
        Schema::enableForeignKeyConstraints();
    }
};
