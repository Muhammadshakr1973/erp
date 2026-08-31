<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\CustomerLedger;
use App\Models\Product;
use App\Models\SalesOrder;
use App\Models\SalesOrderItem;
use App\Models\SalesReturn;
use App\Models\SalesReturnItem;
use App\Models\WarehouseStock;
use App\Models\StockTransaction;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Str;

class SalesReturnService
{
    protected AuditService $auditService;
    protected NotificationService $notificationService;
    protected WhatsAppService $whatsAppService;

    public function __construct(
        AuditService $auditService,
        NotificationService $notificationService,
        WhatsAppService $whatsAppService
    ) {
        $this->auditService = $auditService;
        $this->notificationService = $notificationService;
        $this->whatsAppService = $whatsAppService;
    }

    /**
     * گەڕاندنەوەی کاڵاکانی پسوڵەی فرۆشتن بە شێوەیەکی تۆکمە و سەلامەت
     */
    public function createReturn(array $data, $user): SalesReturn
    {
        return DB::transaction(function () use ($data, $user) {
            $orderId = $data['sales_order_id'];
            
            // ١. قفڵکردنی پسوڵەی سەرەکی
            $order = SalesOrder::with(['customer', 'items'])->lockForUpdate()->findOrFail($orderId);

            // پسوڵەی DELIVERED تەنها دەکرێت ڕاگەڕێنرێتەوە (Return) ناتوانرێت سڕدرێتەوە
            if ($order->status !== SalesOrder::STATUS_DELIVERED) {
                throw ValidationException::withMessages([
                    'sales_order_id' => 'تەنها پسوڵەی گەیندراو (DELIVERED) دەکرێت ڕاگەڕێنرێتەوە.',
                ]);
            }

            // ٢. قفڵکردنی کڕیار بۆ دڵنیابوون لە پاراستنی دروستی باڵانس و ڕێگری لە هاوکاتی
            $customer = Customer::lockForUpdate()->findOrFail($order->customer_id);

            $returnNumber = 'RET-' . strtoupper(Str::random(8));
            
            // دروستکردنی کۆمەڵەی گەڕانەوەی سەرەکی (بەڵام جارێ کۆی گشتییەکە سفرە)
            $salesReturn = SalesReturn::create([
                'return_number'       => $returnNumber,
                'sales_order_id'      => $order->id,
                'customer_id'         => $customer->id,
                'reason'              => $data['reason'] ?? 'Customer Return',
                'status'              => SalesReturn::STATUS_COMPLETED,
                'total_return_amount' => 0,
                'created_by'          => $user->id,
            ]);

            $totalReturnAmount = 0;
            $itemsData = $data['items'];

            foreach ($itemsData as $itemInput) {
                $orderItemId = $itemInput['sales_order_item_id'];
                $returnedQty = (int)$itemInput['quantity'];

                if ($returnedQty <= 0) {
                    throw ValidationException::withMessages([
                        'items' => 'بڕی گەڕێندراو دەبێت لە ٠ زیاتر بێت.',
                    ]);
                }

                // دۆزینەوەی ئایتمی پسوڵە و دڵنیابوون لەوەی سەر بەم پسوڵەیەیە
                $orderItem = SalesOrderItem::where('sales_order_id', $order->id)
                    ->findOrFail($orderItemId);

                // پشکنینی بڕی گەڕێندراوەی پێشوو بۆ ئەم ئایتمە
                $alreadyReturned = SalesReturnItem::whereHas('salesReturn', function ($q) use ($order) {
                    $q->where('sales_order_id', $order->id)
                      ->whereIn('status', [SalesReturn::STATUS_COMPLETED, SalesReturn::STATUS_COMPLETED_LOWER]);
                })->where('sales_order_item_id', $orderItemId)->sum('quantity');

                $availableToReturn = $orderItem->quantity - $alreadyReturned;

                if ($returnedQty > $availableToReturn) {
                    throw ValidationException::withMessages([
                        'items' => "بڕی گەڕێندراو ({$returnedQty}) ناتوانێت لە بڕی گەڕەنەوەی بەردەست ({$availableToReturn}) زیاتر بێت بۆ کاڵای '{$orderItem->product?->name}'.",
                    ]);
                }

                $unitPrice = (int)$orderItem->unit_price;
                $itemTotalAmount = $returnedQty * $unitPrice;
                $totalReturnAmount += $itemTotalAmount;

                // ٣. گۆڕانکاری لە ستۆک (گەڕانەوە بۆ کۆگا)
                $warehouseStock = WarehouseStock::lockForUpdate()->where([
                    'warehouse_id' => $order->warehouse_id,
                    'product_id'   => $orderItem->product_id
                ])->first();

                if (!$warehouseStock) {
                    // ئەگەر ستۆکەکە لەو کۆگایە نەبوو، دروستی بکە
                    $warehouseStock = WarehouseStock::create([
                        'warehouse_id'      => $order->warehouse_id,
                        'product_id'        => $orderItem->product_id,
                        'quantity'          => 0,
                        'reserved_quantity' => 0,
                        'min_stock_level'   => 5,
                        'average_cost'      => $orderItem->cost_price ?? 0,
                    ]);
                    $warehouseStock = WarehouseStock::lockForUpdate()->find($warehouseStock->id);
                }

                // زیادکردنی ستۆکی فیزیکی کاڵاکە چونکە گەڕاوەتەوە کۆگا
                $warehouseStock->adjustStock(
                    $returnedQty,
                    'RETURN',
                    $user->id,
                    'sales_return',
                    $salesReturn->id,
                    "گەڕانەوەی کاڵا بۆ پسوڵەی #{$order->order_number}"
                );

                // ٤. تۆمارکردنی ئایتمی گەڕانەوە
                SalesReturnItem::create([
                    'sales_return_id'     => $salesReturn->id,
                    'sales_order_item_id' => $orderItemId,
                    'product_id'          => $orderItem->product_id,
                    'quantity'            => $returnedQty,
                    'unit_price'          => $unitPrice,
                    'total'               => $itemTotalAmount,
                    'reason'              => $itemInput['reason'] ?? null,
                ]);
            }

            // ٥. نوێکردنەوەی کۆی گشتی پارەی گەڕانەوە لەسەر پسوڵەکە
            $salesReturn->update([
                'total_return_amount' => $totalReturnAmount,
            ]);

            // ٦. کەمکردنەوەی باڵانسی کڕیار (کەمکردنەوەی قەرز)
            $previousBalance = $customer->current_balance;
            $newBalance = $previousBalance - $totalReturnAmount;
            $customer->current_balance = $newBalance;
            $customer->save();

            // ٧. تۆمارکردنی ڕۆژنامەی ژمێریاری (Ledger)
            $ledgerEntry = CustomerLedger::create([
                'customer_id'    => $customer->id,
                'entry_type'     => 'RETURN',
                'type'           => 'credit',
                'debit'          => 0,
                'credit'         => $totalReturnAmount,
                'amount'         => $totalReturnAmount,
                'balance_before' => $previousBalance,
                'balance_after'  => $newBalance,
                'reference_type' => 'sales_return',
                'reference_id'   => $salesReturn->id,
                'description'    => "گەڕانەوەی کاڵا بۆ پسوڵەی فرۆشتنی ژمارە #{$order->order_number}",
            ]);

            // ٨. تۆمارکردنی مێژووی ژمێریاری (Audit Log)
            $this->auditService->logFinancialMovement(
                'SALES_RETURN',
                'SalesReturn',
                $salesReturn->id,
                $totalReturnAmount,
                "گەڕانەوەی کاڵا بۆ پسوڵەی #{$order->order_number} بە کۆی گشتی " . number_format($totalReturnAmount, 0) . " د.ع لەلایەن کڕیار '{$customer->name}'",
                [
                    'old_values' => ['current_balance' => $previousBalance],
                    'new_values' => [
                        'current_balance' => $newBalance,
                        'return_number'   => $salesReturn->return_number,
                    ]
                ],
                $user
            );

            // بنێرەوە بۆ بەکارهێنانی دەرەوەی ترانزاکشنەکە
            return $salesReturn;
        });
    }
}
