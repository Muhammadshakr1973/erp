<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\Product;
use App\Models\SalesOrder;
use App\Models\WarehouseStock;
use App\Models\StockTransaction;
use App\Models\PurchaseRequirement;
use App\Models\CustomerLedger;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class SalesOrderService
{
    protected array $validTransitions = [
        SalesOrder::STATUS_DRAFT => [SalesOrder::STATUS_CONFIRMED, SalesOrder::STATUS_CANCELLED],
        SalesOrder::STATUS_CONFIRMED => [SalesOrder::STATUS_PACKING, SalesOrder::STATUS_READY, SalesOrder::STATUS_CANCELLED],
        SalesOrder::STATUS_PACKING => [SalesOrder::STATUS_READY, SalesOrder::STATUS_CANCELLED],
        SalesOrder::STATUS_READY => [SalesOrder::STATUS_IN_DELIVERY, SalesOrder::STATUS_CANCELLED],
        SalesOrder::STATUS_IN_DELIVERY => [SalesOrder::STATUS_DELIVERED, SalesOrder::STATUS_CANCELLED],
        SalesOrder::STATUS_DELIVERED => [],
        SalesOrder::STATUS_CANCELLED => [],
    ];
    /**
     * دروستکردنی پسوڵەی فرۆشتن بە شێوەی تۆکمە و سەلامەت
     */
    public function createOrder(array $data, $user): SalesOrder
    {
        // ١. پاراستنی لایەنی یەکسانی (Idempotency) بۆ ڕێگری لە دروستکردنی پسوڵەی دووبارە بەهۆی دووجار کلیککردن
        $existingOrder = $this->checkIdempotency($data['customer_id'], $data['warehouse_id'], $data['items']);
        if ($existingOrder) {
            return $existingOrder;
        }

        return DB::transaction(function () use ($data, $user) {
            // ٢. قفڵکردنی ڕیزی کڕیار بۆ ڕێگری لە گۆڕانکاری هاوکات
            $customer = Customer::lockForUpdate()->findOrFail($data['customer_id']);

            // ٣. دڵنیابوونەوە لەوەی کە کڕیارەکە بۆ ئەم مەندوبە دەستنیشان کراوە (Authorization & Assignment)
            $this->checkCustomerAssignment($customer, $user);

            // دروستکردنی ژمارەی تایبەت بۆ پسوڵە (ORD-XXXXXXXX)
            $orderNumber = 'ORD-' . strtoupper(Str::random(8));

            // دروستکردنی پسوڵە لە سەرەتادا بە شێوەی DRAFT
            $order = SalesOrder::create([
                'order_number' => $orderNumber,
                'customer_id' => $customer->id,
                'salesman_id' => $user->id,
                'warehouse_id' => $data['warehouse_id'],
                'order_date' => now()->toDateString(),
                'status' => SalesOrder::STATUS_DRAFT,
                'discount_percent' => $data['discount_percent'] ?? 0,
                'notes' => $data['notes'] ?? null,
                'created_by' => $user->id,
                'subtotal' => 0,
                'discount_amount' => 0,
                'total_amount' => 0,
                'total_profit' => 0,
            ]);

            $subtotal = 0;
            $totalProfit = 0;

            // پاشەکەوتکردنی کاڵاکان بە شێوەی سێریاڵ
            foreach ($data['items'] as $item) {
                $product = Product::findOrFail($item['product_id']);

                // دیاریکردنی نرخ بەپێی تایپ و کڕیار (تۆمارکردنی مێژوویی - Snapshot)
                $unitPrice = $customer->getCurrentPriceForProduct($product);

                $lineTotal = $unitPrice * $item['quantity'];
                $profit = ($unitPrice - $product->cost_price) * $item['quantity'];

                $order->items()->create([
                    'product_id' => $product->id,
                    'quantity' => $item['quantity'],
                    'unit_price' => $unitPrice,
                    'cost_price' => $product->cost_price, // Snapshot
                    'price_type' => $customer->price_type,
                    'line_total' => $lineTotal,
                    'profit' => $profit,
                    'is_packed' => false,
                ]);

                $subtotal += $lineTotal;
                $totalProfit += $profit;
            }

            // هەژمارکردنی داشکاندن و نرخی کۆتایی پسوڵە
            $discountAmount = 0;
            if ($order->discount_percent > 0) {
                $discountAmount = ($subtotal * $order->discount_percent) / 100;
            }
            $totalAmount = $subtotal - $discountAmount;

            $order->update([
                'subtotal' => $subtotal,
                'discount_amount' => $discountAmount,
                'total_amount' => $totalAmount,
                'total_profit' => $totalProfit,
            ]);

            // ئەگەر دۆخی تایبەت دیاری کرابوو وەک DRAFT ئەوا وەکو خۆی دەیهێڵینەوە، ئەگەرنا دەچێتە ڕەوتی CONFIRMED
            $requestedStatus = $data['status'] ?? SalesOrder::STATUS_CONFIRMED;
            if ($requestedStatus === SalesOrder::STATUS_DRAFT) {
                return $order;
            }

            // کاتێک پسوڵە بە سەرکەوتوویی دروستکرا، ڕاستەوخۆ دەیدەینە ڕەوتی پشتڕاستکردنەوە (CONFIRMED) بۆ حجزکردنی ستۆک
            return $this->transitionTo($order, SalesOrder::STATUS_CONFIRMED, $user);
        });

        // Notify new order created AFTER database commit (NOT-001)
        if ($order->status !== SalesOrder::STATUS_DRAFT) {
            app(NotificationService::class)->notifyNewOrderCreated($order, $user);
        }

        return $order;
    }

    public function updateOrder(SalesOrder $order, array $data, $user): SalesOrder
    {
        if ($order->status !== SalesOrder::STATUS_DRAFT) {
            throw ValidationException::withMessages([
                'status' => 'تەنها پسوڵەی DRAFT دەتوانرێت دەستکاری بکرێت.'
            ]);
        }

        return DB::transaction(function () use ($order, $data, $user) {
            $customer = Customer::lockForUpdate()->findOrFail($order->customer_id);

            // Update basic info
            $order->update([
                'discount_percent' => $data['discount_percent'] ?? $order->discount_percent,
                'notes' => $data['notes'] ?? $order->notes,
                'warehouse_id' => $data['warehouse_id'] ?? $order->warehouse_id,
            ]);

            // Remove old items
            $order->items()->delete();

            $subtotal = 0;
            $totalProfit = 0;

            foreach ($data['items'] as $item) {
                $product = Product::findOrFail($item['product_id']);
                $unitPrice = $customer->getCurrentPriceForProduct($product);
                $lineTotal = $unitPrice * $item['quantity'];
                $profit = ($unitPrice - $product->cost_price) * $item['quantity'];

                $order->items()->create([
                    'product_id' => $product->id,
                    'quantity' => $item['quantity'],
                    'unit_price' => $unitPrice,
                    'cost_price' => $product->cost_price,
                    'price_type' => $customer->price_type,
                    'line_total' => $lineTotal,
                    'profit' => $profit,
                    'is_packed' => false,
                ]);

                $subtotal += $lineTotal;
                $totalProfit += $profit;
            }

            $discountAmount = 0;
            if ($order->discount_percent > 0) {
                $discountAmount = ($subtotal * $order->discount_percent) / 100;
            }
            $totalAmount = $subtotal - $discountAmount;

            $order->update([
                'subtotal' => $subtotal,
                'discount_amount' => $discountAmount,
                'total_amount' => $totalAmount,
                'total_profit' => $totalProfit,
            ]);

            $requestedStatus = $data['status'] ?? $order->status;
            if ($requestedStatus !== SalesOrder::STATUS_DRAFT) {
                $order = $this->transitionTo($order, $requestedStatus, $user);
                app(NotificationService::class)->notifyNewOrderCreated($order, $user);
                return $order;
            }

            return $order;
        });
    }

    /**
     * جێبەجێکردنی گواستنەوەی دۆخی پسوڵەکان بە شێوەی دەوڵەتی (State Machine)
     */
    public function transitionTo(SalesOrder $order, string $newStatus, $user): SalesOrder
    {
        $oldStatus = null;
        $updatedOrder = DB::transaction(function () use ($order, $newStatus, $user, &$oldStatus) {
            // Lock order for update to prevent race conditions and concurrent transitions (Idempotency)
            $lockedOrder = SalesOrder::lockForUpdate()->findOrFail($order->id);
            $currentStatus = $lockedOrder->status;
            $oldStatus = $currentStatus;

            if ($currentStatus === $newStatus) {
                return $lockedOrder;
            }

            // ١. دڵنیابوونەوە لەوەی کە گواستنەوەکە یاساییە بەپێی نەخشەی گواستنەوەی دۆخەکان
            if (!isset($this->validTransitions[$currentStatus]) || !in_array($newStatus, $this->validTransitions[$currentStatus])) {
                throw ValidationException::withMessages([
                    'status' => "گواستنەوەی دۆخەکە نادروستە. ناتوانرێت لە دۆخی {$currentStatus} بگۆڕدرێت بۆ {$newStatus}."
                ]);
            }

            // ٢. سەپاندنی دەسەڵاتەکان و مۆڵەتەکان بەپێی دۆخی نوێ لەناو خودی سێرڤسەکەدا بۆ پاراستنی هێمنیی سیستەمەکە
            if (in_array($newStatus, [SalesOrder::STATUS_DRAFT, SalesOrder::STATUS_CONFIRMED, SalesOrder::STATUS_CANCELLED])) {
                if (!$user->hasPermission('orders.create')) {
                    throw ValidationException::withMessages([
                        'status' => 'تۆ ڕێگەپێدراو نیت بۆ گۆڕینی دۆخی پسوڵە بۆ ' . $newStatus
                    ]);
                }
            } elseif (in_array($newStatus, [SalesOrder::STATUS_PACKING, SalesOrder::STATUS_READY])) {
                if (!$user->hasPermission('stock.pack')) {
                    throw ValidationException::withMessages([
                        'status' => 'تۆ ڕێگەپێدراو نیت بۆ گۆڕینی دۆخی پسوڵە بۆ ' . $newStatus
                    ]);
                }
            } elseif (in_array($newStatus, [SalesOrder::STATUS_IN_DELIVERY, SalesOrder::STATUS_DELIVERED])) {
                if (!$user->hasPermission('delivery.update')) {
                    throw ValidationException::withMessages([
                        'status' => 'تۆ ڕێگەپێدراو نیت بۆ گۆڕینی دۆخی پسوڵە بۆ ' . $newStatus
                    ]);
                }
            }

            // ٣. ئەنجامدانی کردارە لۆجیکییە پەیوەندیدارەکان بە هەر دۆخێکەوە
            switch ($newStatus) {
                case SalesOrder::STATUS_CONFIRMED:
                    $this->reserveStock($lockedOrder, $user);
                    $lockedOrder->confirmed_at = now();
                    break;

                case SalesOrder::STATUS_PACKING:
                    break;

                case SalesOrder::STATUS_READY:
                    // Count packed items
                    $packedCount = $lockedOrder->items()->where('is_packed', true)->count();
                    if ($packedCount === 0) {
                        throw ValidationException::withMessages(['status' => 'ناتوانرێت پسوڵە بە ئامادەکراو دابنرێت ئەگەر هیچ کاڵایەکی پاکەت نەکراوە.']);
                    }

                    // Handle unpacked items (partial packing)
                    $unpackedItems = $lockedOrder->items()->where('is_packed', false)->get();
                    foreach ($unpackedItems as $item) {
                        $warehouseStock = WarehouseStock::lockForUpdate()->where([
                            'warehouse_id' => $lockedOrder->warehouse_id,
                            'product_id' => $item->product_id
                        ])->first();

                        if ($warehouseStock) {
                            $warehouseStock->releaseStock($item->quantity, $user->id, 'sales_order', $lockedOrder->id, 'Partial packing release');
                        }
                        $item->delete();
                    }

                    // Recalculate order totals if any items were deleted
                    if ($unpackedItems->count() > 0) {
                        $remainingItems = $lockedOrder->items()->where('is_packed', true)->get();
                        $subtotal = 0;
                        $totalProfit = 0;
                        foreach ($remainingItems as $item) {
                            $subtotal += $item->line_total;
                            $totalProfit += $item->profit;
                        }

                        $discountAmount = 0;
                        if ($lockedOrder->discount_percent > 0) {
                            $discountAmount = ($subtotal * $lockedOrder->discount_percent) / 100;
                        }
                        $totalAmount = $subtotal - $discountAmount;

                        $lockedOrder->update([
                            'subtotal' => $subtotal,
                            'discount_amount' => $discountAmount,
                            'total_amount' => $totalAmount,
                            'total_profit' => $totalProfit,
                        ]);
                    }

                    $lockedOrder->ready_at = now();
                    break;

                case SalesOrder::STATUS_IN_DELIVERY:
                    break;

                case SalesOrder::STATUS_DELIVERED:
                    $this->finalizeStockSale($lockedOrder, $user);
                    $this->postToCustomerLedger($lockedOrder, $user);
                    $lockedOrder->delivered_at = now();
                    // Delivery Synchronization
                    $this->syncDeliveryOnDelivery($lockedOrder);
                    break;

                case SalesOrder::STATUS_CANCELLED:
                    // Only release stock if it was actually reserved (i.e. status was CONFIRMED, PACKING, READY, or IN_DELIVERY)
                    if (in_array($currentStatus, [SalesOrder::STATUS_CONFIRMED, SalesOrder::STATUS_PACKING, SalesOrder::STATUS_READY, SalesOrder::STATUS_IN_DELIVERY])) {
                        $this->releaseStock($lockedOrder, $user);
                    }
                    // Delivery Synchronization
                    $this->syncDeliveryOnCancellation($lockedOrder);
                    break;

                default:
                    throw ValidationException::withMessages(['status' => 'دۆخێکی نەناسراو دیاریکراوە.']);
            }

            // ئەگەر پسوڵەکە لێرە ئەبدەیت کرا
            $lockedOrder->status = $newStatus;
            $lockedOrder->save();

            // تۆمارکردنی مێژووی چالاکی بۆ سیستەم (Audit Logging)
            $this->logActivity($lockedOrder, $currentStatus, $newStatus, $user);

            return $lockedOrder;
        });

        if ($oldStatus !== $newStatus) {
            if ($newStatus === SalesOrder::STATUS_READY) {
                app(NotificationService::class)->notifyOrderReadyForDelivery($updatedOrder, $user);
            }
        }

        return $updatedOrder;
    }

    /**
     * حجزکردنی ستۆک لە کۆگا لە کاتی CONFIRMED
     */
    private function reserveStock(SalesOrder $order, $user): void
    {
        foreach ($order->items as $item) {
            // قفڵکردنی ڕیزی ستۆک بۆ ڕێگری لە کێبڕکێی هاوکات
            $warehouseStock = WarehouseStock::lockForUpdate()->firstOrCreate(
                ['warehouse_id' => $order->warehouse_id, 'product_id' => $item->product_id],
                ['quantity' => 0, 'reserved_quantity' => 0]
            );

            $availableStock = $warehouseStock->quantity - $warehouseStock->reserved_quantity;

            if ($availableStock < $item->quantity) {
                // یاسای BR-O01 و BR-O02: کەمبوونی ستۆک دەنێردرێت بۆ کڕین لە بازاڕ (Purchase Requirements)
                $shortage = $item->quantity - max(0, $availableStock);

                $existingReq = PurchaseRequirement::where('product_id', $item->product_id)
                    ->where('sales_order_id', $order->id)
                    ->where('status', 'OPEN')
                    ->first();

                if ($existingReq) {
                    $existingReq->update([
                        'required_quantity' => $shortage,
                        'current_stock' => $warehouseStock->quantity,
                    ]);
                } else {
                    $product = Product::find($item->product_id);
                    PurchaseRequirement::create([
                        'product_id' => $item->product_id,
                        'warehouse_id' => $order->warehouse_id,
                        'supplier_id' => $product ? $product->supplier_id : null,
                        'sales_order_id' => $order->id,
                        'required_quantity' => $shortage,
                        'current_stock' => $warehouseStock->quantity,
                        'status' => 'OPEN',
                        'created_by' => $user->id,
                    ]);
                }

                $reservedToAdd = max(0, $availableStock);
            } else {
                $reservedToAdd = $item->quantity;
            }

            if ($reservedToAdd > 0) {
                $warehouseStock->reserveStock($reservedToAdd, $user->id, 'sales_order', $order->id);
            }
        }
    }

    /**
     * کەمکردنەوەی فیزیکی کاڵا لە کاتی DELIVERED (کۆتاییهاتنی فرۆشتن)
     */
    private function finalizeStockSale(SalesOrder $order, $user): void
    {
        foreach ($order->items as $item) {
            $warehouseStock = WarehouseStock::lockForUpdate()->where([
                'warehouse_id' => $order->warehouse_id,
                'product_id' => $item->product_id
            ])->first();

            if ($warehouseStock) {
                $warehouseStock->adjustStock(
                    -$item->quantity,
                    'DELIVERY',
                    $user->id,
                    'sales_order',
                    $order->id
                );
            }
        }
    }

    /**
     * ئازادکردنی بڕی حجزکراو لە کاتی CANCELLED
     */
    private function releaseStock(SalesOrder $order, $user): void
    {
        foreach ($order->items as $item) {
            $warehouseStock = WarehouseStock::lockForUpdate()->where([
                'warehouse_id' => $order->warehouse_id,
                'product_id' => $item->product_id
            ])->first();

            if ($warehouseStock) {
                $warehouseStock->releaseStock($item->quantity, $user->id, 'sales_order', $order->id);
            }
        }
    }

    /**
     * تۆمارکردنی پسوڵەی فرۆشتن لە دەفتەری دارایی کڕیار (Customer Ledger)
     */
    private function postToCustomerLedger(SalesOrder $order, $user): void
    {
        $customer = Customer::lockForUpdate()->findOrFail($order->customer_id);

        $previousBalance = $customer->current_balance;
        $newBalance = $previousBalance + $order->total_amount;

        CustomerLedger::create([
            'customer_id' => $customer->id,
            'entry_type' => 'SALE',
            'type' => 'debit',
            'debit' => $order->total_amount,
            'credit' => 0,
            'amount' => $order->total_amount,
            'balance_before' => $previousBalance,
            'balance_after' => $newBalance,
            'reference_type' => 'sales_order',
            'reference_id' => $order->id,
            'description' => "پسوڵەی فرۆشتنی ژمارە {$order->order_number}",
            'created_by' => $user->id,
        ]);

        $customer->update(['current_balance' => $newBalance]);
    }

    /**
     * فلتەرکردنی پاراستنی یەکپارچەیی فرۆشتن (Idempotency Helper)
     */
    private function checkIdempotency(int $customerId, int $warehouseId, array $items): ?SalesOrder
    {
        $recentOrder = SalesOrder::where('customer_id', $customerId)
            ->where('warehouse_id', $warehouseId)
            ->where('created_at', '>=', now()->subSeconds(90))
            ->orderBy('id', 'desc')
            ->first();

        if ($recentOrder) {
            $existingItems = $recentOrder->items()->pluck('quantity', 'product_id')->toArray();
            $newItems = [];
            foreach ($items as $item) {
                $newItems[$item['product_id']] = $item['quantity'];
            }

            if ($existingItems === $newItems) {
                return $recentOrder;
            }
        }

        return null;
    }

    /**
     * دڵنیابوونەوە لە دەستنیشانکردنی کڕیار بۆ مەندوب
     */
    private function checkCustomerAssignment(Customer $customer, $user): void
    {
        if ($user->isAdmin() || $user->isOwner()) {
            return;
        }

        // دیاریکردنی ڕاستەوخۆ
        $hasDirectAssignment = DB::table('customer_assignments')
            ->where('customer_id', $customer->id)
            ->where('salesman_id', $user->id)
            ->where('assigned_from', '<=', now()->toDateString())
            ->where(function ($q) {
                $q->whereNull('assigned_until')
                  ->orWhere('assigned_until', '>=', now()->toDateString());
            })
            ->exists();

        if ($hasDirectAssignment) {
            return;
        }

        // دیاریکردنی بەپێی گەڕەک (Route)
        $hasRouteAssignment = DB::table('route_salesmen')
            ->where('route_id', $customer->route_id)
            ->where('salesman_id', $user->id)
            ->where('work_date', now()->toDateString())
            ->exists();

        if ($hasRouteAssignment) {
            return;
        }

        throw ValidationException::withMessages([
            'customer_id' => 'ڕێگەپێدراو نییە. ئەم کڕیارە بۆ ئەم مەندوبە دەستنیشان نەکراوە.'
        ]);
    }

    /**
     * تۆمارکردنی دەفتەری مێژوویی کار چالاکییەکان (Audit activity log)
     */
    private function logActivity(SalesOrder $order, string $oldStatus, string $newStatus, $user): void
    {
        app(AuditService::class)->log([
            'action'      => 'STATUS_CHANGE',
            'entity_type' => 'SalesOrder',
            'entity_id'   => $order->id,
            'table_name'  => 'sales_orders',
            'old_values'  => [
                'status'       => $oldStatus,
                'order_number' => $order->order_number,
            ],
            'new_values'  => [
                'status'       => $newStatus,
                'order_number' => $order->order_number,
                'total_amount' => $order->total_amount,
            ],
            'description' => "دۆخی پسوڵەی فرۆشتن {$order->order_number} گۆڕدرا لە [{$oldStatus}] بۆ [{$newStatus}]",
            'user'        => $user,
        ]);
    }

    /**
     * Synchronize delivery trip orders when sales order is delivered directly
     */
    private function syncDeliveryOnDelivery(SalesOrder $order): void
    {
        DB::table('delivery_trip_orders')
            ->where('sales_order_id', $order->id)
            ->where('status', 'PENDING')
            ->update([
                'status' => 'DELIVERED',
                'delivered_at' => now(),
                'received_amount' => $order->total_amount,
            ]);
    }

    /**
     * Synchronize delivery trip orders when sales order is cancelled
     */
    private function syncDeliveryOnCancellation(SalesOrder $order): void
    {
        DB::table('delivery_trip_orders')
            ->where('sales_order_id', $order->id)
            ->whereIn('status', ['PENDING', 'DELIVERED'])
            ->update([
                'status' => 'FAILED',
                'failed_reason' => 'Cancelled via Sales Order',
            ]);
    }
}
