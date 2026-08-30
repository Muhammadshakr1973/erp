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

            app(\App\Services\AuditService::class)->log([
                'action'      => 'CREATE',
                'entity_type' => 'StockTransfer',
                'entity_id'   => $transfer->id,
                'table_name'  => 'stock_transfers',
                'old_values'  => null,
                'new_values'  => [
                    'transfer_number'   => $transfer->transfer_number,
                    'from_warehouse_id' => $transfer->from_warehouse_id,
                    'to_warehouse_id'   => $transfer->to_warehouse_id,
                    'items_count'       => count($data['items']),
                ],
                'description' => "داواکاری گواستنەوەی ستۆک دروستکرا: {$transfer->transfer_number}",
                'user'        => $user,
            ]);

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

            // Sort items deterministically by product_id ASC to eliminate deadlock risks
            $sortedItems = $transfer->items->sortBy('product_id');
            foreach ($sortedItems as $item) {

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

                // کەمکردنەوەی ستۆک لە کۆگای نێرەر و تۆمارکردنی جوڵەکە بە مێتۆدی نوێی ئەنیمەی ستۆک
                $sourceStock->adjustStock(
                    -$item->quantity,
                    'TRANSFER_OUT',
                    $user->id,
                    'stock_transfer',
                    $transfer->id
                );

                // ٢. زیادکردنی ستۆک بۆ کۆگای دووەم (To Warehouse)
                $destinationStock = WarehouseStock::lockForUpdate()->firstOrCreate(
                    ['warehouse_id' => $transfer->to_warehouse_id, 'product_id' => $item->product_id],
                    ['quantity' => 0, 'reserved_quantity' => 0]
                );

                $destinationStock->adjustStock(
                    $item->quantity,
                    'TRANSFER_IN',
                    $user->id,
                    'stock_transfer',
                    $transfer->id
                );
            }

            // ٣. گۆڕینی دۆخی گواستنەوەکە بۆ تەواوبوو
            $transfer->update([
                'status'       => 'COMPLETED',
                'completed_at' => now(),
                'approved_by'  => $user->id,
            ]);

            app(\App\Services\AuditService::class)->log([
                'action'      => 'STOCK_TRANSFER_COMPLETE',
                'entity_type' => 'StockTransfer',
                'entity_id'   => $transfer->id,
                'table_name'  => 'stock_transfers',
                'old_values'  => ['status' => 'DRAFT'],
                'new_values'  => [
                    'status'            => 'COMPLETED',
                    'transfer_number'   => $transfer->transfer_number,
                    'from_warehouse_id' => $transfer->from_warehouse_id,
                    'to_warehouse_id'   => $transfer->to_warehouse_id,
                ],
                'description' => "گواستنەوەی ستۆک تەواوکرا: {$transfer->transfer_number} لە کۆگای #{$transfer->from_warehouse_id} بۆ #{$transfer->to_warehouse_id}",
                'user'        => $user,
            ]);

            return $transfer;
        });
    }
}
