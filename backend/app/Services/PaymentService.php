<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\CustomerPayment;
use App\Models\CustomerLedger;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class PaymentService
{
    public function collectPayment(array $data, $user): CustomerPayment
    {
        return DB::transaction(function () use ($data, $user) {

            $customer = Customer::lockForUpdate()->findOrFail($data['customer_id']);

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
                'credit'         => $data['amount'],
                'amount'         => $data['amount'],
                'balance_after'  => $newBalance,
                'reference_type' => 'customer_payment',
                'reference_id'   => $payment->id,
                'description'    => 'وەرگرتنی پارە',
                'created_by'     => $user->id,
            ]);

            // ٤. نوێکردنەوەی کۆی قەرزی کڕیار لە تەیبڵی خۆی
            $customer->update([
                'current_balance' => $newBalance
            ]);

            // ئەگەر نۆتیفیکەیشن هەبوو، دەتوانین لێرە نۆتیفیکەیشنی وەتسئاپ/سیستەم بنێرین (BR-F05)

            return $payment;
        });
    }
}
