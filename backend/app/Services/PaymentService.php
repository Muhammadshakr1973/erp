<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\CustomerPayment;
use App\Models\CustomerLedger;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class PaymentService
{
    private function checkPaymentIdempotency(int $customerId, int $amount, ?int $salesOrderId = null): ?CustomerPayment
    {
        return CustomerPayment::where('customer_id', $customerId)
            ->where('amount', $amount)
            ->where('sales_order_id', $salesOrderId)
            ->where('created_at', '>=', now()->subSeconds(90))
            ->orderBy('id', 'desc')
            ->first();
    }

    public function collectPayment(array $data, $user): CustomerPayment
    {
        // 0. Defensive validation for payment amount and order matching
        if (!isset($data['amount']) || (int)$data['amount'] <= 0) {
            throw \Illuminate\Validation\ValidationException::withMessages([
                'amount' => ['بڕی پارە دەبێت ئەرێنی بێت / Payment amount must be a positive integer'],
            ]);
        }

        if (isset($data['sales_order_id']) && $data['sales_order_id']) {
            $salesOrder = \App\Models\SalesOrder::find($data['sales_order_id']);
            if (!$salesOrder || $salesOrder->customer_id != $data['customer_id']) {
                throw \Illuminate\Validation\ValidationException::withMessages([
                    'sales_order_id' => ['دیاریکراوی پسوڵە بۆ ئەم کڕیارە نییە / Sales order does not belong to customer'],
                ]);
            }
        }

        // First check idempotency outside the transaction lock for faster check, or inside
        $existing = $this->checkPaymentIdempotency($data['customer_id'], $data['amount'], $data['sales_order_id'] ?? null);
        if ($existing) {
            return $existing;
        }

        $result = DB::transaction(function () use ($data, $user) {
            $customer = Customer::lockForUpdate()->findOrFail($data['customer_id']);

            // Double check inside the transaction lock to prevent concurrent double-submissions
            $existing = $this->checkPaymentIdempotency($customer->id, $data['amount'], $data['sales_order_id'] ?? null);
            if ($existing) {
                return $existing;
            }

            // دروستکردنی ژمارەی پسوڵەی پارەدان
            $paymentNumber = 'PAY-' . strtoupper(Str::random(8));

            // ١. تۆمارکردنی پارەدانەکە
            $payment = CustomerPayment::create([
                'payment_number' => $paymentNumber,
                'customer_id'    => $customer->id,
                'sales_order_id' => $data['sales_order_id'] ?? null,
                'amount'         => $data['amount'],
                'payment_method' => $data['payment_method'] ?? 'CASH',
                'paid_at'        => now()->toDateString(),
                'collected_by'   => $user->id, // ئەو کەسەی پارەکەی وەرگرت (مەندوب/شۆفێر)
                'received_by'    => $user->id,
                'notes'          => $data['notes'] ?? null,
            ]);

            // ٢. هەژمارکردنی قەرزی نوێی کڕیارەکە (Balance After)
            $previousBalance = $customer->current_balance;
            $newBalance = $previousBalance - $data['amount']; // پارەی داوە، قەرزەکەی کەم دەبێتەوە

            // ٣. تۆمارکردنی لە لیجەر (Ledger Principle) بۆ مێژوو
            CustomerLedger::create([
                'customer_id'    => $customer->id,
                'entry_type'     => 'PAYMENT',
                'type'           => 'credit', // Credit واتە پارەهاتنە ناوەوە / کەمبوونەوەی قەرز
                'debit'          => 0,
                'credit'         => $data['amount'],
                'amount'         => $data['amount'],
                'balance_before' => $previousBalance,
                'balance_after'  => $newBalance,
                'reference_type' => 'customer_payment',
                'reference_id'   => $payment->id,
                'description'    => $data['notes'] ?? 'وەرگرتنی پارە',
                'created_by'     => $user->id,
            ]);

            // ٤. نوێکردنەوەی کۆی قەرزی کڕیار لە تەیبڵی خۆی
            $customer->update([
                'current_balance' => $newBalance
            ]);

            // ٥. تۆمارکردنی جوڵەکە لە لۆگی چالاکیەکان (Audit Trail)
            app(AuditService::class)->log([
                'action'      => 'PAYMENT',
                'entity_type' => 'CustomerPayment',
                'entity_id'   => $payment->id,
                'table_name'  => 'customer_payments',
                'old_values'  => [
                    'customer_balance' => $previousBalance,
                ],
                'new_values'  => [
                    'payment_number'   => $payment->payment_number,
                    'customer_id'      => $customer->id,
                    'customer_name'    => $customer->name,
                    'amount'           => $payment->amount,
                    'payment_method'   => $payment->payment_method,
                    'customer_balance' => $newBalance,
                ],
                'description' => "پارەدانی کڕیار تۆمارکرا: {$payment->payment_number} بە بڕی {$payment->amount} بۆ کڕیار {$customer->name}",
                'user'        => $user,
            ]);

            return [
                'payment' => $payment,
                'previous_balance' => $previousBalance,
                'new_balance' => $newBalance,
            ];
        });

        // Trigger Notifications ONLY AFTER financial transaction is committed
        app(NotificationService::class)->notifyPaymentReceived($result['payment'], $user);
        app(WhatsAppService::class)->sendCustomerPaymentNotification(
            $result['payment'],
            $result['previous_balance'],
            $result['new_balance'],
            $user
        );

        return $result['payment'];
    }
}
