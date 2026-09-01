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
        SalesOrder::STATUS_CONFIRMED => [SalesOrder::STATUS_PACKING, SalesOrder::STATUS_CANCELLED],
        SalesOrder::STATUS_PACKING => [SalesOrder::STATUS_READY, SalesOrder::STATUS_CANCELLED],
        SalesOrder::STATUS_READY => [SalesOrder::STATUS_IN_DELIVERY, SalesOrder::STATUS_CANCELLED],
        SalesOrder::STATUS_IN_DELIVERY => [SalesOrder::STATUS_DELIVERED, SalesOrder::STATUS_READY, SalesOrder::STATUS_CANCELLED],
        SalesOrder::STATUS_DELIVERED => [],
        SalesOrder::STATUS_CANCELLED => [],
    ];
    /**
     * دروستکردنی پسوڵەی فرۆشتن بە شێوەی تۆکمە و سەلامەت
     */
    public function createOrder(array $data, $user): SalesOrder
    {
        // Check if there is a shared key indicating cooperative dual entry
        $sharedKey = $data['shared_key'] ?? null;
        if ($sharedKey) {
            $existingSharedOrder = SalesOrder::where('shared_key', $sharedKey)->first();
            if ($existingSharedOrder) {
                return $this->updateSharedOrder($existingSharedOrder, $data, $user);
            }
        }

        // ١. پاراستنی لایەنی یەکسانی (Idempotency) بۆ ڕێگری لە دروستکردنی پسوڵەی دووبارە بەهۆی دووجار کلیککردن
        // Bypass time-based heuristic if request has a true Idempotency-Key, as the middleware guarantees uniqueness
        $hasTrueIdempotency = request()->hasHeader('X-Idempotency-Key') || request()->hasHeader('Idempotency-Key');
        if (!$hasTrueIdempotency) {
            $existingOrder = $this->checkIdempotency($data['customer_id'], $data['warehouse_id'], $data['items']);
            if ($existingOrder) {
                return $existingOrder;
            }
        }

        $order = DB::transaction(function () use ($data, $user) {
            // ٢. قفڵکردنی ڕیزی کڕیار بۆ ڕێگری لە گۆڕانکاری هاوکات
            $customer = Customer::lockForUpdate()->findOrFail($data['customer_id']);

            // ٣. دڵنیابوونەوە لەوەی کە کڕیارەکە بۆ ئەم مەندوبە دەستنیشان کراوە (Authorization & Assignment)
            $this->checkCustomerAssignment($customer, $user);

            // دروستکردنی ژمارەی تایبەت بۆ پسوڵە (ORD-XXXXXXXX)
            $orderNumber = 'ORD-' . strtoupper(Str::random(8));

            // دروستکردنی پسوڵە لە سەرەتادا بە شێوەی DRAFT
            $order = SalesOrder::create([
                'order_number' => $orderNumber,
                'shared_key' => $data['shared_key'] ?? null,
                'version' => 1,
                'customer_id' => $customer->id,
                'salesman_id' => $user->id,
                'warehouse_id' => $data['warehouse_id'],
                'order_date' => now()->toDateString(),
                'status' => SalesOrder::STATUS_DRAFT,
                'notes' => $data['notes'] ?? null,
                'created_by' => $user->id,
                'subtotal' => 0,
                'permanent_discount_percent' => 0,
                'permanent_discount_amount' => 0,
                'discount_percent' => 0,
                'discount_amount' => 0,
                'discount_type' => 'PERCENT',
                'total_amount' => 0,
                'total_profit' => 0,
            ]);

            $subtotal = 0;
            $totalProfit = 0;

            // پاشەکەوتکردنی کاڵاکان بە شێوەی سێریاڵ
            foreach ($data['items'] as $item) {
                $quantity = (int) $item['quantity'];
                if ($quantity <= 0) {
                    throw ValidationException::withMessages([
                        'items' => 'بڕی کاڵا دەبێت لە ١ کەمتر نەبێت.'
                    ]);
                }

                $product = Product::findOrFail($item['product_id']);

                // دیاریکردنی نرخ بەپێی تایپ و کڕیار (تۆمارکردنی مێژوویی - Snapshot)
                $priceDetails = $customer->getPriceDetailsForProduct($product);
                $unitPrice = (int) $priceDetails['price'];
                $priceType = $priceDetails['price_type'];
                $costPrice = (int) $product->cost_price; // Snapshot نرخی کڕین

                $lineTotal = $unitPrice * $quantity;
                $profit = ($unitPrice - $costPrice) * $quantity;

                $order->items()->create([
                    'product_id' => $product->id,
                    'quantity' => $quantity,
                    'unit_price' => $unitPrice,
                    'cost_price' => $costPrice, // Snapshot
                    'price_type' => $priceType,
                    'discount_percent' => 0,
                    'discount_amount' => 0,
                    'line_total' => $lineTotal,
                    'total_price' => $lineTotal,
                    'profit' => $profit,
                    'is_packed' => false,
                ]);

                $subtotal += $lineTotal;
                $totalProfit += $profit;
            }

            // ١. داشکاندنی بەردەوامی کڕیار (Permanent Customer Discount)
            $permDiscountPercent = max(0, min(100, (float) ($customer->permanent_discount ?? 0)));
            $permDiscountAmount = 0;
            if ($permDiscountPercent > 0) {
                $permDiscountAmount = (int) round(($subtotal * $permDiscountPercent) / 100);
            }
            $amountAfterPermDiscount = max(0, $subtotal - $permDiscountAmount);

            // ٢. داشکاندنی تایبەت بەم پسوڵەیە (Invoice / Order Discount)
            $discountType = strtoupper($data['discount_type'] ?? 'PERCENT');
            $invoiceDiscountPercent = isset($data['discount_percent']) ? max(0, min(100, (float) $data['discount_percent'])) : 0.0;
            $invoiceDiscountAmount = 0;

            if ($discountType === 'FIXED' || (isset($data['discount_amount']) && (int)$data['discount_amount'] > 0 && $invoiceDiscountPercent == 0)) {
                $discountType = 'FIXED';
                $fixedAmount = (int) ($data['discount_amount'] ?? 0);
                $invoiceDiscountAmount = min($amountAfterPermDiscount, max(0, $fixedAmount));
            } elseif ($invoiceDiscountPercent > 0) {
                $discountType = 'PERCENT';
                $invoiceDiscountAmount = (int) round(($amountAfterPermDiscount * $invoiceDiscountPercent) / 100);
            }

            $totalAmount = max(0, $amountAfterPermDiscount - $invoiceDiscountAmount);

            $order->update([
                'subtotal' => $subtotal,
                'permanent_discount_percent' => $permDiscountPercent,
                'permanent_discount_amount' => $permDiscountAmount,
                'discount_percent' => $invoiceDiscountPercent,
                'discount_amount' => $invoiceDiscountAmount,
                'discount_type' => $discountType,
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
        if ($order->shared_key || isset($data['shared_key']) || isset($data['version'])) {
            return $this->updateSharedOrder($order, $data, $user);
        }

        if ($order->status !== SalesOrder::STATUS_DRAFT) {
            throw ValidationException::withMessages([
                'status' => 'تەنها پسوڵەی DRAFT دەتوانرێت دەستکاری بکرێت.'
            ]);
        }

        return DB::transaction(function () use ($order, $data, $user) {
            $customer = Customer::lockForUpdate()->findOrFail($order->customer_id);

            // Update basic info
            $order->update([
                'notes' => $data['notes'] ?? $order->notes,
                'warehouse_id' => $data['warehouse_id'] ?? $order->warehouse_id,
            ]);

            // Remove old items
            $order->items()->delete();

            $subtotal = 0;
            $totalProfit = 0;

            foreach ($data['items'] as $item) {
                $quantity = (int) $item['quantity'];
                if ($quantity <= 0) {
                    throw ValidationException::withMessages([
                        'items' => 'بڕی کاڵا دەبێت لە ١ کەمتر نەبێت.'
                    ]);
                }

                $product = Product::findOrFail($item['product_id']);
                $priceDetails = $customer->getPriceDetailsForProduct($product);
                $unitPrice = (int) $priceDetails['price'];
                $priceType = $priceDetails['price_type'];
                $costPrice = (int) $product->cost_price;

                $lineTotal = $unitPrice * $quantity;
                $profit = ($unitPrice - $costPrice) * $quantity;

                $order->items()->create([
                    'product_id' => $product->id,
                    'quantity' => $quantity,
                    'unit_price' => $unitPrice,
                    'cost_price' => $costPrice,
                    'price_type' => $priceType,
                    'discount_percent' => 0,
                    'discount_amount' => 0,
                    'line_total' => $lineTotal,
                    'total_price' => $lineTotal,
                    'profit' => $profit,
                    'is_packed' => false,
                ]);

                $subtotal += $lineTotal;
                $totalProfit += $profit;
            }

            // ١. داشکاندنی بەردەوامی کڕیار (Permanent Customer Discount)
            $permDiscountPercent = max(0, min(100, (float) ($customer->permanent_discount ?? 0)));
            $permDiscountAmount = 0;
            if ($permDiscountPercent > 0) {
                $permDiscountAmount = (int) round(($subtotal * $permDiscountPercent) / 100);
            }
            $amountAfterPermDiscount = max(0, $subtotal - $permDiscountAmount);

            // ٢. داشکاندنی تایبەت بەم پسوڵەیە (Invoice / Order Discount)
            $discountType = strtoupper($data['discount_type'] ?? ($order->discount_type ?? 'PERCENT'));
            $invoiceDiscountPercent = isset($data['discount_percent']) ? max(0, min(100, (float) $data['discount_percent'])) : max(0, min(100, (float) $order->discount_percent));
            $invoiceDiscountAmount = 0;

            if ($discountType === 'FIXED' || (isset($data['discount_amount']) && (int)$data['discount_amount'] > 0 && $invoiceDiscountPercent == 0)) {
                $discountType = 'FIXED';
                $fixedAmount = isset($data['discount_amount']) ? (int)$data['discount_amount'] : (int)$order->discount_amount;
                $invoiceDiscountAmount = min($amountAfterPermDiscount, max(0, $fixedAmount));
            } elseif ($invoiceDiscountPercent > 0) {
                $discountType = 'PERCENT';
                $invoiceDiscountAmount = (int) round(($amountAfterPermDiscount * $invoiceDiscountPercent) / 100);
            }

            $totalAmount = max(0, $amountAfterPermDiscount - $invoiceDiscountAmount);

            $order->update([
                'subtotal' => $subtotal,
                'permanent_discount_percent' => $permDiscountPercent,
                'permanent_discount_amount' => $permDiscountAmount,
                'discount_percent' => $invoiceDiscountPercent,
                'discount_amount' => $invoiceDiscountAmount,
                'discount_type' => $discountType,
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
            if (in_array($newStatus, [SalesOrder::STATUS_DRAFT, SalesOrder::STATUS_CONFIRMED])) {
                if (!$user->hasPermission('orders.create')) {
                    throw ValidationException::withMessages([
                        'status' => 'تۆ ڕێگەپێدراو نیت بۆ گۆڕینی دۆخی پسوڵە بۆ ' . $newStatus
                    ]);
                }
            } elseif ($newStatus === SalesOrder::STATUS_PACKING || $newStatus === SalesOrder::STATUS_READY) {
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
            } elseif ($newStatus === SalesOrder::STATUS_CANCELLED) {
                $canCancel = $user->hasPermission('orders.create')
                    || ($user->hasPermission('stock.pack') && ($currentStatus === SalesOrder::STATUS_CONFIRMED || $currentStatus === SalesOrder::STATUS_PACKING || $currentStatus === SalesOrder::STATUS_READY))
                    || ($user->hasPermission('delivery.update') && $currentStatus === SalesOrder::STATUS_IN_DELIVERY)
                    || $user->isAdmin()
                    || $user->isOwner();

                if (!$canCancel) {
                    throw ValidationException::withMessages([
                        'status' => 'تۆ ڕێگەپێدراو نیت بۆ هەڵوەشاندنەوەی ئەم پسوڵەیە.'
                    ]);
                }

                // ڕێگری لە هەڵوەشاندنەوەی پسوڵەیەک کە کۆمسیۆنی چالاکی بۆ هەژمارکراوە
                $hasActiveCommission = \App\Models\SalesmanCommissionDetail::where('sales_order_id', $lockedOrder->id)
                    ->whereHas('commission', function ($q) {
                        $q->whereIn('status', [
                            \App\Models\SalesmanCommission::STATUS_CALCULATED,
                            \App\Models\SalesmanCommission::STATUS_APPROVED,
                            \App\Models\SalesmanCommission::STATUS_PAID,
                        ]);
                    })
                    ->exists();

                if ($hasActiveCommission) {
                    throw ValidationException::withMessages([
                        'status' => 'ناتوانرێت پسوڵە هەڵبوەشێنرێتەوە چونکە لە کۆمسیۆنێکی چالاکدا بەکارهاتووە. تکایە سەرەتا کۆمسیۆنەکە هەڵوەشێنەرەوە.',
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

                    // Handle unpacked items (partial packing) in deterministic order of product_id ASC to prevent deadlocks
                    $unpackedItems = $lockedOrder->items()->where('is_packed', false)->orderBy('product_id', 'asc')->get();
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

                        $permDiscountAmount = 0;
                        if ($lockedOrder->permanent_discount_percent > 0) {
                            $permDiscountAmount = (int) round(($subtotal * $lockedOrder->permanent_discount_percent) / 100);
                        }
                        $amountAfterPermDiscount = max(0, $subtotal - $permDiscountAmount);

                        $invoiceDiscountAmount = 0;
                        if ($lockedOrder->discount_type === 'FIXED') {
                            $invoiceDiscountAmount = min($amountAfterPermDiscount, (int) $lockedOrder->discount_amount);
                        } elseif ($lockedOrder->discount_percent > 0) {
                            $invoiceDiscountAmount = (int) round(($amountAfterPermDiscount * $lockedOrder->discount_percent) / 100);
                        }
                        $totalAmount = max(0, $amountAfterPermDiscount - $invoiceDiscountAmount);

                        $lockedOrder->update([
                            'subtotal' => $subtotal,
                            'permanent_discount_amount' => $permDiscountAmount,
                            'discount_amount' => $invoiceDiscountAmount,
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
                    // Close any open purchase requirements linked to this cancelled order
                    PurchaseRequirement::where('sales_order_id', $lockedOrder->id)
                        ->where('status', 'OPEN')
                        ->update(['status' => 'CLOSED']);
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
        // Sort items deterministically by product_id ASC to eliminate deadlock risks
        $sortedItems = $order->items->sortBy('product_id');
        foreach ($sortedItems as $item) {
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
                    ->whereIn('status', ['OPEN', 'ORDERED'])
                    ->first();

                if ($existingReq) {
                    if ($existingReq->status === 'OPEN') {
                        $existingReq->update([
                            'required_quantity' => $shortage,
                            'current_stock' => $warehouseStock->quantity,
                        ]);
                    } elseif ($existingReq->status === 'ORDERED') {
                        $additionalShortage = $shortage - $existingReq->required_quantity;
                        if ($additionalShortage > 0) {
                            $product = Product::find($item->product_id);
                            PurchaseRequirement::create([
                                'product_id' => $item->product_id,
                                'warehouse_id' => $order->warehouse_id,
                                'supplier_id' => $product ? $product->supplier_id : null,
                                'sales_order_id' => $order->id,
                                'required_quantity' => $additionalShortage,
                                'current_stock' => $warehouseStock->quantity,
                                'status' => 'OPEN',
                                'created_by' => $user->id,
                            ]);
                        }
                    }
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
        // Sort items deterministically by product_id ASC to eliminate deadlock risks
        $sortedItems = $order->items->sortBy('product_id');
        foreach ($sortedItems as $item) {
            // ١. قفڵکردنی ڕیزی ستۆکی پەیوەندیدار (Step 1: Lock the stock row)
            $warehouseStock = WarehouseStock::lockForUpdate()->where([
                'warehouse_id' => $order->warehouse_id,
                'product_id' => $item->product_id
            ])->first();

            if (!$warehouseStock) {
                // ٦. ئەگەر کاڵاکە لەم کۆگایەدا نەبوو (Step 6: Throw validation exception if record doesn't exist)
                throw ValidationException::withMessages([
                    'stock' => "کاڵای ژمارە {$item->product_id} لەم کۆگایەدا بوونی نییە."
                ]);
            }

            // ٢. سەرلەنوێ خوێندنەوەی بڕی فیزیکی بە شێوەی باوەڕپێکراو (Step 2: Re-read authoritative current quantity)
            $currentQty = $warehouseStock->quantity;

            // ٣. سەرلەنوێ خوێندنەوەی بڕی حجزکراو (Step 3: Re-read authoritative reserved quantity)
            $reservedQty = $warehouseStock->reserved_quantity;

            // ٤. هەژمارکردنی بڕی فیزیکی نوێ دوای کەمکردنەوە (Step 4: Calculate new quantity)
            $newQty = $currentQty - $item->quantity;

            // ٥. پشکنینی دروستیی گۆڕانکاری داواکراو (Step 5: Validate requested deduction)
            if ($newQty < 0) {
                // ٦. هەڵدانی هەڵەی بازرگانی لە کاتی نەبوونی ستۆک (Step 6: Throw business validation exception)
                throw ValidationException::withMessages([
                    'stock' => "بڕی پێویست لە ستۆکی فیزیکی کۆگا بەردەست نییە بۆ جێبەجێکردنی فرۆشتن. کاڵا: {$item->product_id}، بەردەست: {$currentQty}، داواکراو: {$item->quantity}"
                ]);
            }

            // ٧. ئەنجامدانی کردارەکە پاش سەرکەوتنی پشکنینەکان (Step 7: Only then modify stock)
            $warehouseStock->adjustStock(
                -$item->quantity,
                'DELIVERY',
                $user->id,
                'sales_order',
                $order->id
            );
        }
    }

    /**
     * ئازادکردنی بڕی حجزکراو لە کاتی CANCELLED
     */
    private function releaseStock(SalesOrder $order, $user): void
    {
        // Sort items deterministically by product_id ASC to eliminate deadlock risks
        $sortedItems = $order->items->sortBy('product_id');
        foreach ($sortedItems as $item) {
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

    /**
     * Cooperative dual-entry update of a shared order identity.
     * Integrates optimistic locking (versioning) and robust validation.
     */
    public function updateSharedOrder(SalesOrder $order, array $data, $user): SalesOrder
    {
        return DB::transaction(function () use ($order, $data, $user) {
            // Lock order for update to prevent concurrent race conditions
            $order = SalesOrder::lockForUpdate()->findOrFail($order->id);

            // Status consistency check: Shared order can only be edited while it is in DRAFT status
            if ($order->status !== SalesOrder::STATUS_DRAFT) {
                throw new \RuntimeException('ناتوانرێت دەستکاری پسوڵەی هاوبەش بکرێت چونکە پێشتر پەسەندکراوە یان لە پرۆسەدایە.');
            }

            // Concurrent edit validation (optimistic locking / stale client check)
            $clientVersion = isset($data['version']) ? (int) $data['version'] : null;
            if ($clientVersion !== null && $order->version !== $clientVersion) {
                throw ValidationException::withMessages([
                    'version' => 'هەڵەی هاوکاتی: داتاکانی ئەم پسوڵەیە پێشتر لەلایەن ئامێرێکی ترەوە دەستکاری کراون. تکایە پسوڵەکە نوێ بکەرەوە.',
                    'conflict_data' => [
                        'current_version' => $order->version,
                        'order_id' => $order->id,
                        'total_amount' => $order->total_amount,
                    ]
                ]);
            }

            // Lock customer row
            $customer = Customer::lockForUpdate()->findOrFail($data['customer_id']);
            $this->checkCustomerAssignment($customer, $user);

            // Clear old items
            $order->items()->delete();

            $subtotal = 0;
            $totalProfit = 0;

            foreach ($data['items'] as $item) {
                $quantity = (int) $item['quantity'];
                if ($quantity <= 0) {
                    throw ValidationException::withMessages([
                        'items' => 'بڕی کاڵا دەبێت لە ١ کەمتر نەبێت.'
                    ]);
                }

                $product = Product::findOrFail($item['product_id']);

                $priceDetails = $customer->getPriceDetailsForProduct($product);
                $unitPrice = (int) $priceDetails['price'];
                $priceType = $priceDetails['price_type'];
                $costPrice = (int) $product->cost_price;

                $lineTotal = $unitPrice * $quantity;
                $profit = ($unitPrice - $costPrice) * $quantity;

                $order->items()->create([
                    'product_id' => $product->id,
                    'quantity' => $quantity,
                    'unit_price' => $unitPrice,
                    'cost_price' => $costPrice,
                    'price_type' => $priceType,
                    'discount_percent' => 0,
                    'discount_amount' => 0,
                    'line_total' => $lineTotal,
                    'total_price' => $lineTotal,
                    'profit' => $profit,
                    'is_packed' => false,
                ]);

                $subtotal += $lineTotal;
                $totalProfit += $profit;
            }

            $permDiscountPercent = max(0, min(100, (float) ($customer->permanent_discount ?? 0)));
            $permDiscountAmount = 0;
            if ($permDiscountPercent > 0) {
                $permDiscountAmount = (int) round(($subtotal * $permDiscountPercent) / 100);
            }
            $amountAfterPermDiscount = max(0, $subtotal - $permDiscountAmount);

            $discountType = strtoupper($data['discount_type'] ?? 'PERCENT');
            $invoiceDiscountPercent = isset($data['discount_percent']) ? max(0, min(100, (float) $data['discount_percent'])) : 0.0;
            $invoiceDiscountAmount = 0;

            if ($discountType === 'FIXED' || (isset($data['discount_amount']) && (int)$data['discount_amount'] > 0 && $invoiceDiscountPercent == 0)) {
                $discountType = 'FIXED';
                $fixedAmount = (int) ($data['discount_amount'] ?? 0);
                $invoiceDiscountAmount = min($amountAfterPermDiscount, max(0, $fixedAmount));
            } elseif ($invoiceDiscountPercent > 0) {
                $discountType = 'PERCENT';
                $invoiceDiscountAmount = (int) round(($amountAfterPermDiscount * $invoiceDiscountPercent) / 100);
            }

            $totalAmount = max(0, $amountAfterPermDiscount - $invoiceDiscountAmount);

            // Increment version and save order
            $order->update([
                'customer_id' => $customer->id,
                'warehouse_id' => $data['warehouse_id'],
                'notes' => $data['notes'] ?? $order->notes,
                'subtotal' => $subtotal,
                'permanent_discount_percent' => $permDiscountPercent,
                'permanent_discount_amount' => $permDiscountAmount,
                'discount_percent' => $invoiceDiscountPercent,
                'discount_amount' => $invoiceDiscountAmount,
                'discount_type' => $discountType,
                'total_amount' => $totalAmount,
                'total_profit' => $totalProfit,
                'version' => $order->version + 1,
            ]);

            $requestedStatus = $data['status'] ?? $order->status;
            if ($requestedStatus !== $order->status) {
                $order = $this->transitionTo($order, $requestedStatus, $user);
            }

            return $order;
        });
    }
}
