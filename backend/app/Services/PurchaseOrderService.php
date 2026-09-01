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
    public function receiveOrder(PurchaseOrder $order, $user, ?array $receivingItems = null): PurchaseOrder
    {
        return DB::transaction(function () use ($order, $user, $receivingItems) {
            // Lock the purchase order to prevent concurrent receiving race conditions
            $lockedOrder = PurchaseOrder::lockForUpdate()->findOrFail($order->id);

            if ($lockedOrder->status === PurchaseOrder::STATUS_CANCELLED) {
                throw ValidationException::withMessages(['status' => 'ناتوانرێت پسوڵەی هەڵوەشاوە وەربگیرێت.']);
            }

            // Check if all items are already fully received
            $allItems = $lockedOrder->items()->get();
            $isAlreadyFullyReceived = $allItems->every(function ($it) {
                return $it->received_quantity >= $it->quantity;
            });

            if ($lockedOrder->status === PurchaseOrder::STATUS_RECEIVED || $isAlreadyFullyReceived) {
                throw ValidationException::withMessages(['status' => 'ئەم پسوڵەی کڕینە پێشتر بە تەواوی وەرگیراوە.']);
            }

            $supplier = Supplier::lockForUpdate()->findOrFail($lockedOrder->supplier_id);

            // Build receiving quantities map: item_id => qty_to_receive
            $receivingMap = [];

            if (empty($receivingItems)) {
                // Full receiving mode (default): receive all remaining quantities
                foreach ($allItems as $item) {
                    $remaining = max(0, $item->quantity - $item->received_quantity);
                    if ($remaining > 0) {
                        $receivingMap[$item->id] = $remaining;
                    }
                }
            } else {
                // Partial/specified receiving mode
                foreach ($receivingItems as $reqItem) {
                    $productId = $reqItem['product_id'] ?? null;
                    $itemId = $reqItem['item_id'] ?? null;
                    $qtyToReceive = (int) ($reqItem['quantity'] ?? 0);

                    if ($qtyToReceive <= 0) {
                        throw ValidationException::withMessages(['items' => 'بڕی وەرگیراو دەبێت لە ٠ گەورەتر بێت.']);
                    }

                    $matchingItem = $allItems->first(function ($it) use ($productId, $itemId) {
                        if ($itemId !== null && (int)$it->id === (int)$itemId) {
                            return true;
                        }
                        if ($productId !== null && (int)$it->product_id === (int)$productId) {
                            return true;
                        }
                        return false;
                    });

                    if (!$matchingItem) {
                        throw ValidationException::withMessages(['items' => 'کاڵای دیاریکراو لەم پسوڵەی کڕینەدا بوونی نییە.']);
                    }

                    $remaining = $matchingItem->quantity - $matchingItem->received_quantity;
                    if ($remaining <= 0) {
                        throw ValidationException::withMessages(['items' => "کاڵای (کۆد #{$matchingItem->product_id}) بە تەواوی وەرگیراوە."]);
                    }

                    if ($qtyToReceive > $remaining) {
                        throw ValidationException::withMessages(['items' => "بڕی وەرگیراو ({$qtyToReceive}) زیاترە لە بڕی مابووەوە ({$remaining})."]);
                    }

                    $receivingMap[$matchingItem->id] = ($receivingMap[$matchingItem->id] ?? 0) + $qtyToReceive;
                }
            }

            if (empty($receivingMap)) {
                throw ValidationException::withMessages(['items' => 'هیچ کاڵایەک بۆ وەرگرتن نەدۆزرایەوە.']);
            }

            // Sort items deterministically by product_id ASC to eliminate deadlock risks
            $sortedItems = $allItems->sortBy('product_id');
            $batchTotalAmount = 0;

            foreach ($sortedItems as $item) {
                $qtyToReceive = $receivingMap[$item->id] ?? 0;
                if ($qtyToReceive <= 0) {
                    continue;
                }

                // Historical cost calculated from agreed unit_cost on the PO item
                $itemCost = $qtyToReceive * $item->unit_cost;
                $batchTotalAmount += $itemCost;

                // 1. Lock stock row and adjust stock
                $warehouseStock = WarehouseStock::lockForUpdate()->firstOrCreate(
                    ['warehouse_id' => $lockedOrder->warehouse_id, 'product_id' => $item->product_id],
                    ['quantity' => 0, 'reserved_quantity' => 0]
                );

                $warehouseStock->adjustStock(
                    $qtyToReceive,
                    'PURCHASE',
                    $user->id,
                    'purchase_order',
                    $lockedOrder->id
                );

                // 2. Update received_quantity on item
                $newReceived = $item->received_quantity + $qtyToReceive;
                $item->update(['received_quantity' => $newReceived]);
            }

            // 3. Post to SupplierLedger for the received amount
            $previousBalance = (int) $supplier->current_balance;
            $newBalance = $previousBalance + $batchTotalAmount;

            SupplierLedger::create([
                'supplier_id'    => $supplier->id,
                'entry_type'     => 'PURCHASE',
                'type'           => 'credit',
                'debit'          => 0,
                'credit'         => $batchTotalAmount,
                'amount'         => $batchTotalAmount,
                'balance_before' => $previousBalance,
                'balance_after'  => $newBalance,
                'reference_type' => 'purchase_order',
                'reference_id'   => $lockedOrder->id,
                'description'    => "کڕینی کاڵا بە پسوڵەی {$lockedOrder->order_number}",
                'created_by'     => $user->id,
            ]);

            $supplier->update(['current_balance' => $newBalance]);

            // 4. Check if all items are fully received
            $freshItems = $lockedOrder->items()->get();
            $isFullyReceived = $freshItems->every(function ($it) {
                return $it->received_quantity >= $it->quantity;
            });

            if ($isFullyReceived) {
                $lockedOrder->update([
                    'status'      => 'RECEIVED',
                    'received_at' => now(),
                ]);

                // Close connected purchase requirements
                $lockedOrder->requirements()->update(['status' => 'CLOSED']);
            }

            app(\App\Services\AuditService::class)->log([
                'action'      => 'RECEIVE',
                'entity_type' => 'PurchaseOrder',
                'entity_id'   => $lockedOrder->id,
                'table_name'  => 'purchase_orders',
                'old_values'  => [
                    'status' => $lockedOrder->getOriginal('status'),
                ],
                'new_values'  => [
                    'status'            => $lockedOrder->status,
                    'order_number'      => $lockedOrder->order_number,
                    'supplier_id'       => $supplier->id,
                    'supplier_balance'  => $newBalance,
                    'received_amount'   => $batchTotalAmount,
                    'is_fully_received' => $isFullyReceived,
                ],
                'description' => "کاڵاکانی پسوڵەی کڕین {$lockedOrder->order_number} (بڕی {$batchTotalAmount}) بە سەرکەوتوویی وەرگیران لە کۆگا",
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
