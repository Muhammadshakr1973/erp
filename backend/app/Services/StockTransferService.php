<?php

namespace App\Services;

use App\Models\StockTransfer;
use App\Models\WarehouseStock;
use App\Models\StockTransaction;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;
use Illuminate\Support\Str;

class StockTransferService
{
    /**
     * دروستکردنی داواکاری گواستنەوە (DRAFT)
     */
    public function createTransfer(array $data, $user): StockTransfer
    {
        return DB::transaction(function () use ($data, $user) {

            $transferNumber = 'TRF-' . strtoupper(Str::random(8));

            $transfer = StockTransfer::create([
                'transfer_number'   => $transferNumber,
                'from_warehouse_id' => $data['from_warehouse_id'],
                'to_warehouse_id'   => $data['to_warehouse_id'],
                'status'            => 'DRAFT',
                'notes'             => $data['notes'] ?? null,
                'created_by'        => $user->id,
            ]);

            foreach ($data['items'] as $item) {
                $transfer->items()->create([
                    'product_id' => $item['product_id'],
                    'quantity'   => $item['quantity'],
                ]);
            }

            return $transfer;
        });
    }

    /**
     * جێبەجێکردنی گواستنەوەکە (COMPLETED)
     */
    public function completeTransfer(StockTransfer $transfer, $user): StockTransfer
    {
        if ($transfer->status === 'COMPLETED') {
            throw ValidationException::withMessages(['status' => 'ئەم گواستنەوەیە پێشتر جێبەجێ کراوە.']);
        }

        return DB::transaction(function () use ($transfer, $user) {

            foreach ($transfer->items as $item) {

                // ١. هێنانی ستۆک لە کۆگای یەکەم (From Warehouse)
                $sourceStock = WarehouseStock::lockForUpdate()->firstOrCreate(
                    ['warehouse_id' => $transfer->from_warehouse_id, 'product_id' => $item->product_id],
                    ['quantity' => 0, 'reserved_quantity' => 0]
                );

                // پشکنین بزانین ئایا ستۆکی بەردەست بەشی ئەم گواستنەوەیە دەکات؟ (quantity - reserved)
                $availableStock = $sourceStock->quantity - $sourceStock->reserved_quantity;
                if ($availableStock < $item->quantity) {
                    throw ValidationException::withMessages([
                        'stock' => "کاڵای ژمارە {$item->product_id} بڕی پێویست بەردەست نییە لە کۆگای نێرەر. بەردەست: {$availableStock}",
                    ]);
                }

                // کەمکردنەوەی ستۆک لە کۆگای نێرەر
                $sourceStock->decrement('quantity', $item->quantity);

                StockTransaction::create([
                    'warehouse_id'    => $transfer->from_warehouse_id,
                    'product_id'      => $item->product_id,
                    'type'            => 'TRANSFER_OUT',
                    'quantity_change' => -$item->quantity, // بە سالب دەچێتە دەرەوە
                    'reference_type'  => 'stock_transfer',
                    'reference_id'    => $transfer->id,
                    'created_by'      => $user->id,
                ]);

                // ٢. زیادکردنی ستۆک بۆ کۆگای دووەم (To Warehouse)
                $destinationStock = WarehouseStock::lockForUpdate()->firstOrCreate(
                    ['warehouse_id' => $transfer->to_warehouse_id, 'product_id' => $item->product_id],
                    ['quantity' => 0, 'reserved_quantity' => 0]
                );

                $destinationStock->increment('quantity', $item->quantity);

                StockTransaction::create([
                    'warehouse_id'    => $transfer->to_warehouse_id,
                    'product_id'      => $item->product_id,
                    'type'            => 'TRANSFER_IN',
                    'quantity_change' => $item->quantity, // بە موجەب دێتە ناوەوە
                    'reference_type'  => 'stock_transfer',
                    'reference_id'    => $transfer->id,
                    'created_by'      => $user->id,
                ]);
            }

            // ٣. گۆڕینی دۆخی گواستنەوەکە بۆ تەواوبوو
            $transfer->update([
                'status'       => 'COMPLETED',
                'completed_at' => now(),
                'approved_by'  => $user->id,
            ]);

            return $transfer;
        });
    }
}
