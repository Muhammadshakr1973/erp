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

            // کاتێک پسوڵە بە سەرکەوتوویی دروستکرا، ڕاستەوخۆ دەیدەینە ڕەوتی پشتڕاستکردنەوە (CONFIRMED) بۆ حجزکردنی ستۆک
            return $this->transitionTo($order, SalesOrder::STATUS_CONFIRMED, $user);
        });
    }

    /**
     * جێبەجێکردنی گواستنەوەی دۆخی پسوڵەکان بە شێوەی دەوڵەتی (State Machine)
     */
    public function transitionTo(SalesOrder $order, string $newStatus, $user): SalesOrder
    {
        return DB::transaction(function () use ($order, $newStatus, $user) {
            $currentStatus = $order->status;

            if ($currentStatus === $newStatus) {
                return $order;
            }

            // دڵنیابوونەوە لە ڕاستی دۆخی نوێ و یاساکانی گواستنەوە
            switch ($newStatus) {
                case SalesOrder::STATUS_CONFIRMED:
                    if ($currentStatus !== SalesOrder::STATUS_DRAFT) {
                        throw ValidationException::withMessages(['status' => 'تەنها پسوڵەی داڕشتن (Draft) دەکرێت پشتڕاست بکرێتەوە.']);
                    }
                    $this->reserveStock($order, $user);
                    $order->confirmed_at = now();
                    break;

                case SalesOrder::STATUS_PACKING:
                    if ($currentStatus !== SalesOrder::STATUS_CONFIRMED) {
                        throw ValidationException::withMessages(['status' => 'پێویستە سەرەتا پسوڵەکە پشتڕاستکراوە بێت (Confirmed).']);
                    }
                    break;

                case SalesOrder::STATUS_READY:
                    if ($currentStatus !== SalesOrder::STATUS_PACKING && $currentStatus !== SalesOrder::STATUS_CONFIRMED) {
                        throw ValidationException::withMessages(['status' => 'گۆڕین بۆ ئامادە تەنها لە حاڵەتی پشتڕاستکردنەوە یان پاکەتکردن دەبێت.']);
                    }
                    $order->ready_at = now();
                    break;

                case SalesOrder::STATUS_IN_DELIVERY:
                    if ($currentStatus !== SalesOrder::STATUS_READY) {
                        throw ValidationException::withMessages(['status' => 'تەنها پسوڵەی ئامادەکراو (Ready) دەتوانێت بنێردرێت بۆ گەیاندن.']);
                    }
                    break;

                case SalesOrder::STATUS_DELIVERED:
                    if ($currentStatus !== SalesOrder::STATUS_IN_DELIVERY) {
                        throw ValidationException::withMessages(['status' => 'گۆڕین بۆ گەیشتوو تەنها بۆ ئەو پسوڵانەیە کە لە ڕێگەی گەیاندندان.']);
                    }
                    $this->finalizeStockSale($order, $user);
                    $this->postToCustomerLedger($order, $user);
                    $order->delivered_at = now();
                    break;

                case SalesOrder::STATUS_CANCELLED:
                    if ($currentStatus === SalesOrder::STATUS_DELIVERED || $currentStatus === SalesOrder::STATUS_IN_DELIVERY) {
                        throw ValidationException::withMessages(['status' => 'ناتوانرێت پسوڵەی گەیندراو یان لە ڕێگەی گەیاندن هەڵبوەشێنرێتەوە.']);
                    }
                    $this->releaseStock($order, $user);
                    break;

                default:
                    throw ValidationException::withMessages(['status' => 'دۆخێکی نەناسراو دیاریکراوە.']);
            }

            // ئەگەر پسوڵەکە لێرە ئەبدەیت کرا
            $order->status = $newStatus;
            $order->save();

            // تۆمارکردنی مێژووی چالاکی بۆ سیستەم (Audit Logging)
            $this->logActivity($order, $currentStatus, $newStatus, $user);

            return $order;
        });
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
                    ->where('warehouse_id', $order->warehouse_id)
                    ->where('status', 'OPEN')
                    ->first();

                if ($existingReq) {
                    $existingReq->increment('required_quantity', $shortage);
                } else {
                    $product = Product::find($item->product_id);
                    PurchaseRequirement::create([
                        'product_id' => $item->product_id,
                        'warehouse_id' => $order->warehouse_id,
                        'supplier_id' => $product->supplier_id,
                        'required_quantity' => $shortage,
                        'current_stock' => $warehouseStock->quantity,
                        'status' => 'OPEN',
                        'created_by' => $user->id,
                    ]);
                }

                // حجزکردنی ئەوەی کە بەردەستە
                $reservedToAdd = max(0, $availableStock);
            } else {
                $reservedToAdd = $item->quantity;
            }

            if ($reservedToAdd > 0) {
                $warehouseStock->increment('reserved_quantity', $reservedToAdd);

                // تۆمارکردنی جوڵەی ستۆک (RESERVE)
                StockTransaction::create([
                    'warehouse_id' => $order->warehouse_id,
                    'product_id' => $item->product_id,
                    'type' => 'RESERVE',
                    'quantity_change' => $reservedToAdd,
                    'quantity_after' => $warehouseStock->quantity,
                    'reference_type' => 'sales_order',
                    'reference_id' => $order->id,
                    'created_by' => $user->id,
                ]);
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
                // کەمکردنەوەی بڕی گشتی و بڕی حجزکراو بە تێکڕا
                $newQty = max(0, $warehouseStock->quantity - $item->quantity);
                $newReserved = max(0, $warehouseStock->reserved_quantity - $item->quantity);

                $warehouseStock->update([
                    'quantity' => $newQty,
                    'reserved_quantity' => $newReserved
                ]);

                // تۆمارکردنی کەمبوونەکە (DELIVERY/out)
                StockTransaction::create([
                    'warehouse_id' => $order->warehouse_id,
                    'product_id' => $item->product_id,
                    'type' => 'DELIVERY',
                    'quantity_change' => -$item->quantity,
                    'quantity_after' => $newQty,
                    'reference_type' => 'sales_order',
                    'reference_id' => $order->id,
                    'created_by' => $user->id,
                ]);
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
                // ئەگەر پێشتر حجز کرابوو، بڕی حجزکراوی لێ دەردەکەینەوە
                $releasedQty = min($warehouseStock->reserved_quantity, $item->quantity);

                if ($releasedQty > 0) {
                    $warehouseStock->decrement('reserved_quantity', $releasedQty);

                    StockTransaction::create([
                        'warehouse_id' => $order->warehouse_id,
                        'product_id' => $item->product_id,
                        'type' => 'RELEASE',
                        'quantity_change' => -$releasedQty,
                        'quantity_after' => $warehouseStock->quantity,
                        'reference_type' => 'sales_order',
                        'reference_id' => $order->id,
                        'created_by' => $user->id,
                    ]);
                }
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
        DB::table('sync_logs')->insert([
            'user_id' => $user->id,
            'entity_type' => 'sales_order',
            'entity_id' => $order->id,
            'table_name' => 'sales_orders',
            'action' => 'UPDATE',
            'status' => 'success',
            'payload' => json_encode([
                'order_number' => $order->order_number,
                'old_status' => $oldStatus,
                'new_status' => $newStatus,
                'user_name' => $user->name,
                'timestamp' => now()->toDateTimeString(),
            ]),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
