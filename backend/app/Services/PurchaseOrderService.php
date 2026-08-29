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

            return $order;
        });
    }

    /**
     * وەرگرتنی کاڵاکان لە کۆگا (زیادکردنی ستۆک و تۆمارکردنی قەرزی کۆمپانیا)
     */
    public function receiveOrder(PurchaseOrder $order, $user): PurchaseOrder
    {
        if ($order->status === 'RECEIVED') {
            throw ValidationException::withMessages(['status' => 'ئەم پسوڵەیە پێشتر وەرگیراوە.']);
        }

        return DB::transaction(function () use ($order, $user) {

            $supplier = Supplier::lockForUpdate()->findOrFail($order->supplier_id);

            foreach ($order->items as $item) {
                // ١. زیادکردنی ستۆک لە کۆگا
                $warehouseStock = WarehouseStock::lockForUpdate()->firstOrCreate(
                    ['warehouse_id' => $order->warehouse_id, 'product_id' => $item->product_id],
                    ['quantity' => 0, 'reserved_quantity' => 0]
                );

                $warehouseStock->increment('quantity', $item->quantity);

                // (دەتوانیت لێرەدا Average Cost ی کاڵاکەش هەژمار بکەیت و ئەپدەیتی بکەیت لە مۆدێلی Product ئەگەر پێویست بوو)

                // ٢. تۆمارکردنی جوڵەی ستۆک (PURCHASE)
                StockTransaction::create([
                    'warehouse_id'    => $order->warehouse_id,
                    'product_id'      => $item->product_id,
                    'type'            => 'PURCHASE', // هاتنە ناوەوەی کاڵا
                    'quantity_change' => $item->quantity, // موجەبە چونکە زیاد دەکات
                    'reference_type'  => 'purchase_order',
                    'reference_id'    => $order->id,
                    'created_by'      => $user->id,
                ]);

                // نوێکردنەوەی بڕی وەرگیراو لەناو ئایتمەکە
                $item->update(['received_quantity' => $item->quantity]);
            }

            // ٣. هەژمارکردنی قەرزی کۆمپانیا (ئێمە قەرزدار دەبین)
            // پێویستە لە داتابەیسەکەتدا current_balance بۆ Supplier هەبێت، یان لە لیجەرەوە کۆی بکەیتەوە
            // بۆ سادەیی، لێرە ڕاستەوخۆ دەیخەینە ناو SupplierLedger بە دۆخی Credit (واتە پارەی لای ئێمەیە)

            // هەژمارکردنی بالانسی پێشوو لە لیجەرەوە (وەک ئەوەی لە CustomerLedger کردمان)
            $lastLedger = SupplierLedger::where('supplier_id', $supplier->id)->orderByDesc('id')->first();
            $previousBalance = $lastLedger ? $lastLedger->balance_after : 0;
            $newBalance = $previousBalance + $order->total_amount; // قەرزەکەمان زیاد دەکات

            SupplierLedger::create([
                'supplier_id'    => $supplier->id,
                'entry_type'     => 'PURCHASE',
                'type'           => 'credit',
                'debit'          => 0,
                'credit'         => $order->total_amount,
                'amount'         => $order->total_amount,
                'balance_before' => $previousBalance,
                'balance_after'  => $newBalance,
                'reference_type' => 'purchase_order',
                'reference_id'   => $order->id,
                'description'    => "کڕینی کاڵا بە پسوڵەی {$order->order_number}",
                'created_by'     => $user->id,
            ]);

            // ٤. گۆڕینی دۆخی پسوڵەکە بۆ RECEIVED
            $order->update([
                'status'      => 'RECEIVED',
                'received_at' => now(),
            ]);

            return $order;
        });
    }
}
