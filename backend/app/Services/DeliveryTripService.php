<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\DeliveryTrip;
use App\Models\SalesOrder;
use App\Models\CustomerPayment;
use App\Models\CustomerLedger;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Str;

class DeliveryTripService
{
    protected SalesOrderService $salesOrderService;

    public function __construct(SalesOrderService $salesOrderService)
    {
        $this->salesOrderService = $salesOrderService;
    }

    /**
     * دروستکردنی گەشت و پێدانی پسوڵەکان بە شۆفێر
     */
    public function createTrip(array $data, $user): DeliveryTrip
    {
        return DB::transaction(function () use ($data, $user) {

            $tripNumber = 'TRP-' . strtoupper(Str::random(8));

            // ١. دروستکردنی گەشتەکە
            $trip = DeliveryTrip::create([
                'trip_number' => $tripNumber,
                'driver_id'   => $data['driver_id'],
                'trip_date'   => $data['trip_date'],
                'status'      => 'IN_PROGRESS',
                'started_at'  => now(),
                'total_orders' => count($data['order_ids']),
                'notes'       => $data['notes'] ?? null,
                'created_by'  => $user->id,
            ]);

            // ٢. زیادکردنی پسوڵەکان بۆ ناو گەشتەکە
            foreach ($data['order_ids'] as $index => $orderId) {
                $order = SalesOrder::findOrFail($orderId);

                // دڵنیابوونەوە کە پسوڵەکە پێشتر نەگەیندراوە
                if (in_array($order->status, ['DELIVERED', 'CANCELLED'])) {
                    throw ValidationException::withMessages([
                        'orders' => "پسوڵەی ژمارە {$order->order_number} ناتوانرێت بنێردرێت چونکە دۆخەکەی {$order->status}ـە."
                    ]);
                }

                // گۆڕینی دۆخی پسوڵەکە بۆ (لە ڕێگایە) بە شێوەیەکی دەوڵەتی لەگەڵ نوێکردنەوەی هەموو لۆجیکەکان
                $this->salesOrderService->transitionTo($order, SalesOrder::STATUS_IN_DELIVERY, $user);

                // بەستنەوەی پسوڵەکە بە گەشتەکەوە
                $trip->orders()->create([
                    'sales_order_id' => $order->id,
                    'status'         => 'PENDING',
                    'delivery_order' => $index + 1,
                ]);
            }

            app(\App\Services\AuditService::class)->log([
                'action'      => 'CREATE',
                'entity_type' => 'DeliveryTrip',
                'entity_id'   => $trip->id,
                'table_name'  => 'delivery_trips',
                'old_values'  => null,
                'new_values'  => [
                    'trip_number'  => $trip->trip_number,
                    'driver_id'    => $trip->driver_id,
                    'trip_date'    => $trip->trip_date,
                    'total_orders' => $trip->total_orders,
                ],
                'description' => "گەشتی گەیاندن دروستکرا: {$trip->trip_number} بۆ شۆفێر #{$trip->driver_id}",
                'user'        => $user,
            ]);

            return $trip;
        });
    }

    /**
     * گەیاندنی پسوڵە و وەرگرتنی پارە لەلایەن شۆفێرەوە
     */
    public function deliverOrder(int $tripOrderId, array $data, $user)
    {
        return DB::transaction(function () use ($tripOrderId, $data, $user) {

            // هێنانی ئۆردەری ناو گەشتەکە لەگەڵ پسوڵە سەرەکییەکە و کڕیارەکە
            $tripOrder = \App\Models\DeliveryTripOrder::with(['order.customer', 'trip'])->findOrFail($tripOrderId);
            $salesOrder = $tripOrder->order;
            $customer = $salesOrder->customer;

            if ($tripOrder->status === 'DELIVERED') {
                throw ValidationException::withMessages(['status' => 'ئەم پسوڵەیە پێشتر گەیندراوە.']);
            }

            $receivedAmount = $data['received_amount'];

            // ١. گۆڕینی دۆخی پسوڵەکان بۆ گەیندراو
            $tripOrder->update([
                'status'          => 'DELIVERED',
                'received_amount' => $receivedAmount,
                'delivered_at'    => now(),
                'notes'           => $data['notes'] ?? null,
            ]);

            // گۆڕینی دۆخی پسوڵەکە بۆ گەیندراو بە شێوەیەکی دەوڵەتی (State Machine) و سەلامەت
            $this->salesOrderService->transitionTo($salesOrder, SalesOrder::STATUS_DELIVERED, $user);

            // ٢. زیادکردنی کۆی پارەی وەرگیراو بۆ ناو گەشتەکە
            $tripOrder->trip->increment('total_amount_collected', $receivedAmount);

            // ٣. هەژمارکردنی قەرز (تۆمارکردنی پارەدان ئەگەر پارەی دابوو)
            // ئەگەر شۆفێرەکە پارەی وەرگرت، پێویستە قەرزی کڕیار کەم بکەینەوە
            if ($receivedAmount > 0) {
                // Lock the customer row to prevent race conditions
                $lockedCustomer = Customer::lockForUpdate()->find($customer->id);

                $payment = CustomerPayment::create([
                    'payment_number' => 'PAY-' . strtoupper(Str::random(8)),
                    'customer_id'    => $lockedCustomer->id,
                    'sales_order_id' => $salesOrder->id,
                    'amount'         => $receivedAmount,
                    'payment_method' => 'CASH',
                    'paid_at'        => now()->toDateString(),
                    'collected_by'   => $user->id, // شۆفێرەکە
                    'received_by'    => $user->id,
                ]);

                $newBalance = $lockedCustomer->current_balance - $receivedAmount;

                CustomerLedger::create([
                    'customer_id'    => $lockedCustomer->id,
                    'entry_type'     => 'PAYMENT',
                    'type'           => 'credit',
                    'debit'          => 0,
                    'credit'         => $receivedAmount,
                    'amount'         => $receivedAmount,
                    'balance_before' => $lockedCustomer->current_balance,
                    'balance_after'  => $newBalance,
                    'reference_type' => 'delivery_payment',
                    'reference_id'   => $payment->id,
                    'description'    => "پارەدان لە کاتی گەیاندنی پسوڵەی {$salesOrder->order_number}",
                    'created_by'     => $user->id,
                ]);

                $lockedCustomer->update(['current_balance' => $newBalance]);
            }

            app(\App\Services\AuditService::class)->log([
                'action'      => 'DELIVERY_CONFIRM',
                'entity_type' => 'DeliveryTripOrder',
                'entity_id'   => $tripOrder->id,
                'table_name'  => 'delivery_trip_orders',
                'old_values'  => [
                    'status' => 'PENDING',
                ],
                'new_values'  => [
                    'status'          => 'DELIVERED',
                    'order_number'    => $salesOrder->order_number,
                    'received_amount' => $receivedAmount,
                    'driver_id'       => $user->id,
                ],
                'description' => "پسوڵەی {$salesOrder->order_number} بە سەرکەوتوویی گەیندرا بە کڕیار",
                'user'        => $user,
            ]);

            return $tripOrder;
        });
    }
}
