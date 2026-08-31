<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\CustomerPayment;
use App\Models\SalesOrder;
use App\Models\Setting;
use App\Models\Supplier;
use App\Models\User;
use App\Models\WhatsAppNotificationLog;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class WhatsAppService
{
    /**
     * Get configured company name for header
     */
    private function getCompanyName(): string
    {
        return Setting::getValue('company_name', 'کۆمپانیای گاردی (GARDI ERP)');
    }

    /**
     * Clean phone number to standard format
     */
    public function formatPhoneNumber(?string $phone): ?string
    {
        if (!$phone) {
            return null;
        }

        // Remove non-digit characters except +
        $cleaned = preg_replace('/[^\d+]/', '', $phone);
        
        // Handle Iraqi numbers starting with 07 -> +9647
        if (str_starts_with($cleaned, '07')) {
            $cleaned = '+964' . substr($cleaned, 1);
        } elseif (str_starts_with($cleaned, '7') && strlen($cleaned) === 10) {
            $cleaned = '+964' . $cleaned;
        }

        return $cleaned;
    }

    /**
     * Format currency amount for Kurdish display
     */
    private function formatMoney(int|float $amount): string
    {
        return number_format($amount, 0, '.', ',') . ' د.ع';
    }

    /**
     * Check if WhatsApp message was already dispatched for this reference (Idempotency)
     */
    public function checkIdempotency(string $referenceType, int $referenceId, string $notificationType): ?WhatsAppNotificationLog
    {
        return WhatsAppNotificationLog::where('reference_type', $referenceType)
            ->where('reference_id', $referenceId)
            ->where('notification_type', $notificationType)
            ->whereIn('status', [WhatsAppNotificationLog::STATUS_SENT, WhatsAppNotificationLog::STATUS_SIMULATED])
            ->where('created_at', '>=', now()->subMinutes(10))
            ->first();
    }

    /**
     * BR-F06: Customer Payment WhatsApp Notification
     * Triggered AFTER payment transaction is committed
     */
    public function sendCustomerPaymentNotification(
        CustomerPayment $payment,
        int $previousBalance,
        int $newBalance,
        ?User $actor = null
    ): WhatsAppNotificationLog {
        $customer = $payment->customer ?? Customer::find($payment->customer_id);
        $phone = $this->formatPhoneNumber($customer?->phone);
        $recipientName = $customer?->name ?? 'کڕیاری بەڕێز';

        // Check idempotency
        $existing = $this->checkIdempotency('customer_payment', $payment->id, 'PAYMENT_RECEIVED');
        if ($existing) {
            return $existing;
        }

        $company = $this->getCompanyName();
        $dateStr = now()->format('Y-m-d H:i');
        $paymentAmount = $this->formatMoney($payment->amount);
        $oldDebtStr = $this->formatMoney($previousBalance);
        $newDebtStr = $this->formatMoney($newBalance);

        // Standard Sorani Kurdish receipt format per BR-F08
        $message = "🏢 *{$company}*\n"
            . "--------------------------------\n"
            . "🧾 *پسوڵەی وەرگرتنی پارە*\n"
            . "👤 بەڕێز: {$recipientName}\n"
            . "🔢 ژمارەی پسوڵە: {$payment->payment_number}\n"
            . "💰 بڕی وەرگیراو: *{$paymentAmount}*\n"
            . "📊 قەرزی پێشوو: {$oldDebtStr}\n"
            . "📉 قەرزی نوێی ماوە: *{$newDebtStr}*\n"
            . "🕒 کات و بەروار: {$dateStr}\n"
            . "📌 جۆری پارەدان: {$payment->payment_method}\n"
            . "--------------------------------\n"
            . "سوپاس بۆ مامەڵەکردنتان لەگەڵمان.";

        $payload = [
            'payment_id' => $payment->id,
            'payment_number' => $payment->payment_number,
            'customer_id' => $customer?->id,
            'amount' => $payment->amount,
            'previous_balance' => $previousBalance,
            'new_balance' => $newBalance,
        ];

        return $this->dispatchMessage(
            recipientPhone: $phone ?? $customer?->phone ?? 'UNKNOWN',
            recipientName: $recipientName,
            notificationType: 'PAYMENT_RECEIVED',
            referenceType: 'customer_payment',
            referenceId: $payment->id,
            message: $message,
            customerId: $customer?->id,
            supplierId: null,
            payload: $payload,
            actor: $actor
        );
    }

    /**
     * BR-F05: Customer Delivery Debt WhatsApp Notification
     * Triggered AFTER delivery transaction is committed when order is delivered with debt or partial payment
     */
    public function sendDeliveryDebtNotification(
        SalesOrder $order,
        int $previousBalance,
        int $receivedAmount,
        int $newBalance,
        ?User $actor = null
    ): WhatsAppNotificationLog {
        $customer = $order->customer ?? Customer::find($order->customer_id);
        $phone = $this->formatPhoneNumber($customer?->phone);
        $recipientName = $customer?->name ?? 'کڕیاری بەڕێز';

        // Check idempotency
        $existing = $this->checkIdempotency('sales_order', $order->id, 'DELIVERY_DEBT');
        if ($existing) {
            return $existing;
        }

        $company = $this->getCompanyName();
        $dateStr = now()->format('Y-m-d H:i');
        $orderTotalStr = $this->formatMoney($order->total_amount);
        $receivedStr = $this->formatMoney($receivedAmount);
        $oldDebtStr = $this->formatMoney($previousBalance);
        $newDebtStr = $this->formatMoney($newBalance);

        $message = "🏢 *{$company}*\n"
            . "--------------------------------\n"
            . "🚚 *پسوڵەی گەیاندنی کاڵا*\n"
            . "👤 بەڕێز: {$recipientName}\n"
            . "🔢 پسوڵەی فرۆشتن: {$order->order_number}\n"
            . "📦 کۆی پسوڵە: {$orderTotalStr}\n"
            . "💵 بڕی دراو بە شۆفێر: {$receivedStr}\n"
            . "📊 قەرزی پێشوو: {$oldDebtStr}\n"
            . "📈 کۆی گشتی قەرزی ماوە: *{$newDebtStr}*\n"
            . "🕒 کات و بەروار: {$dateStr}\n"
            . "--------------------------------\n"
            . "سوپاس بۆ متمانەتان.";

        $payload = [
            'order_id' => $order->id,
            'order_number' => $order->order_number,
            'customer_id' => $customer?->id,
            'order_total' => $order->total_amount,
            'received_amount' => $receivedAmount,
            'previous_balance' => $previousBalance,
            'new_balance' => $newBalance,
        ];

        return $this->dispatchMessage(
            recipientPhone: $phone ?? $customer?->phone ?? 'UNKNOWN',
            recipientName: $recipientName,
            notificationType: 'DELIVERY_DEBT',
            referenceType: 'sales_order',
            referenceId: $order->id,
            message: $message,
            customerId: $customer?->id,
            supplierId: null,
            payload: $payload,
            actor: $actor
        );
    }

    /**
     * BR-F05/BR-F06 Fallback: Customer Sales Return WhatsApp Notification
     * Triggered AFTER sales return is successfully committed to keep ledger and customer in sync
     */
    public function sendReturnDebtNotification(
        SalesOrder $order,
        int $previousBalance,
        int $returnAmount,
        int $newBalance,
        ?User $actor = null
    ): WhatsAppNotificationLog {
        $customer = $order->customer ?? Customer::find($order->customer_id);
        $phone = $this->formatPhoneNumber($customer?->phone);
        $recipientName = $customer?->name ?? 'کڕیاری بەڕێز';

        // Check idempotency
        $existing = $this->checkIdempotency('sales_order', $order->id, 'SALES_RETURN');
        if ($existing) {
            return $existing;
        }

        $company = $this->getCompanyName();
        $dateStr = now()->format('Y-m-d H:i');
        $returnAmountStr = $this->formatMoney($returnAmount);
        $oldDebtStr = $this->formatMoney($previousBalance);
        $newDebtStr = $this->formatMoney($newBalance);

        $message = "🏢 *{$company}*\n"
            . "--------------------------------\n"
            . "🔄 *ئاگاداری گەڕاندنەوەی کاڵا*\n"
            . "👤 بەڕێز: {$recipientName}\n"
            . "🔢 پسوڵەی پەیوەندیدار: {$order->order_number}\n"
            . "💰 کۆی پارەی گەڕێندراو: *{$returnAmountStr}*\n"
            . "📊 قەرزی پێشوو: {$oldDebtStr}\n"
            . "📉 قەرزی نوێی ماوە: *{$newDebtStr}*\n"
            . "🕒 کات و بەروار: {$dateStr}\n"
            . "--------------------------------\n"
            . "سوپاس بۆ متمانەتان.";

        $payload = [
            'order_id' => $order->id,
            'order_number' => $order->order_number,
            'customer_id' => $customer?->id,
            'return_amount' => $returnAmount,
            'previous_balance' => $previousBalance,
            'new_balance' => $newBalance,
        ];

        return $this->dispatchMessage(
            recipientPhone: $phone ?? $customer?->phone ?? 'UNKNOWN',
            recipientName: $recipientName,
            notificationType: 'SALES_RETURN',
            referenceType: 'sales_order',
            referenceId: $order->id,
            message: $message,
            customerId: $customer?->id,
            supplierId: null,
            payload: $payload,
            actor: $actor
        );
    }

    /**
     * BR-F07: Supplier Payment / Purchase WhatsApp Notification
     */
    public function sendSupplierPaymentNotification(
        Supplier $supplier,
        int $amount,
        int $previousBalance,
        int $newBalance,
        ?User $actor = null,
        ?string $referenceType = 'supplier_payment',
        ?int $referenceId = null
    ): WhatsAppNotificationLog {
        $phone = $this->formatPhoneNumber($supplier->phone);
        $recipientName = $supplier->name;

        if ($referenceId) {
            $existing = $this->checkIdempotency($referenceType, $referenceId, 'SUPPLIER_PAYMENT');
            if ($existing) {
                return $existing;
            }
        }

        $company = $this->getCompanyName();
        $dateStr = now()->format('Y-m-d H:i');
        $paidStr = $this->formatMoney($amount);
        $oldDebtStr = $this->formatMoney($previousBalance);
        $newDebtStr = $this->formatMoney($newBalance);

        $message = "🏢 *{$company}*\n"
            . "--------------------------------\n"
            . "💳 *تۆمارکردنی پارەدانی کۆمپانیا/سەپڵایەر*\n"
            . "👤 دابینکەری بەڕێز: {$recipientName}\n"
            . "💰 بڕی پارەی دراو: *{$paidStr}*\n"
            . "📊 قەرزی پێشوومان: {$oldDebtStr}\n"
            . "📉 باڵانسی نوێی ماوە: *{$newDebtStr}*\n"
            . "🕒 کات و بەروار: {$dateStr}\n"
            . "--------------------------------\n";

        $payload = [
            'supplier_id' => $supplier->id,
            'amount' => $amount,
            'previous_balance' => $previousBalance,
            'new_balance' => $newBalance,
        ];

        return $this->dispatchMessage(
            recipientPhone: $phone ?? $supplier->phone ?? 'UNKNOWN',
            recipientName: $recipientName,
            notificationType: 'SUPPLIER_PAYMENT',
            referenceType: $referenceType,
            referenceId: $referenceId,
            message: $message,
            customerId: null,
            supplierId: $supplier->id,
            payload: $payload,
            actor: $actor
        );
    }

    /**
     * Dispatch message to provider with fallback and full audit recording
     */
    public function dispatchMessage(
        string $recipientPhone,
        ?string $recipientName,
        string $notificationType,
        ?string $referenceType,
        ?int $referenceId,
        string $message,
        ?int $customerId = null,
        ?int $supplierId = null,
        array $payload = [],
        ?User $actor = null
    ): WhatsAppNotificationLog {
        $idempotencyKey = 'WA-' . md5($recipientPhone . '_' . $notificationType . '_' . $referenceType . '_' . $referenceId . '_' . date('YmdH'));

        $log = WhatsAppNotificationLog::create([
            'customer_id' => $customerId,
            'supplier_id' => $supplierId,
            'recipient_phone' => $recipientPhone,
            'recipient_name' => $recipientName,
            'notification_type' => $notificationType,
            'reference_type' => $referenceType,
            'reference_id' => $referenceId,
            'idempotency_key' => $idempotencyKey,
            'message' => $message,
            'status' => WhatsAppNotificationLog::STATUS_PENDING,
            'provider' => config('services.whatsapp.provider') ?? Setting::getValue('whatsapp_provider', 'unconfigured'),
            'payload' => $payload,
            'last_attempt_at' => now(),
            'created_by' => $actor?->id,
        ]);

        return $this->executeProviderSend($log);
    }

    /**
     * Execute sending via configured provider or record simulated status if unconfigured
     */
    public function executeProviderSend(WhatsAppNotificationLog $log): WhatsAppNotificationLog
    {
        $provider = $log->provider ?? config('services.whatsapp.provider') ?? Setting::getValue('whatsapp_provider', 'unconfigured');
        $apiUrl = config('services.whatsapp.api_url') ?? Setting::getValue('whatsapp_api_url');
        $apiToken = config('services.whatsapp.api_token') ?? Setting::getValue('whatsapp_api_token');

        // Check if provider credentials are set
        if (!$apiUrl || !$apiToken || $provider === 'unconfigured') {
            $log->update([
                'status' => WhatsAppNotificationLog::STATUS_SIMULATED,
                'provider' => 'unconfigured_stub',
                'sent_at' => now(),
                'response' => [
                    'mode' => 'SIMULATED',
                    'note' => 'WhatsApp provider credentials (API URL / Token) are not yet configured in environment or settings. Message logged safely for delivery inspection.',
                ],
            ]);

            Log::info("WhatsApp Notification Recorded (Simulated Mode - Provider Unconfigured): [{$log->recipient_phone}]", [
                'type' => $log->notification_type,
                'message' => $log->message,
            ]);

            return $log;
        }

        try {
            $response = Http::withToken($apiToken)
                ->timeout(10)
                ->post($apiUrl, [
                    'phone' => $log->recipient_phone,
                    'message' => $log->message,
                ]);

            if ($response->successful()) {
                $resData = $response->json() ?? ['raw' => $response->body()];
                $log->update([
                    'status' => WhatsAppNotificationLog::STATUS_SENT,
                    'provider_message_id' => $resData['id'] ?? $resData['message_id'] ?? Str::uuid()->toString(),
                    'response' => $resData,
                    'sent_at' => now(),
                    'error_message' => null,
                ]);
            } else {
                $log->update([
                    'status' => WhatsAppNotificationLog::STATUS_FAILED,
                    'error_message' => 'Provider HTTP ' . $response->status() . ': ' . $response->body(),
                    'response' => $response->json() ?? ['raw' => $response->body()],
                ]);
                Log::warning("WhatsApp send failed for log #{$log->id}: " . $response->body());
            }
        } catch (\Throwable $e) {
            $log->update([
                'status' => WhatsAppNotificationLog::STATUS_FAILED,
                'error_message' => $e->getMessage(),
            ]);
            Log::error("WhatsApp send exception for log #{$log->id}: " . $e->getMessage());
        }

        return $log;
    }

    /**
     * Retry sending a failed WhatsApp message
     */
    public function retryNotification(int $logId, ?User $actor = null): WhatsAppNotificationLog
    {
        $log = WhatsAppNotificationLog::findOrFail($logId);
        $log->increment('retry_count');
        $log->update([
            'last_attempt_at' => now(),
            'status' => WhatsAppNotificationLog::STATUS_PENDING,
        ]);

        return $this->executeProviderSend($log);
    }

    /**
     * Get paginated logs for inspection and reporting (BR-R04)
     */
    public function getLogs(array $filters = [], int $perPage = 20)
    {
        $query = WhatsAppNotificationLog::with(['customer', 'supplier', 'creator'])
            ->latest('id');

        if (!empty($filters['status'])) {
            $query->where('status', $filters['status']);
        }

        if (!empty($filters['notification_type'])) {
            $query->where('notification_type', $filters['notification_type']);
        }

        if (!empty($filters['customer_id'])) {
            $query->where('customer_id', $filters['customer_id']);
        }

        if (!empty($filters['search'])) {
            $search = $filters['search'];
            $query->where(function ($q) use ($search) {
                $q->where('recipient_phone', 'like', "%{$search}%")
                  ->orWhere('recipient_name', 'like', "%{$search}%")
                  ->orWhere('message', 'like', "%{$search}%");
            });
        }

        return $query->paginate($perPage);
    }
}
