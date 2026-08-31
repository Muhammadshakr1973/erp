<?php

namespace App\Services;

use App\Models\PurchaseOrder;
use App\Models\Supplier;
use App\Models\WarehouseStock;
use App\Models\StockTransaction;
use App\Models\SupplierLedger;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Str;

class PurchaseOrderService
{
    /**
     * دروستکردنی پسوڵەی کڕین (تەنها داواکاری - ستۆک زیاد ناکات)
     */
    public function createOrder(array $data, $user): PurchaseOrder
    {
        return DB::transaction(function () use ($data, $user) {

            $orderNumber = 'PO-' . strtoupper(Str::random(8));
            $totalAmount = 0;

            $order = PurchaseOrder::create([
                'order_number' => $orderNumber,
                'supplier_id'  => $data['supplier_id'],
                'warehouse_id' => $data['warehouse_id'],
                'status'       => 'DRAFT',
                'notes'        => $data['notes'] ?? null,
                'created_by'   => $user->id,
                'total_amount' => 0, // دواتر ئەپدەیت دەکرێت
            ]);

            foreach ($data['items'] as $item) {
                $totalCost = $item['quantity'] * $item['unit_cost'];
                $totalAmount += $totalCost;

                $order->items()->create([
                    'product_id' => $item['product_id'],
                    'quantity'   => $item['quantity'],
                    'unit_cost'  => $item['unit_cost'],
                    'total_cost' => $totalCost,
                ]);
            }

            $order->update(['total_amount' => $totalAmount]);

            app(\App\Services\AuditService::class)->log([
                'action'      => 'CREATE',
                'entity_type' => 'PurchaseOrder',
                'entity_id'   => $order->id,
                'table_name'  => 'purchase_orders',
                'old_values'  => null,
                'new_values'  => [
                    'order_number' => $order->order_number,
                    'supplier_id'  => $order->supplier_id,
                    'warehouse_id' => $order->warehouse_id,
                    'total_amount' => $totalAmount,
                    'items_count'  => count($data['items']),
                ],
                'description' => "پسوڵەی کڕین دروستکرا: {$order->order_number} بە بڕی {$totalAmount}",
                'user'        => $user,
            ]);

            return $order;
        });
    }

    /**
     * وەرگرتنی کاڵاکان لە کۆگا (زیادکردنی ستۆک و تۆمارکردنی قەرزی کۆمپانیا)
     */
    public function receiveOrder(PurchaseOrder $order, $user): PurchaseOrder
    {
        return DB::transaction(function () use ($order, $user) {
            // Lock the purchase order to prevent concurrent receiving race conditions
            $lockedOrder = PurchaseOrder::lockForUpdate()->findOrFail($order->id);

            if ($lockedOrder->status === PurchaseOrder::STATUS_RECEIVED || $lockedOrder->status === PurchaseOrder::STATUS_RECEIVED_LOWER) {
                return $lockedOrder;
            }

            if ($lockedOrder->status === PurchaseOrder::STATUS_CANCELLED) {
                throw ValidationException::withMessages(['status' => 'ناتوانرێت پسوڵەی هەڵوەشاوە وەربگیرێت.']);
            }

            $supplier = Supplier::lockForUpdate()->findOrFail($lockedOrder->supplier_id);

            // Sort items deterministically by product_id ASC to eliminate deadlock risks
            $sortedItems = $lockedOrder->items->sortBy('product_id');

            foreach ($sortedItems as $item) {
                // ١. زیادکردنی ستۆک لە کۆگا
                $warehouseStock = WarehouseStock::lockForUpdate()->firstOrCreate(
                    ['warehouse_id' => $lockedOrder->warehouse_id, 'product_id' => $item->product_id],
                    ['quantity' => 0, 'reserved_quantity' => 0]
                );

                $warehouseStock->adjustStock(
                    $item->quantity,
                    'PURCHASE',
                    $user->id,
                    'purchase_order',
                    $lockedOrder->id
                );

                // نوێکردنەوەی بڕی وەرگیراو لەناو ئایتمەکە
                $item->update(['received_quantity' => $item->quantity]);
            }

            // ٣. هەژمارکردنی قەرزی کۆمپانیا (ئێمە قەرزدار دەبین)
            $previousBalance = (int) $supplier->current_balance;
            $newBalance = $previousBalance + $lockedOrder->total_amount; // قەرزەکەمان زیاد دەکات

            SupplierLedger::create([
                'supplier_id'    => $supplier->id,
                'entry_type'     => 'PURCHASE',
                'type'           => 'credit',
                'debit'          => 0,
                'credit'         => $lockedOrder->total_amount,
                'amount'         => $lockedOrder->total_amount,
                'balance_before' => $previousBalance,
                'balance_after'  => $newBalance,
                'reference_type' => 'purchase_order',
                'reference_id'   => $lockedOrder->id,
                'description'    => "کڕینی کاڵا بە پسوڵەی {$lockedOrder->order_number}",
                'created_by'     => $user->id,
            ]);

            // نوێکردنەوەی بالانسی سەپڵایەر لە داتابەیسدا
            $supplier->update(['current_balance' => $newBalance]);

            // ٤. گۆڕینی دۆخی پسوڵەکە بۆ RECEIVED
            $lockedOrder->update([
                'status'      => 'RECEIVED',
                'received_at' => now(),
            ]);

            // دۆخی داواکارییەکانی کڕینی پەیوەستکراو دادەخرێت
            $lockedOrder->requirements()->update(['status' => 'CLOSED']);

            app(\App\Services\AuditService::class)->log([
                'action'      => 'RECEIVE',
                'entity_type' => 'PurchaseOrder',
                'entity_id'   => $lockedOrder->id,
                'table_name'  => 'purchase_orders',
                'old_values'  => [
                    'status' => 'DRAFT',
                ],
                'new_values'  => [
                    'status'           => 'RECEIVED',
                    'order_number'     => $lockedOrder->order_number,
                    'supplier_id'      => $supplier->id,
                    'supplier_balance' => $newBalance,
                    'total_amount'     => $lockedOrder->total_amount,
                ],
                'description' => "کاڵاکانی پسوڵەی کڕین {$lockedOrder->order_number} بە سەرکەوتوویی وەرگیران لە کۆگا و ستۆک زیادکرا",
                'user'        => $user,
            ]);

            return $lockedOrder;
        });
    }

    /**
     * هەڵوەشاندنەوەی پسوڵەی کڕین
     */
    public function cancelOrder(PurchaseOrder $order, $user): PurchaseOrder
    {
        return DB::transaction(function () use ($order, $user) {
            $lockedOrder = PurchaseOrder::lockForUpdate()->findOrFail($order->id);

            if ($lockedOrder->status === PurchaseOrder::STATUS_CANCELLED) {
                return $lockedOrder;
            }

            if ($lockedOrder->status === PurchaseOrder::STATUS_RECEIVED || $lockedOrder->status === PurchaseOrder::STATUS_RECEIVED_LOWER) {
                throw ValidationException::withMessages(['status' => 'ناتوانرێت پسوڵەی کڕین هەڵبوەشێنرێتەوە چونکە پێشتر وەرگیراوە.']);
            }

            $oldStatus = $lockedOrder->status;
            $lockedOrder->update(['status' => PurchaseOrder::STATUS_CANCELLED]);

            // داواکارییەکانی کڕین دەکرێنەوە بۆ ئەوەی دووبارە بکرێن بە پسوڵە ئەگەر پێویست بکات
            $lockedOrder->requirements()->update([
                'status' => 'OPEN',
                'purchase_order_id' => null
            ]);

            app(\App\Services\AuditService::class)->log([
                'action'      => 'CANCEL',
                'entity_type' => 'PurchaseOrder',
                'entity_id'   => $lockedOrder->id,
                'table_name'  => 'purchase_orders',
                'old_values'  => ['status' => $oldStatus],
                'new_values'  => ['status' => PurchaseOrder::STATUS_CANCELLED],
                'description' => "پسوڵەی کڕینی {$lockedOrder->order_number} هەڵوەشێنرایەوە",
                'user'        => $user,
            ]);

            return $lockedOrder;
        });
    }
}
