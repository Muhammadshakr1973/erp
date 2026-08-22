<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\Product;
use App\Models\SalesOrder;
use App\Models\WarehouseStock;
use App\Models\StockTransaction;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class SalesOrderService
{
    /**
     * دروستکردنی پسوڵەی فرۆشتن
     */
    public function createOrder(array $data, $user): SalesOrder
    {
        // بەکارهێنانی Database Transaction بۆ ئەوەی ئەگەر لە هەر جێگایەک هەڵە ڕوویدا،
        // هەموو گۆڕانکارییەکانی ستۆک و پارە بەتاڵ بکرێنەوە (Rollback).
        return DB::transaction(function () use ($data, $user) {

            $customer = Customer::findOrFail($data['customer_id']);

            // دروستکردنی ژمارەی تایبەت بۆ پسوڵە (نموونە: ORD-12345678)
            $orderNumber = 'ORD-' . strtoupper(Str::random(8));

            // دروستکردنی پەڕەی سەرەکی پسوڵەکە بە شێوەی Draft
            $order = SalesOrder::create([
                'order_number' => $orderNumber,
                'customer_id' => $customer->id,
                'salesman_id' => $user->id, // مەندوبەکە
                'warehouse_id' => $data['warehouse_id'],
                'order_date' => now()->toDateString(),
                'status' => SalesOrder::STATUS_DRAFT, // بەپێی مۆدێلەکەت 'draft'
                'discount_percent' => $data['discount_percent'] ?? 0,
                'notes' => $data['notes'] ?? null,
                'created_by' => $user->id,

                // ئەم بەهایانە دواتر لە کاتی خولانەوە (Loop) پڕیان دەکەینەوە
                'subtotal' => 0,
                'discount_amount' => 0,
                'total_amount' => 0,
                'total_profit' => 0,
            ]);

            $subtotal = 0;
            $totalProfit = 0;

            // خولانەوە بەسەر هەموو ئایتمەکانی ناو پسوڵەکە
            foreach ($data['items'] as $item) {
                $product = Product::findOrFail($item['product_id']);

                // ١. دیاریکردنی نرخی فرۆشتن (بەپێی جۆری کڕیار یان نرخی تایبەت)
                $unitPrice = $customer->getCurrentPriceForProduct($product);

                $lineTotal = $unitPrice * $item['quantity'];
                $profit = ($unitPrice - $product->cost_price) * $item['quantity'];

                // ٢. پاشەکەوتکردنی ئایتمەکە (Snapshot Principle)
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

                // ٣. حجزکردنی ستۆک (Reserve Stock) لە کۆگا
                $warehouseStock = WarehouseStock::firstOrCreate(
                    ['warehouse_id' => $order->warehouse_id, 'product_id' => $product->id],
                    ['quantity' => 0, 'reserved_quantity' => 0]
                );

                // زیادکردنی بڕی حجزکراو (وەک داواکارییەکەی دۆکیومێنتەکەت)
                $warehouseStock->increment('reserved_quantity', $item['quantity']);

                // تۆمارکردنی جوڵەی ستۆک لە مێژوو (Stock Transaction)
                StockTransaction::create([
                    'warehouse_id' => $order->warehouse_id,
                    'product_id' => $product->id,
                    'type' => StockTransaction::TYPE_RESERVED, // 'reserved'
                    'quantity_change' => $item['quantity'],
                    'reference_type' => 'sales_order',
                    'reference_id' => $order->id,
                    'created_by' => $user->id,
                ]);
            }

            // هەژمارکردنی داشکاندن و نرخی کۆتایی
            $discountAmount = 0;
            if ($order->discount_percent > 0) {
                $discountAmount = ($subtotal * $order->discount_percent) / 100;
            }
            $totalAmount = $subtotal - $discountAmount;

            // نوێکردنەوەی پسوڵەکە بە بڕە کۆتاییەکان
            $order->update([
                'subtotal' => $subtotal,
                'discount_amount' => $discountAmount,
                'total_amount' => $totalAmount,
                'total_profit' => $totalProfit,
            ]);

            return $order;
        });
    }
}
