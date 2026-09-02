<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\CustomerPayment;
use App\Models\CustomerLedger;
use App\Models\SalesOrder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class PaymentService
{
    public function collectPayment(array $data, $user): CustomerPayment
    {
        // 0. Defensive validation for payment amount and order matching
        if (!isset($data['amount']) || (int)$data['amount'] <= 0) {
            throw ValidationException::withMessages([
                'amount' => ['بڕی پارە دەبێت ئەرێنی بێت / Payment amount must be a positive integer'],
            ]);
        }

        if (isset($data['sales_order_id']) && $data['sales_order_id']) {
            $salesOrder = SalesOrder::find($data['sales_order_id']);
            if (!$salesOrder || $salesOrder->customer_id != $data['customer_id']) {
                throw ValidationException::withMessages([
                    'sales_order_id' => ['دیاریکراوی پسوڵە بۆ ئەم کڕیارە نییە / Sales order does not belong to customer'],
                ]);
            }
        }

        $result = DB::transaction(function () use ($data, $user) {
            $customer = Customer::lockForUpdate()->findOrFail($data['customer_id']);
            $previousBalance = (int) $customer->current_balance;
            $paymentAmount = (int) $data['amount'];

            // Overpayment Protection: customer cannot pay more than their total outstanding debt
            if ($paymentAmount > $previousBalance) {
                throw ValidationException::withMessages([
                    'amount' => ['بڕی پارەدان زیاترە لە کۆی قەرزی کڕیار / Payment amount exceeds customer outstanding debt'],
                ]);
            }

            // If payment is linked to a specific Sales Order, enforce remaining order balance check
            if (isset($data['sales_order_id']) && $data['sales_order_id']) {
                $salesOrder = SalesOrder::lockForUpdate()->find($data['sales_order_id']);
                if (!$salesOrder || $salesOrder->customer_id != $customer->id) {
                    throw ValidationException::withMessages([
                        'sales_order_id' => ['دیاریکراوی پسوڵە بۆ ئەم کڕیارە نییە / Sales order does not belong to customer'],
                    ]);
                }

                $totalPaidForOrder = (int) CustomerPayment::where('sales_order_id', $salesOrder->id)->sum('amount');
                $orderTotal = (int) $salesOrder->total_amount;
                $orderRemaining = max(0, $orderTotal - $totalPaidForOrder);

                if ($paymentAmount > $orderRemaining) {
                    throw ValidationException::withMessages([
                        'amount' => ['بڕی پارەدان زیاترە لە قەرزی ماوەی ئەم پسوڵەیە / Payment amount exceeds remaining order balance'],
                    ]);
                }
            }

            // دروستکردنی ژمارەی پسوڵەی پارەدان
            $paymentNumber = 'PAY-' . strtoupper(Str::random(8));

            // ١. تۆمارکردنی پارەدانەکە
            $payment = CustomerPayment::create([
                'payment_number' => $paymentNumber,
                'customer_id'    => $customer->id,
                'sales_order_id' => $data['sales_order_id'] ?? null,
                'amount'         => $paymentAmount,
                'payment_method' => isset($data['payment_method']) ? strtoupper($data['payment_method']) : 'CASH',
                'paid_at'        => now()->toDateString(),
                'collected_by'   => $user->id,
                'received_by'    => $user->id,
                'notes'          => $data['notes'] ?? null,
            ]);

            // ٢. هەژمارکردنی قەرزی نوێی کڕیارەکە (Balance After)
            $newBalance = $previousBalance - $paymentAmount;

            // ٣. تۆمارکردنی لە لیجەر (Ledger Principle) بۆ مێژوو
            CustomerLedger::create([
                'customer_id'    => $customer->id,
                'entry_type'     => 'PAYMENT',
                'type'           => 'credit',
                'debit'          => 0,
                'credit'         => $paymentAmount,
                'amount'         => $paymentAmount,
                'balance_before' => $previousBalance,
                'balance_after'  => $newBalance,
                'reference_type' => 'customer_payment',
                'reference_id'   => $payment->id,
                'description'    => $data['notes'] ?? 'وەرگرتنی پارە',
                'created_by'     => $user->id,
            ]);

            // ٤. نوێکردنەوەی کۆی قەرزی کڕیار لە تەیبڵی خۆی
            $customer->update([
                'current_balance' => $newBalance,
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
