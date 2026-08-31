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
                // Simulate payment collection but throw exception to force rollback
                $payment = $paymentService->collectPayment($paymentData, $this->owner);
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

        // Verify NO WhatsApp log was created/persisted
        $this->assertDatabaseMissing('whatsapp_notification_logs', [
            'customer_id' => $this->customer->id,
            'notification_type' => 'PAYMENT_RECEIVED',
        ]);
    }

    /**
     * Test that a provider-level WhatsApp failure does NOT rollback the parent transaction.
     */
    public function test_whatsapp_failure_does_not_rollback_parent_transaction(): void
    {
        // Fake the WhatsApp HTTP provider API to return a 500 server error
        \Illuminate\Support\Facades\Http::fake([
            'https://api.whatsapp-provider.com/*' => \Illuminate\Support\Facades\Http::response(['error' => 'Internal Server Error'], 500),
        ]);

        // Configure settings/config to force the service to hit the faked endpoint instead of simulated fallback
        \App\Models\Setting::updateOrCreate(['key' => 'whatsapp_provider'], ['value' => 'api_provider']);
        \App\Models\Setting::updateOrCreate(['key' => 'whatsapp_api_url'], ['value' => 'https://api.whatsapp-provider.com/send']);
        \App\Models\Setting::updateOrCreate(['key' => 'whatsapp_api_token'], ['value' => 'secret_token_123']);

        $paymentService = app(PaymentService::class);

        $paymentData = [
            'customer_id' => $this->customer->id,
            'amount' => 300000,
            'payment_method' => 'cash',
            'notes' => 'Payment with failing WhatsApp provider',
        ];

        // Execute payment - this should NOT throw an exception despite WhatsApp failing
        $payment = $paymentService->collectPayment($paymentData, $this->owner);

        $this->assertNotNull($payment);

        // Verify the parent payment transaction successfully committed
        $this->assertDatabaseHas('customer_payments', [
            'id' => $payment->id,
            'amount' => 300000,
        ]);

        // Verify the customer's financial balance is updated (committed)
        $this->customer->refresh();
        $this->assertEquals(700000, $this->customer->current_balance);

        // Verify the WhatsApp notification log is marked as FAILED with error message
        $this->assertDatabaseHas('whatsapp_notification_logs', [
            'reference_id' => $payment->id,
            'status' => 'FAILED',
        ]);

        $log = WhatsAppNotificationLog::where('reference_id', $payment->id)->first();
        $this->assertNotNull($log);
        $this->assertContains('FAILED', [$log->status]);
        $this->assertStringContainsString('Provider HTTP 500', $log->error_message);
    }

    /**
     * Test WhatsApp retry logic transitions status and increments retry count.
     */
    public function test_whatsapp_retry_logic(): void
    {
        // Create an initially failed WhatsApp notification log
        $log = WhatsAppNotificationLog::create([
            'customer_id' => $this->customer->id,
            'recipient_phone' => '+9647501234567',
            'recipient_name' => 'Kawa Store',
            'notification_type' => 'PAYMENT_RECEIVED',
            'reference_type' => 'customer_payment',
            'reference_id' => 9999,
            'idempotency_key' => 'WA-unique-retry-test-key-123',
            'message' => 'Test message',
            'status' => 'FAILED',
            'provider' => 'api_provider',
            'retry_count' => 0,
        ]);

        // Fake the WhatsApp HTTP provider API to now succeed
        \Illuminate\Support\Facades\Http::fake([
            'https://api.whatsapp-provider.com/*' => \Illuminate\Support\Facades\Http::response(['id' => 'msg_id_9999', 'success' => true], 200),
        ]);

        // Configure credentials
        \App\Models\Setting::updateOrCreate(['key' => 'whatsapp_provider'], ['value' => 'api_provider']);
        \App\Models\Setting::updateOrCreate(['key' => 'whatsapp_api_url'], ['value' => 'https://api.whatsapp-provider.com/send']);
        \App\Models\Setting::updateOrCreate(['key' => 'whatsapp_api_token'], ['value' => 'secret_token_123']);

        $whatsAppService = app(WhatsAppService::class);

        // Invoke the retry logic
        $updatedLog = $whatsAppService->retryNotification($log->id, $this->owner);

        // Assert that the retry count has incremented to 1
        $this->assertEquals(1, $updatedLog->retry_count);

        // Assert that the status successfully transitioned to SENT
        $this->assertEquals('SENT', $updatedLog->status);
        $this->assertEquals('msg_id_9999', $updatedLog->provider_message_id);
        $this->assertNull($updatedLog->error_message);

        // Also verify the database is in sync
        $this->assertDatabaseHas('whatsapp_notification_logs', [
            'id' => $log->id,
            'retry_count' => 1,
            'status' => 'SENT',
            'provider_message_id' => 'msg_id_9999',
        ]);
    }
}
