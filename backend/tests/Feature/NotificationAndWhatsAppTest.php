<?php

namespace Tests\Feature;

use App\Models\Customer;
use App\Models\DeviceToken;
use App\Models\Notification;
use App\Models\Role;
use App\Models\User;
use App\Models\WhatsAppNotificationLog;
use App\Services\NotificationService;
use App\Services\PaymentService;
use App\Services\WhatsAppService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class NotificationAndWhatsAppTest extends TestCase
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
            'code' => 'RC-01',
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

        $n2 = $service->sendNotification(
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
            'device_token' => $token,
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
            'device_token' => $token,
            'is_active' => false,
        ]);
    }

    /**
     * Test Payment Service triggers WhatsApp message & in-app notification after commit
     */
    public function test_payment_service_triggers_whatsapp_notification_idempotently(): void
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

        // Verify WhatsApp notification log created
        $this->assertDatabaseHas('whatsapp_notification_logs', [
            'customer_id' => $this->customer->id,
            'notification_type' => 'PAYMENT_RECEIVED',
            'reference_type' => 'CustomerPayment',
            'reference_id' => $payment->id,
        ]);

        $log = WhatsAppNotificationLog::where('reference_id', $payment->id)->first();
        $this->assertNotNull($log);
        $this->assertStringContainsString('250,000', $log->message);
        $this->assertStringContainsString('750,000', $log->message);

        // Test Idempotency: Calling send again for same payment returns existing log without duplicates
        $whatsAppService = app(WhatsAppService::class);
        $secondLog = $whatsAppService->sendCustomerPaymentNotification($payment, 1000000, 750000, $this->owner);

        $this->assertEquals($log->id, $secondLog->id);
        $this->assertEquals(1, WhatsAppNotificationLog::where('reference_id', $payment->id)->count());
    }
}
