<?php

namespace App\Services;

use App\Models\PurchaseOrder;
use App\Models\Supplier;
use App\Models\WarehouseStock;
use App\Models\StockTransaction;
use App\Models\SupplierLedger;
use App\Models\SupplierPayment;
use App\Models\PurchaseRequirement;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Str;

class PurchaseOrderService
{
    /**
     * دروستکردنی پسوڵەی کڕین (دەتوانێت بەخۆکاری کاڵاکان وەربگرێت و قەرز و بڕی دراو تۆمار بکات)
     */
    public function createOrder(array $data, $user): PurchaseOrder
    {
        return DB::transaction(function () use ($data, $user) {
            // ئەگەر دابینکەر دیاری نەکرابوو، دابینکەری گشتی/بێناو بەکاردەهێنرێت
            $supplierId = !empty($data['supplier_id']) ? (int) $data['supplier_id'] : null;
            if (!$supplierId) {
                $defaultSupplier = Supplier::firstOrCreate(
                    ['name' => 'دابینکەری گشتی (بێناو)'],
                    [
                        'phone' => null,
                        'current_balance' => 0,
                        'created_by' => $user->id,
                    ]
                );
                $supplierId = $defaultSupplier->id;
            }

            $supplier = Supplier::lockForUpdate()->findOrFail($supplierId);

            $orderNumber = 'PO-' . strtoupper(Str::random(8));
            $totalAmount = 0;
            $autoReceive = isset($data['auto_receive']) ? (bool) $data['auto_receive'] : true;
            $paidAmount = isset($data['paid_amount']) ? max(0, (int) $data['paid_amount']) : 0;

            $initialStatus = $autoReceive ? PurchaseOrder::STATUS_RECEIVED : PurchaseOrder::STATUS_DRAFT;

            $orderData = [
                'order_number' => $orderNumber,
                'supplier_id'  => $supplierId,
                'warehouse_id' => $data['warehouse_id'],
                'status'       => $initialStatus,
                'notes'        => $data['notes'] ?? null,
                'created_by'   => $user->id,
                'total_amount' => 0,
                'received_at'  => $autoReceive ? now() : null,
            ];

            if (Schema::hasColumn('purchase_orders', 'paid_amount')) {
                $orderData['paid_amount'] = $paidAmount;
            }

            $order = PurchaseOrder::create($orderData);

            // ئایتمەکانی پسوڵەی کڕین
            $itemsList = $data['items'] ?? [];
            foreach ($itemsList as $item) {
                $qty = (int) $item['quantity'];
                $unitCost = (int) $item['unit_cost'];
                $lineTotal = $qty * $unitCost;
                $totalAmount += $lineTotal;

                $order->items()->create([
                    'product_id'        => $item['product_id'],
                    'quantity'          => $qty,
                    'unit_cost'         => $unitCost,
                    'total_cost'        => $lineTotal,
                    'received_quantity' => $autoReceive ? $qty : 0,
                ]);

                // ئەگەر auto_receive چالاک بێت، ڕاستەوخۆ دەچێتە ستۆکی کۆگا
                if ($autoReceive) {
                    $warehouseStock = WarehouseStock::lockForUpdate()->firstOrCreate(
                        ['warehouse_id' => $data['warehouse_id'], 'product_id' => $item['product_id']],
                        ['quantity' => 0, 'reserved_quantity' => 0]
                    );

                    $warehouseStock->adjustStock(
                        $qty,
                        'PURCHASE',
                        $user->id,
                        'purchase_order',
                        $order->id
                    );

                    // نوێکردنەوەی نرخی تێچووی کاڵا و دابینکەر لە خشتەی کاڵاکان
                    $product = \App\Models\Product::find($item['product_id']);
                    if ($product) {
                        $prodUpdate = ['cost_price' => $unitCost];
                        if ($supplierId) {
                            $prodUpdate['supplier_id'] = $supplierId;
                        }
                        $product->update($prodUpdate);
                    }
                }
            }

            // ئەپدەیتکردنی کۆی گشتی و بڕی دراو
            $updatePayload = ['total_amount' => $totalAmount];
            if (Schema::hasColumn('purchase_orders', 'paid_amount')) {
                $updatePayload['paid_amount'] = min($paidAmount, $totalAmount);
            }
            $order->update($updatePayload);

            // ئەگەر autoReceive بێت، مامەڵەی حیساباتی قەرز و بڕی پارەی دراو ئەنجام دەدرێت
            if ($autoReceive && $totalAmount > 0) {
                $previousBalance = (int) $supplier->current_balance;
                $balanceAfterPurchase = $previousBalance + $totalAmount;

                // ١. تۆمارکردنی کڕین لە دەفتەری حیساباتی دابینکەر (زیادبوونی قەرز)
                SupplierLedger::create([
                    'supplier_id'    => $supplier->id,
                    'entry_type'     => 'PURCHASE',
                    'type'           => 'credit',
                    'debit'          => 0,
                    'credit'         => $totalAmount,
                    'amount'         => $totalAmount,
                    'balance_before' => $previousBalance,
                    'balance_after'  => $balanceAfterPurchase,
                    'reference_type' => 'purchase_order',
                    'reference_id'   => $order->id,
                    'description'    => "کڕینی کاڵا بە پسوڵەی {$order->order_number}",
                    'created_by'     => $user->id,
                ]);

                $finalBalance = $balanceAfterPurchase;

                // ٢. ئەگەر پارەی نەقد درابێت، وەک پارەدان تۆمار دەکرێت و لە قەرز کەم دەبێتەوە
                if ($paidAmount > 0) {
                    $effectivePaid = min($paidAmount, $totalAmount);
                    $finalBalance = $balanceAfterPurchase - $effectivePaid;

                    SupplierPayment::create([
                        'supplier_id'       => $supplier->id,
                        'purchase_order_id' => $order->id,
                        'amount'            => $effectivePaid,
                        'payment_method'    => 'cash',
                        'paid_at'           => now()->toDateString(),
                        'notes'             => "پارەدانی نەقد بۆ پسوڵەی {$order->order_number}",
                        'created_by'        => $user->id,
                    ]);

                    SupplierLedger::create([
                        'supplier_id'    => $supplier->id,
                        'entry_type'     => 'PAYMENT',
                        'type'           => 'debit',
                        'debit'          => $effectivePaid,
                        'credit'         => 0,
                        'amount'         => $effectivePaid,
                        'balance_before' => $balanceAfterPurchase,
                        'balance_after'  => $finalBalance,
                        'reference_type' => 'supplier_payment',
                        'reference_id'   => $order->id,
                        'description'    => "پارەدانی پسوڵەی کڕین {$order->order_number}",
                        'created_by'     => $user->id,
                    ]);
                }

                $supplier->update(['current_balance' => $finalBalance]);

                // ٣. داخستنی داواکارییە کراوەکانی کڕین (Purchase Requirements) بۆ ئەم کاڵایانە ئەگەر هەبن
                $productIds = collect($itemsList)->pluck('product_id')->filter()->toArray();
                if (!empty($productIds)) {
                    PurchaseRequirement::whereIn('product_id', $productIds)
                        ->where('warehouse_id', $order->warehouse_id)
                        ->where('status', 'OPEN')
                        ->update([
                            'status'            => 'CLOSED',
                            'purchase_order_id' => $order->id,
                        ]);
                }
            }

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
                    'paid_amount'  => $paidAmount,
                    'items_count'  => count($data['items']),
                ],
                'description' => "پسوڵەی کڕین دروستکرا: {$order->order_number} بە بڕی {$totalAmount} (دراو: {$paidAmount})",
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
        $notificationData = null;
        $receivedOrder = DB::transaction(function () use ($order, $user, $receivingItems, &$notificationData) {
            // Lock the purchase order to prevent concurrent receiving race conditions
            $lockedOrder = PurchaseOrder::lockForUpdate()->findOrFail($order->id);

            if ($lockedOrder->status === PurchaseOrder::STATUS_CANCELLED) {
                throw ValidationException::withMessages(['status' => 'ناتوانرێت پسوڵەی هەڵوەشاوە وەربگیرێت.']);
            }

            if ($lockedOrder->status === PurchaseOrder::STATUS_DRAFT || $lockedOrder->status === PurchaseOrder::STATUS_DRAFT_LOWER) {
                throw ValidationException::withMessages(['status' => 'ناتوانرێت پسوڵەی ڕەشنووس وەربگیرێت، پێویستە پێشتر پەسەند بکرێت.']);
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
                // Step 1: Normalize & group requested quantities by PurchaseOrderItem identity
                $groupedQuantities = [];

                foreach ($receivingItems as $reqItem) {
                    $productId = $reqItem['product_id'] ?? null;
                    $itemId = $reqItem['item_id'] ?? null;
                    $qtyToReceive = (int) ($reqItem['quantity'] ?? 0);

                    if ($qtyToReceive <= 0) {
                        throw ValidationException::withMessages(['items' => 'بڕی وەرگیراو دەبێت لە ٠ گەورەتر بێت.']);
                    }

                    if ($itemId === null && $productId === null) {
                        throw ValidationException::withMessages(['items' => 'پێویستە item_id یاخود product_id دیاری بكرێت.']);
                    }

                    $matchingItem = null;
                    if ($itemId !== null) {
                        $matchingItem = $allItems->first(function ($it) use ($itemId) {
                            return (int)$it->id === (int)$itemId;
                        });

                        if ($matchingItem && $productId !== null && (int)$matchingItem->product_id !== (int)$productId) {
                            throw ValidationException::withMessages(['items' => 'کۆدی کاڵا و زنجیرەی پسوڵە یەکناگرنەوە.']);
                        }
                    } else {
                        // Only product_id was provided
                        $matchingItems = $allItems->filter(function ($it) use ($productId) {
                            return (int)$it->product_id === (int)$productId;
                        });

                        if ($matchingItems->count() > 1) {
                            throw ValidationException::withMessages(['items' => 'چەند دێڕێک هەن بۆ هەمان کاڵا، تکایە item_id دیاری بکە.']);
                        }

                        $matchingItem = $matchingItems->first();
                    }

                    if (!$matchingItem) {
                        throw ValidationException::withMessages(['items' => 'کاڵای دیاریکراو لەم پسوڵەی کڕینەدا بوونی نییە.']);
                    }

                    $poItemId = (int) $matchingItem->id;
                    $groupedQuantities[$poItemId] = ($groupedQuantities[$poItemId] ?? 0) + $qtyToReceive;
                }

                // Step 2: Validate grouped quantities against remaining quantity for each PurchaseOrderItem BEFORE mutating any state
                foreach ($groupedQuantities as $poItemId => $totalQtyToReceive) {
                    $matchingItem = $allItems->firstWhere('id', $poItemId);

                    $remaining = $matchingItem->quantity - $matchingItem->received_quantity;
                    if ($remaining <= 0) {
                        throw ValidationException::withMessages(['items' => "کاڵای (کۆد #{$matchingItem->product_id}) بە تەواوی وەرگیراوە."]);
                    }

                    if ($totalQtyToReceive > $remaining) {
                        throw ValidationException::withMessages(['items' => "بڕی وەرگیراو ({$totalQtyToReceive}) زیاترە لە بڕی مابووەوە ({$remaining})."]);
                    }
                }

                $receivingMap = $groupedQuantities;
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

                // نوێکردنەوەی نرخی تێچووی کاڵا و دابینکەر لە خشتەی کاڵاکان (products)
                $product = \App\Models\Product::find($item->product_id);
                if ($product) {
                    $prodUpdate = ['cost_price' => (int) $item->unit_cost];
                    if ($lockedOrder->supplier_id) {
                        $prodUpdate['supplier_id'] = $lockedOrder->supplier_id;
                    }
                    $product->update($prodUpdate);
                }
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
                    'status'      => PurchaseOrder::STATUS_RECEIVED,
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

            $notificationData = [
                'supplier'           => $supplier,
                'order'              => $lockedOrder,
                'batch_total_amount' => $batchTotalAmount,
                'previous_balance'   => $previousBalance,
                'new_balance'        => $newBalance,
            ];

            return $lockedOrder;
        });

        // WhatsApp notification AFTER commit per BR-F07
        if ($notificationData && $notificationData['batch_total_amount'] > 0) {
            try {
                app(\App\Services\WhatsAppService::class)->sendSupplierPurchaseNotification(
                    $notificationData['supplier'],
                    $notificationData['order'],
                    $notificationData['batch_total_amount'],
                    $notificationData['previous_balance'],
                    $notificationData['new_balance'],
                    $user
                );
            } catch (\Throwable $e) {
                \Illuminate\Support\Facades\Log::warning("WhatsApp supplier purchase notification failed: " . $e->getMessage());
            }
        }

        return $receivedOrder;
    }

    /**
     * پەسەندکردنی پسوڵەی کڕین
     */
    public function confirmOrder(PurchaseOrder $order, $user): PurchaseOrder
    {
        return DB::transaction(function () use ($order, $user) {
            $lockedOrder = PurchaseOrder::lockForUpdate()->findOrFail($order->id);

            if ($lockedOrder->status === PurchaseOrder::STATUS_CANCELLED) {
                throw ValidationException::withMessages(['status' => 'ناتوانرێت پسوڵەی هەڵوەشاوە پەسەند بكرێت.']);
            }

            if ($lockedOrder->status === PurchaseOrder::STATUS_RECEIVED || $lockedOrder->status === PurchaseOrder::STATUS_RECEIVED_LOWER) {
                throw ValidationException::withMessages(['status' => 'ئەم پسوڵەی کڕینە پێشتر وەرگیراوە.']);
            }

            if ($lockedOrder->status === PurchaseOrder::STATUS_DRAFT) {
                $lockedOrder->update(['status' => PurchaseOrder::STATUS_CONFIRMED]);

                app(\App\Services\AuditService::class)->log([
                    'action'      => 'CONFIRM',
                    'entity_type' => 'PurchaseOrder',
                    'entity_id'   => $lockedOrder->id,
                    'table_name'  => 'purchase_orders',
                    'old_values'  => ['status' => PurchaseOrder::STATUS_DRAFT],
                    'new_values'  => ['status' => PurchaseOrder::STATUS_CONFIRMED],
                    'description' => "پسوڵەی کڕینی {$lockedOrder->order_number} پەسەند کرا",
                    'user'        => $user,
                ]);
            }

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

            if ($lockedOrder->items()->where('received_quantity', '>', 0)->exists()) {
                throw ValidationException::withMessages(['status' => 'ناتوانرێت پسوڵەی کڕین هەڵبوەشێنرێتەوە چونکە بەشێک لە کاڵاکانی وەرگیراون.']);
            }

            $oldStatus = $lockedOrder->status;
            $lockedOrder->update(['status' => PurchaseOrder::STATUS_CANCELLED]);

            // داواکارییەکانی کڕین دەکرێنەوە بۆ ئەوەی دووبارە بکرێن بە پسوڵە ئەگەر پێویست بکات
            $requirements = $lockedOrder->requirements()->get();

            foreach ($requirements as $req) {
                $oldReqStatus = $req->status;
                $oldPOId = $req->purchase_order_id;

                $req->update([
                    'status' => 'OPEN',
                    'purchase_order_id' => null
                ]);

                app(\App\Services\AuditService::class)->log([
                    'action'      => 'REOPENED',
                    'entity_type' => 'PurchaseRequirement',
                    'entity_id'   => $req->id,
                    'table_name'  => 'purchase_requirements',
                    'old_values'  => [
                        'status' => $oldReqStatus,
                        'purchase_order_id' => $oldPOId
                    ],
                    'new_values'  => [
                        'status' => 'OPEN',
                        'purchase_order_id' => null
                    ],
                    'description' => "داواکاری کڕینی #{$req->id} گۆڕدرا لە {$oldReqStatus} بۆ OPEN و لۆگی purchase_order_id پاککرایەوە بەهۆی هەڵوەشاندنەوەی پسوڵەی کڕین",
                    'user'        => $user,
                ]);
            }

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

    /**
     * نوێکردنەوەی پسوڵەی کڕین (بۆ نمونە گۆڕینی کاڵاکان، دابینکەر، یان تەئکیدکردنەوە)
     */
    public function updateOrder(PurchaseOrder $order, array $data, $user): PurchaseOrder
    {
        return DB::transaction(function () use ($order, $data, $user) {
            $lockedOrder = PurchaseOrder::lockForUpdate()->findOrFail($order->id);

            if ($lockedOrder->status !== PurchaseOrder::STATUS_DRAFT && $lockedOrder->status !== PurchaseOrder::STATUS_DRAFT_LOWER) {
                throw ValidationException::withMessages(['status' => 'تەنها دەتوانرێت پسوڵەی ڕەشنووس دەستکاری بکرێت.']);
            }

            $supplierId = array_key_exists('supplier_id', $data) ? $data['supplier_id'] : $lockedOrder->supplier_id;
            $warehouseId = array_key_exists('warehouse_id', $data) ? (int)$data['warehouse_id'] : $lockedOrder->warehouse_id;
            $notes = array_key_exists('notes', $data) ? $data['notes'] : $lockedOrder->notes;
            $paidAmount = array_key_exists('paid_amount', $data) ? max(0, (int)$data['paid_amount']) : (int)$lockedOrder->paid_amount;
            $autoReceive = !empty($data['auto_receive']);

            $totalAmount = 0;
            if (isset($data['items'])) {
                $lockedOrder->items()->delete();

                foreach ($data['items'] as $item) {
                    $qty = (int) $item['quantity'];
                    $unitCost = (int) $item['unit_cost'];
                    $lineTotal = $qty * $unitCost;
                    $totalAmount += $lineTotal;

                    $lockedOrder->items()->create([
                        'product_id'        => $item['product_id'],
                        'quantity'          => $qty,
                        'unit_cost'         => $unitCost,
                        'total_cost'        => $lineTotal,
                        'received_quantity' => $autoReceive ? $qty : 0,
                    ]);

                    if ($autoReceive) {
                        $warehouseStock = WarehouseStock::lockForUpdate()->firstOrCreate(
                            ['warehouse_id' => $warehouseId, 'product_id' => $item['product_id']],
                            ['quantity' => 0, 'reserved_quantity' => 0]
                        );

                        $warehouseStock->adjustStock(
                            $qty,
                            'PURCHASE',
                            $user->id,
                            'purchase_order',
                            $lockedOrder->id
                        );

                        // نوێکردنەوەی نرخی تێچووی کاڵا و دابینکەر لە خشتەی کاڵاکان
                        $product = \App\Models\Product::find($item['product_id']);
                        if ($product) {
                            $prodUpdate = ['cost_price' => $unitCost];
                            if ($supplierId) {
                                $prodUpdate['supplier_id'] = $supplierId;
                            }
                            $product->update($prodUpdate);
                        }
                    }
                }
                $lockedOrder->total_amount = $totalAmount;
            } else {
                $totalAmount = (int) $lockedOrder->total_amount;
            }

            $lockedOrder->supplier_id = $supplierId;
            $lockedOrder->warehouse_id = $warehouseId;
            $lockedOrder->notes = $notes;
            if (Schema::hasColumn('purchase_orders', 'paid_amount')) {
                $lockedOrder->paid_amount = min($paidAmount, $totalAmount);
            }

            if ($autoReceive) {
                $lockedOrder->status = PurchaseOrder::STATUS_RECEIVED;
                $lockedOrder->received_at = now();
                $lockedOrder->save();

                // قەرز و حیساباتی دابینکەر
                if ($supplierId && $totalAmount > 0) {
                    $supplier = Supplier::lockForUpdate()->find($supplierId);
                    if ($supplier) {
                        $previousBalance = (int) $supplier->current_balance;
                        $balanceAfterPurchase = $previousBalance + $totalAmount;

                        SupplierLedger::create([
                            'supplier_id'    => $supplier->id,
                            'entry_type'     => 'PURCHASE',
                            'type'           => 'credit',
                            'debit'          => 0,
                            'credit'         => $totalAmount,
                            'amount'         => $totalAmount,
                            'balance_before' => $previousBalance,
                            'balance_after'  => $balanceAfterPurchase,
                            'reference_type' => 'purchase_order',
                            'reference_id'   => $lockedOrder->id,
                            'description'    => "کڕینی کاڵا بە پسوڵەی {$lockedOrder->order_number}",
                            'created_by'     => $user->id,
                        ]);

                        $finalBalance = $balanceAfterPurchase;
                        if ($paidAmount > 0) {
                            $effectivePaid = min($paidAmount, $totalAmount);
                            $finalBalance = $balanceAfterPurchase - $effectivePaid;

                            SupplierPayment::create([
                                'supplier_id'       => $supplier->id,
                                'purchase_order_id' => $lockedOrder->id,
                                'amount'            => $effectivePaid,
                                'payment_method'    => 'cash',
                                'paid_at'           => now()->toDateString(),
                                'notes'             => "پارەدانی نەقد بۆ پسوڵەی {$lockedOrder->order_number}",
                                'created_by'        => $user->id,
                            ]);

                            SupplierLedger::create([
                                'supplier_id'    => $supplier->id,
                                'entry_type'     => 'PAYMENT',
                                'type'           => 'debit',
                                'debit'          => $effectivePaid,
                                'credit'         => 0,
                                'amount'         => $effectivePaid,
                                'balance_before' => $balanceAfterPurchase,
                                'balance_after'  => $finalBalance,
                                'reference_type' => 'supplier_payment',
                                'reference_id'   => $lockedOrder->id,
                                'description'    => "پارەدانی پسوڵەی کڕین {$lockedOrder->order_number}",
                                'created_by'     => $user->id,
                            ]);
                        }

                        $supplier->update(['current_balance' => $finalBalance]);
                    }
                }

                // داخستنی داواکارییە پەیوەندیدارەکان
                if (isset($data['items'])) {
                    $productIds = collect($data['items'])->pluck('product_id')->filter()->toArray();
                    if (!empty($productIds)) {
                        PurchaseRequirement::whereIn('product_id', $productIds)
                            ->where('warehouse_id', $lockedOrder->warehouse_id)
                            ->where('status', 'OPEN')
                            ->update([
                                'status'            => 'CLOSED',
                                'purchase_order_id' => $lockedOrder->id,
                            ]);
                    }
                }
            } else {
                $lockedOrder->save();
            }

            app(\App\Services\AuditService::class)->log([
                'action'      => $autoReceive ? 'RECEIVE' : 'UPDATE',
                'entity_type' => 'PurchaseOrder',
                'entity_id'   => $lockedOrder->id,
                'table_name'  => 'purchase_orders',
                'old_values'  => null,
                'new_values'  => [
                    'order_number' => $lockedOrder->order_number,
                    'supplier_id'  => $lockedOrder->supplier_id,
                    'warehouse_id' => $lockedOrder->warehouse_id,
                    'status'       => $lockedOrder->status,
                    'total_amount' => $lockedOrder->total_amount,
                    'paid_amount'  => $lockedOrder->paid_amount,
                ],
                'description' => $autoReceive 
                    ? "پسوڵەی کڕین #{$lockedOrder->order_number} تەئکید کرایەوە و کاڵاکان خرانە ناو ستۆک"
                    : "پسوڵەی کڕینی ڕەشنووس #{$lockedOrder->order_number} نوێکرایەوە",
                'user'        => $user,
            ]);

            return $lockedOrder->fresh(['supplier', 'warehouse', 'items.product', 'payments']);
        });
    }

    /**
     * سڕینەوەی پسوڵەی کڕینی ڕەشنووس
     */
    public function deleteOrder(PurchaseOrder $order, $user): void
    {
        DB::transaction(function () use ($order, $user) {
            $lockedOrder = PurchaseOrder::lockForUpdate()->findOrFail($order->id);

            if ($lockedOrder->status === PurchaseOrder::STATUS_RECEIVED || $lockedOrder->status === PurchaseOrder::STATUS_RECEIVED_LOWER) {
                throw ValidationException::withMessages(['status' => 'ناتوانرێت پسوڵەی وەرگیراو بسڕدرێتەوە.']);
            }

            if ($lockedOrder->items()->where('received_quantity', '>', 0)->exists()) {
                throw ValidationException::withMessages(['status' => 'ناتوانرێت ئەم پسوڵەیە بسڕدرێتەوە چونكە بەشێک لە کاڵاکانی وەرگیراون.']);
            }

            $lockedOrder->requirements()->update(['status' => 'OPEN', 'purchase_order_id' => null]);
            $lockedOrder->items()->delete();
            $lockedOrder->delete();

            app(\App\Services\AuditService::class)->log([
                'action'      => 'DELETE',
                'entity_type' => 'PurchaseOrder',
                'entity_id'   => $lockedOrder->id,
                'table_name'  => 'purchase_orders',
                'old_values'  => ['order_number' => $lockedOrder->order_number],
                'new_values'  => null,
                'description' => "پسوڵەی کڕینی ڕەشنووس {$lockedOrder->order_number} سڕایەوە",
                'user'        => $user,
            ]);
        });
    }
}
