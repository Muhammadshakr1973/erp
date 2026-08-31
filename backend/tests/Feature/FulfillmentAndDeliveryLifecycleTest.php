<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Role;
use App\Models\Route;
use App\Models\Customer;
use App\Models\Warehouse;
use App\Models\Product;
use App\Models\WarehouseStock;
use App\Models\SalesOrder;
use App\Models\SalesOrderItem;
use App\Models\DeliveryTrip;
use App\Models\DeliveryTripOrder;
use App\Models\CustomerLedger;
use App\Models\CustomerPayment;
use App\Models\SalesReturn;
use App\Models\SalesReturnItem;
use App\Models\StockTransaction;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class FulfillmentAndDeliveryLifecycleTest extends TestCase
{
    use RefreshDatabase;

    protected $admin;
    protected $salesman;
    protected $driver;
    protected $unauthorizedDriver;
    protected $warehouseStaff;
    protected $customer;
    protected $warehouse;
    protected $product;
    protected $route;

    protected function setUp(): void
    {
        parent::setUp();

        // ١. ئامادەکردنی ڕۆڵەکان و بەکارهێنەران (Set up roles and users)
        $adminRole = Role::firstOrCreate(['name' => 'admin']);
        $salesmanRole = Role::firstOrCreate(['name' => 'salesman']);
        $driverRole = Role::firstOrCreate(['name' => 'driver']);
        $warehouseRole = Role::firstOrCreate(['name' => 'warehouse']);

        $this->admin = User::factory()->create([
            'role_id'   => $adminRole->id,
            'is_active' => true,
        ]);

        $this->salesman = User::factory()->create([
            'role_id'   => $salesmanRole->id,
            'is_active' => true,
        ]);

        $this->driver = User::factory()->create([
            'role_id'   => $driverRole->id,
            'is_active' => true,
        ]);

        $this->unauthorizedDriver = User::factory()->create([
            'role_id'   => $driverRole->id,
            'is_active' => true,
        ]);

        $this->warehouseStaff = User::factory()->create([
            'role_id'   => $warehouseRole->id,
            'is_active' => true,
        ]);

        // ٢. ڕێڕەو و کۆگا و کڕیار (Set up route, warehouse, and customer)
        $this->route = Route::create(['name' => 'Slemani Route']);
        
        $this->warehouse = Warehouse::create([
            'name' => 'Main Warehouse',
            'code' => 'WH01',
        ]);

        $this->customer = Customer::create([
            'name'            => 'Hiwa Ali',
            'phone'           => '07701234567',
            'current_balance' => 100000, // باڵانسی سەرەتایی ١٠٠ هەزار دینار قەرزدار
            'route_id'        => $this->route->id,
            'is_active'       => true,
        ]);

        // ٣. کاڵا و بڕی سەرەتایی لە کۆگا (Set up product and initial warehouse stock)
        $this->product = Product::create([
            'name'            => 'Cold Water Bottle XL',
            'sku'             => 'WAT-001',
            'price'           => 10000, // نرخی فرۆشتن ١٠ هەزار دینار
            'cost_price'      => 6000,  // تێچوو ٦ هەزار دینار
            'min_stock_level' => 5,
        ]);

        WarehouseStock::create([
            'warehouse_id'      => $this->warehouse->id,
            'product_id'        => $this->product->id,
            'quantity'          => 100, // ١٠٠ دانە لە ستۆکی فیزیکی
            'reserved_quantity' => 0,
        ]);

        // بەستنەوەی مەندوب بە کڕیارەوە (Assign customer to salesman)
        $this->salesman->assignedCustomers()->attach($this->customer->id);
    }

    /** @test */
    public function it_can_complete_entire_fulfillment_delivery_re_dispatch_and_return_lifecycle()
    {
        // ==========================================
        // قۆناغی یەکەم: دروستکردنی پسوڵەی فرۆشتن بە دۆخی DRAFT (Phase 1: Create Sales Order in DRAFT)
        // ==========================================
        $orderData = [
            'customer_id'  => $this->customer->id,
            'warehouse_id' => $this->warehouse->id,
            'items' => [
                [
                    'product_id' => $this->product->id,
                    'quantity'   => 10, // داواکردنی ١٠ دانە
                    'unit_price' => 10000,
                ]
            ],
        ];

        $response = $this->actingAs($this->salesman)->postJson('/api/v1/sales-orders', $orderData);
        $response->assertStatus(201);
        $orderId = $response->json('data.id');

        $this->assertDatabaseHas('sales_orders', [
            'id'              => $orderId,
            'status'          => SalesOrder::STATUS_DRAFT,
            'total_amount'    => 100000, // ١٠ دانە * ١٠ هەزار = ١٠٠ هەزار دینار کۆی پسوڵە
            'total_cost'      => 60000,  // ١٠ دانە * ٦ هەزار = ٦٠ هەزار دینار کۆی تێچوو
            'total_profit'    => 40000,  // قازانج ٤٠ هەزار دینار
            'customer_id'     => $this->customer->id,
            'warehouse_id'    => $this->warehouse->id,
        ]);

        // ==========================================
        // قۆناغی دووەم: پشتڕاستکردنەوە و حجزکردنی ستۆک (Phase 2: Confirm Order and Reserve Stock)
        // ==========================================
        $response = $this->actingAs($this->salesman)->postJson("/api/v1/sales-orders/{$orderId}/status", [
            'status' => SalesOrder::STATUS_CONFIRMED,
        ]);
        $response->assertStatus(200);

        // پشکنینی حجزکردنی کاڵا لە ستۆک
        $this->assertDatabaseHas('warehouse_stock', [
            'warehouse_id'      => $this->warehouse->id,
            'product_id'        => $this->product->id,
            'quantity'          => 100, // فیزیکی دەبێت هێشتا ١٠٠ بێت چونکە نەگەیندراوە
            'reserved_quantity' => 10,  // دەبێت ١٠ دانە حجز کرابێت
        ]);

        // ==========================================
        // قۆناغی سێیەم: پاکەتکردن و ئامادەکردن (Phase 3: Packing & Ready)
        // ==========================================
        // ١. گۆڕین بۆ PACKING
        $response = $this->actingAs($this->warehouseStaff)->postJson("/api/v1/sales-orders/{$orderId}/status", [
            'status' => SalesOrder::STATUS_PACKING,
        ]);
        $response->assertStatus(200);

        // ٢. نیشانەکردنی ئایتمەکان بە پاکەتکراو و گۆڕین بۆ READY
        $orderItem = SalesOrderItem::where('sales_order_id', $orderId)->first();
        $orderItem->update(['is_packed' => true]);

        $response = $this->actingAs($this->warehouseStaff)->postJson("/api/v1/sales-orders/{$orderId}/status", [
            'status' => SalesOrder::STATUS_READY,
        ]);
        $response->assertStatus(200);

        // ==========================================
        // قۆناغی چوارەم: دروستکردنی گەشتی گەیاندن و سپاردن بە شۆفێر (Phase 4: Create Delivery Trip)
        // ==========================================
        $tripData = [
            'driver_id' => $this->driver->id,
            'route_id'  => $this->route->id,
            'trip_date' => now()->toDateString(),
            'orders'    => [
                [
                    'sales_order_id' => $orderId,
                    'delivery_order' => 1,
                ]
            ],
        ];

        $response = $this->actingAs($this->admin)->postJson('/api/v1/delivery-trips', $tripData);
        $response->assertStatus(201);
        $tripId = $response->json('data.id');
        $tripOrderId = $response->json('data.orders.0.id');

        // دۆخی پسوڵەی سەرەکی دەبێت ئۆتۆماتیکی گۆڕابێت بۆ IN_DELIVERY
        $this->assertDatabaseHas('sales_orders', [
            'id'     => $orderId,
            'status' => SalesOrder::STATUS_IN_DELIVERY,
        ]);

        $this->assertDatabaseHas('delivery_trip_orders', [
            'id'               => $tripOrderId,
            'delivery_trip_id' => $tripId,
            'sales_order_id'   => $orderId,
            'status'           => 'PENDING',
        ]);

        // ==========================================
        // قۆناغی پێنجەم: ڕێگری لە دەستڕاگەیشتنی شۆفێری تر (Phase 5: IDOR driver block check)
        // ==========================================
        $response = $this->actingAs($this->unauthorizedDriver)->postJson("/api/v1/delivery-trips/orders/{$tripOrderId}/deliver", [
            'received_amount' => 50000,
        ]);
        $response->assertStatus(403); // دەبێت ڕێگری لێبکرێت چونکە سەر بە گەشتی ئەم نییە

        // ==========================================
        // قۆناغی شەشەم: شکستی گەیاندن و گەڕانەوە بۆ READY (Phase 6: Failed Delivery & Re-dispatch)
        // ==========================================
        $response = $this->actingAs($this->driver)->postJson("/api/v1/delivery-trips/orders/{$tripOrderId}/fail", [
            'failed_reason' => 'کڕیار لە ماڵەوە نەبوو',
            'notes'         => 'دووبارە هەوڵ بدەوە بەیانی',
        ]);
        $response->assertStatus(200);

        // دەبێت دۆخی گەشتەکە بووبێتە FAILED و پسوڵە سەرەکییەکە گەڕابێتەوە بۆ READY بۆ دووبارە ناردنەوە
        $this->assertDatabaseHas('delivery_trip_orders', [
            'id'            => $tripOrderId,
            'status'        => 'FAILED',
            'failed_reason' => 'کڕیار لە ماڵەوە نەبوو',
        ]);

        $this->assertDatabaseHas('sales_orders', [
            'id'     => $orderId,
            'status' => SalesOrder::STATUS_READY,
        ]);

        // ستۆکی حجزکراو دەبێت هێشتا وەک خۆی پارێزراو مابێتەوە بۆ پسوڵەکە
        $this->assertDatabaseHas('warehouse_stock', [
            'warehouse_id'      => $this->warehouse->id,
            'product_id'        => $this->product->id,
            'quantity'          => 100,
            'reserved_quantity' => 10,
        ]);

        // ==========================================
        // قۆناغی حەوتەم: سەرلەنوێ دروستکردنەوەی گەشتی گەیاندن (Phase 7: Re-plan Delivery Trip)
        // ==========================================
        $response = $this->actingAs($this->admin)->postJson('/api/v1/delivery-trips', $tripData);
        $response->assertStatus(201);
        $newTripOrderId = $response->json('data.orders.0.id');

        $this->assertDatabaseHas('sales_orders', [
            'id'     => $orderId,
            'status' => SalesOrder::STATUS_IN_DELIVERY,
        ]);

        // ==========================================
        // قۆناغی هەشتەم: گەیاندنی سەرکەوتوو لەگەڵ وەرگرتنی بەشێک پارە (Phase 8: Deliver with partial payment)
        // ==========================================
        // کڕیار بڕی ٣٠ هەزار دینار دەدات بە شۆفێر، مابقی ٧٠ هەزار دینار دەچێتە سەر قەرزەکەی
        $response = $this->actingAs($this->driver)->postJson("/api/v1/delivery-trips/orders/{$newTripOrderId}/deliver", [
            'received_amount' => 30000,
            'notes'           => 'بەشێکی درا و بەشێکی بە قەرز بەجێما',
        ]);
        $response->assertStatus(200);

        // دڵنیابوونەوە لە گۆڕانی دۆخی گەیاندن بۆ سەرکەوتوو
        $this->assertDatabaseHas('delivery_trip_orders', [
            'id'              => $newTripOrderId,
            'status'          => 'DELIVERED',
            'received_amount' => 30000,
        ]);

        $this->assertDatabaseHas('sales_orders', [
            'id'     => $orderId,
            'status' => SalesOrder::STATUS_DELIVERED,
        ]);

        // پشکنینی لێدەرچوونی کۆتایی ستۆک و نەمانی حجزەکە (Stock Deduction)
        $this->assertDatabaseHas('warehouse_stock', [
            'warehouse_id'      => $this->warehouse->id,
            'product_id'        => $this->product->id,
            'quantity'          => 90, // کەمبووەوە بە بڕی ١٠ دانەی فرۆشراو
            'reserved_quantity' => 0,  // حجزەکە ئازادکرا چونکە گەیاندنەکە تەواو بوو
        ]);

        // پشکنینی کاریگەری لەسەر باڵانسی کڕیار (Financial Impact)
        // باڵانسی پێشوو: ١٠٠،٠٠٠ دینار قەرز
        // بڕی پسوڵە: +١٠٠،٠٠٠ دینار قەرز
        // بڕی دراو بە شۆفێر: -٣٠،٠٠٠ دینار
        // باڵانسی نوێی قەرز دەبێت بێتە: ١٧٠،٠٠٠ دینار قەرزدار
        $this->assertDatabaseHas('customers', [
            'id'              => $this->customer->id,
            'current_balance' => 170000,
        ]);

        // پشکنینی دروستبوونی تۆماری پارەدان لە سیستەم (Payment record)
        $this->assertDatabaseHas('customer_payments', [
            'customer_id'    => $this->customer->id,
            'amount'         => 30000,
            'payment_method' => 'CASH',
        ]);

        // پشکنینی دروستبوونی تۆماری Ledger (Customer Ledger Entries)
        // یەکەم: قەرزی پسوڵە (١٠٠ هەزار)
        $this->assertDatabaseHas('customer_ledger', [
            'customer_id'    => $this->customer->id,
            'entry_type'     => 'SALE',
            'type'           => 'debit',
            'debit'          => 100000,
            'credit'         => 0,
            'balance_before' => 100000,
            'balance_after'  => 200000,
        ]);

        // دووەم: کەمکردنەوەی قەرز بە پارەدانەکە (٣٠ هەزار)
        $this->assertDatabaseHas('customer_ledger', [
            'customer_id'    => $this->customer->id,
            'entry_type'     => 'PAYMENT',
            'type'           => 'credit',
            'debit'          => 0,
            'credit'         => 30000,
            'balance_before' => 200000,
            'balance_after'  => 170000,
        ]);

        // ==========================================
        // قۆناغی نۆیەم: گەڕاندنەوەی کاڵا (Phase 9: Sales Return)
        // ==========================================
        // کڕیار بڕیاری گەڕاندنەوەی ٢ دانە لە کاڵاکان دەدات (بەهۆی درز یان هەر کێشەیەک)
        // گەڕاندنەوەی ٢ دانە بە نرخی ١٠ هەزار = ٢٠ هەزار دینار کەمکردنەوەی قەرز
        $returnData = [
            'sales_order_id' => $orderId,
            'reason'         => '٢ دانە لە بوتڵەکان شکاوبوون',
            'items'          => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity'            => 2,
                    'reason'              => 'شکاو بووە',
                ]
            ],
        ];

        $response = $this->actingAs($this->salesman)->postJson('/api/v1/sales-returns', $returnData);
        $response->assertStatus(201);
        $returnId = $response->json('data.id');

        // پشکنینی سەرکەوتوویی گەڕانەوەی کۆگا
        $this->assertDatabaseHas('sales_returns', [
            'id'                  => $returnId,
            'sales_order_id'      => $orderId,
            'customer_id'         => $this->customer->id,
            'total_return_amount' => 20000,
            'status'              => 'completed',
        ]);

        $this->assertDatabaseHas('sales_return_items', [
            'sales_return_id'     => $returnId,
            'sales_order_item_id' => $orderItem->id,
            'quantity'            => 2,
            'unit_price'          => 10000,
            'total'               => 20000,
        ]);

        // دڵنیابوونەوە لەوەی کاڵاکە گەڕاوەتەوە بۆ ناو ستۆک (Stock return effect)
        // ستۆکی فیزیکی ماوە دەبێت ببێتە: ٩٠ + ٢ = ٩٢ دانە
        $this->assertDatabaseHas('warehouse_stock', [
            'warehouse_id' => $this->warehouse->id,
            'product_id'   => $this->product->id,
            'quantity'     => 92,
        ]);

        // دڵنیابوونەوە لە کەمبوونەوەی قەرزی کڕیار لەسەر باڵانسەکەی
        // باڵانسی پێشوو: ١٧٠،٠٠٠ دینار قەرزدار
        // کۆی گەڕانەوە: -٢٠،٠٠٠ دینار
        // باڵانسی نوێی قەرز دەبێت بێتە: ١٥٠،٠٠٠ دینار قەرزدار
        $this->assertDatabaseHas('customers', [
            'id'              => $this->customer->id,
            'current_balance' => 150000,
        ]);

        // پشکنینی تۆماری Ledger بۆ کرداری گەڕانەوەکە
        $this->assertDatabaseHas('customer_ledger', [
            'customer_id'    => $this->customer->id,
            'entry_type'     => 'RETURN',
            'type'           => 'credit',
            'debit'          => 0,
            'credit'         => 20000,
            'balance_before' => 170000,
            'balance_after'  => 150000,
        ]);

        // هەوڵدان بۆ گەڕاندنەوەی زیاتر لە توانای بەردەست دەبێت ڕەت بکرێتەوە
        // کۆی کڕدراو ١٠ دانە بوو، ٢ دانەی گەڕاوەتەوە، تەنها ٨ دانە ماوە بۆ گەڕانەوە. ئەگەر داوای ٩ دانە بکات دەبێت فەشەل بێنێت
        $invalidReturnData = [
            'sales_order_id' => $orderId,
            'reason'         => 'بڕی ناڕاست',
            'items'          => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity'            => 9, // لە کاتێکدا تەنها ٨ دانەی ماوە
                ]
            ],
        ];

        $response = $this->actingAs($this->salesman)->postJson('/api/v1/sales-returns', $invalidReturnData);
        $response->assertStatus(422); // دەبێت فڕێدانی هەڵەی فۆرم و ناڕاستی بڕی داواکراو بدات
    }
}
