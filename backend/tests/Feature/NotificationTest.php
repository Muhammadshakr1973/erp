<?php

namespace Tests\Feature;

use App\Models\Customer;
use App\Models\Notification;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Services\NotificationService;
use App\Services\PaymentService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class NotificationTest extends TestCase
{
    use RefreshDatabase;

    protected User $owner;
    protected User $salesman;
    protected Customer $customer;

    protected function setUp(): void
    {
        parent::setUp();

        $ownerRole = Role::create([
            'name' => Role::OWNER,
            'display_name' => 'Owner',
            'permissions' => ['*'],
        ]);

        $salesmanRole = Role::create([
            'name' => Role::SALESMAN,
            'display_name' => 'Salesman',
            'permissions' => ['orders.create', 'customers.view'],
        ]);

        $this->owner = User::factory()->create([
            'role_id' => $ownerRole->id,
            'is_active' => true,
        ]);

        $this->salesman = User::factory()->create([
            'role_id' => $salesmanRole->id,
            'is_active' => true,
        ]);

        $route = \App\Models\Route::create([
            'name' => 'Route Center',
            'is_active' => true,
        ]);

        $this->customer = Customer::create([
            'name' => 'Kawa Store',
            'phone' => '07501234567',
            'route_id' => $route->id,
            'credit_limit' => 5000000,
            'current_balance' => 1000000,
            'payment_type' => 'credit',
            'is_active' => true,
        ]);
    }

    /**
     * Test notification creation, list, and unread count
     */
    public function test_notifications_lifecycle_and_unread_count(): void
    {
        $service = app(NotificationService::class);

        // Create 2 notifications
        $n1 = $service->sendNotification(
            $this->salesman,
            'order',
            'پسوڵەی نوێ',
            'پسوڵەی ژمارە ORD-1001 بە سەرکەوتوویی دروستکرا.',
            ['order_id' => 1001]
        );

        $service->sendNotification(
            $this->salesman,
            'payment',
            'پارەدان وەرگیرا',
            'بڕی 50,000 دینار لە کڕیار وەرگیرا.',
            ['payment_id' => 2002]
        );

        // Check unread count via API
        $res = $this->actingAs($this->salesman, 'sanctum')
            ->getJson('/api/v1/notifications/unread-count');

        $res->assertOk()
            ->assertJson(['unread_count' => 2]);

        // Mark single as read
        $markRes = $this->actingAs($this->salesman, 'sanctum')
            ->postJson("/api/v1/notifications/{$n1->id}/read");

        $markRes->assertOk()
            ->assertJsonPath('data.is_read', true);

        // Verify unread count is now 1
        $this->assertEquals(1, $service->getUnreadCount($this->salesman));

        // Mark all as read
        $markAllRes = $this->actingAs($this->salesman, 'sanctum')
            ->postJson('/api/v1/notifications/read');

        $markAllRes->assertOk()
            ->assertJson(['success' => true, 'updated_count' => 1]);

        $this->assertEquals(0, $service->getUnreadCount($this->salesman));
    }

    /**
     * Test device token registration and removal
     */
    public function test_device_token_registration_and_cleanup(): void
    {
        $token = 'fcm_sample_device_token_123456789';

        $regRes = $this->actingAs($this->salesman, 'sanctum')
            ->postJson('/api/v1/device-token', [
                'device_token' => $token,
                'device_type' => 'android',
                'device_name' => 'Samsung Galaxy S22',
            ]);

        $regRes->assertOk()
            ->assertJson(['success' => true]);

        $this->assertDatabaseHas('device_tokens', [
            'user_id' => $this->salesman->id,
            'token' => $token,
            'is_active' => true,
        ]);

        // Remove token
        $delRes = $this->actingAs($this->salesman, 'sanctum')
            ->deleteJson('/api/v1/device-token', [
                'device_token' => $token,
            ]);

        $delRes->assertOk()
            ->assertJson(['success' => true]);

        $this->assertDatabaseHas('device_tokens', [
            'user_id' => $this->salesman->id,
            'token' => $token,
            'is_active' => false,
        ]);
    }

    /**
     * Test Payment Service triggers in-app notification after commit
     */
    public function test_payment_service_triggers_in_app_notification(): void
    {
        $paymentService = app(PaymentService::class);

        $paymentData = [
            'customer_id' => $this->customer->id,
            'amount' => 250000,
            'payment_method' => 'cash',
            'notes' => 'وەسڵی مانگانە',
        ];

        $payment = $paymentService->collectPayment($paymentData, $this->owner);

        $this->assertNotNull($payment);

        // Verify financial integrity
        $this->customer->refresh();
        $this->assertEquals(750000, $this->customer->current_balance);

        // Verify in-app notification created
        $this->assertDatabaseHas('notifications', [
            'type' => 'payment',
        ]);
    }

    /**
     * Test that notifications are never dispatched if the parent transaction fails and rolls back.
     */
    public function test_failed_transactions_do_not_dispatch_notifications(): void
    {
        $paymentService = app(PaymentService::class);

        $paymentData = [
            'customer_id' => $this->customer->id,
            'amount' => 150000,
            'payment_method' => 'cash',
            'notes' => 'This transaction will fail',
        ];

        try {
            \Illuminate\Support\Facades\DB::transaction(function () use ($paymentService, $paymentData) {
                $paymentService->collectPayment($paymentData, $this->owner);
                throw new \Exception('Forced Rollback');
            });
        } catch (\Exception $e) {
            $this->assertEquals('Forced Rollback', $e->getMessage());
        }

        // Verify payment is NOT in database
        $this->assertDatabaseMissing('customer_payments', [
            'amount' => 150000,
            'notes' => 'This transaction will fail',
        ]);

        // Verify NO in-app notification was dispatched/persisted
        $this->assertDatabaseMissing('notifications', [
            'type' => 'payment',
            'body' => 'بڕی 150,000 دینار لە کڕیار وەرگیرا.',
        ]);
    }

    /**
     * Test that creating a new customer triggers a notification to admins and owners.
     */
    public function test_new_customer_triggers_notification_to_admins_and_owners(): void
    {
        $adminRole = Role::create([
            'name' => Role::ADMIN,
            'display_name' => 'Admin',
            'permissions' => ['*'],
        ]);

        $adminUser = User::factory()->create([
            'role_id' => $adminRole->id,
            'is_active' => true,
        ]);

        Notification::whereIn('user_id', [$this->owner->id, $adminUser->id])->delete();

        $payload = [
            'name' => 'New Awesome Customer',
            'phone' => '07502223344',
            'price_tier' => 'RETAIL',
            'route_id' => $this->customer->route_id,
        ];

        $response = $this->actingAs($this->salesman, 'sanctum')
            ->postJson('/api/v1/customers', $payload);

        $response->assertStatus(201);

        // Verify notification was created for Owner and Admin
        $this->assertDatabaseHas('notifications', [
            'user_id' => $this->owner->id,
            'type' => 'customer',
            'title' => 'کڕیاری نوێ زیادکرا',
        ]);

        $this->assertDatabaseHas('notifications', [
            'user_id' => $adminUser->id,
            'type' => 'customer',
            'title' => 'کڕیاری نوێ زیادکرا',
        ]);

        // Ensure salesman didn't get this notification (only owner and admin)
        $this->assertDatabaseMissing('notifications', [
            'user_id' => $this->salesman->id,
            'type' => 'customer',
        ]);
    }

    /**
     * Test that creating a new sales order notifies warehouse staff but does NOT notify admin or owner.
     */
    public function test_new_sales_order_does_not_notify_admin_or_owner(): void
    {
        $adminRole = Role::create([
            'name' => Role::ADMIN,
            'display_name' => 'Admin',
            'permissions' => ['*'],
        ]);

        $adminUser = User::factory()->create([
            'role_id' => $adminRole->id,
            'is_active' => true,
        ]);

        $warehouseRole = Role::create([
            'name' => 'warehouse',
            'display_name' => 'Warehouse',
            'permissions' => ['stock.pack'],
        ]);

        $warehouseUser = User::factory()->create([
            'role_id' => $warehouseRole->id,
            'is_active' => true,
        ]);

        $warehouse = \App\Models\Warehouse::create(['name' => 'Warehouse A', 'is_main' => true, 'is_active' => true]);
        $product = Product::create([
            'name' => 'Sample Item',
            'sku' => 'SMP-11',
            'unit' => 'PCS',
            'cost_price' => 1000,
            'price_n1' => 2000,
            'price_n2' => 2000,
            'price_n3' => 2000,
            'is_active' => true,
        ]);

        \App\Models\WarehouseStock::create([
            'warehouse_id' => $warehouse->id,
            'product_id' => $product->id,
            'quantity' => 50,
            'reserved_quantity' => 0,
        ]);

        Notification::query()->delete();

        $orderData = [
            'customer_id' => $this->customer->id,
            'warehouse_id' => $warehouse->id,
            'items' => [
                ['product_id' => $product->id, 'quantity' => 2]
            ]
        ];

        $this->actingAs($this->salesman, 'sanctum')
            ->postJson('/api/v1/orders', $orderData)
            ->assertStatus(200);

        // Verify warehouse user GOT the order notification
        $this->assertDatabaseHas('notifications', [
            'user_id' => $warehouseUser->id,
            'type' => 'order',
            'title' => 'پسوڵەی فرۆشتنی نوێ دروستکرا',
        ]);

        // Verify owner and admin did NOT get notification for new order creation
        $this->assertDatabaseMissing('notifications', [
            'user_id' => $this->owner->id,
            'type' => 'order',
            'title' => 'پسوڵەی فرۆشتنی نوێ دروستکرا',
        ]);

        $this->assertDatabaseMissing('notifications', [
            'user_id' => $adminUser->id,
            'type' => 'order',
            'title' => 'پسوڵەی فرۆشتنی نوێ دروستکرا',
        ]);
    }
}
