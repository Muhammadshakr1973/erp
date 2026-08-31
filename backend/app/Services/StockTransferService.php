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
        return DB::transaction(function () use ($transfer, $user) {
            $lockedTransfer = StockTransfer::lockForUpdate()->findOrFail($transfer->id);

            $currentStatus = strtolower($lockedTransfer->status);
            if ($currentStatus === 'completed' || $currentStatus === StockTransfer::STATUS_COMPLETED) {
                return $lockedTransfer;
            }

            if ($currentStatus === 'cancelled' || $currentStatus === StockTransfer::STATUS_CANCELLED) {
                throw ValidationException::withMessages(['status' => 'ناتوانرێت گواستنەوەی هەڵوەشاوە جێبەجێ بكرێت.']);
            }

            // Sort items deterministically by product_id ASC to eliminate deadlock risks
            $sortedItems = $lockedTransfer->items->sortBy('product_id');
            foreach ($sortedItems as $item) {

                // ١. قفڵکردنی ڕیزی ستۆکی کۆگای نێرەر (Step 1: Lock the source stock row)
                $sourceStock = WarehouseStock::lockForUpdate()->firstOrCreate(
                    ['warehouse_id' => $lockedTransfer->from_warehouse_id, 'product_id' => $item->product_id],
                    ['quantity' => 0, 'reserved_quantity' => 0]
                );

                // ٢. خوێندنەوەی بڕی فیزیکی پێشوو (Step 2: Re-read authoritative current quantity)
                $currentQty = $sourceStock->quantity;

                // ٣. خوێندنەوەی بڕی حجزکراوی پێشوو (Step 3: Re-read authoritative reserved quantity)
                $reservedQty = $sourceStock->reserved_quantity;

                // ٤. هەژمارکردنی بڕی بەردەستی باوەڕپێکراو (Step 4: Calculate authoritative available quantity)
                $availableStock = $currentQty - $reservedQty;

                // ٥. پشکنینی گونجاویی بڕی داواکراوی گواستنەوە (Step 5: Validate requested deduction)
                if ($availableStock < $item->quantity) {
                    // ٦. هەڵدانی هەڵەی گونجاو لە کاتی نەبوونی ستۆکی بەردەست (Step 6: Throw business validation exception if insufficient)
                    throw ValidationException::withMessages([
                        'stock' => "کاڵای ژمارە {$item->product_id} بڕی پێویست بەردەست نییە لە کۆگای نێرەر. بەردەست بۆ ناردن: {$availableStock}، بڕی داواکراو: {$item->quantity}",
                    ]);
                }

                // ٧. کەمکردنەوەی ستۆک لە کۆگای نێرەر پاش پەسەندکردنی مەرجەکان (Step 7: Only then modify stock)
                $sourceStock->adjustStock(
                    -$item->quantity,
                    'TRANSFER_OUT',
                    $user->id,
                    'stock_transfer',
                    $lockedTransfer->id
                );

                // ٢. زیادکردنی ستۆک بۆ کۆگای دووەم (To Warehouse)
                $destinationStock = WarehouseStock::lockForUpdate()->firstOrCreate(
                    ['warehouse_id' => $lockedTransfer->to_warehouse_id, 'product_id' => $item->product_id],
                    ['quantity' => 0, 'reserved_quantity' => 0]
                );

                $destinationStock->adjustStock(
                    $item->quantity,
                    'TRANSFER_IN',
                    $user->id,
                    'stock_transfer',
                    $lockedTransfer->id
                );
            }

            // ٣. گۆڕینی دۆخی گواستنەوەکە بۆ تەواوبوو
            $lockedTransfer->update([
                'status'       => 'COMPLETED',
                'completed_at' => now(),
                'approved_by'  => $user->id,
            ]);

            app(\App\Services\AuditService::class)->log([
                'action'      => 'STOCK_TRANSFER_COMPLETE',
                'entity_type' => 'StockTransfer',
                'entity_id'   => $lockedTransfer->id,
                'table_name'  => 'stock_transfers',
                'old_values'  => ['status' => $currentStatus],
                'new_values'  => [
                    'status'            => 'COMPLETED',
                    'transfer_number'   => $lockedTransfer->transfer_number,
                    'from_warehouse_id' => $lockedTransfer->from_warehouse_id,
                    'to_warehouse_id'   => $lockedTransfer->to_warehouse_id,
                ],
                'description' => "گواستنەوەی ستۆک تەواوکرا: {$lockedTransfer->transfer_number} لە کۆگای #{$lockedTransfer->from_warehouse_id} بۆ #{$lockedTransfer->to_warehouse_id}",
                'user'        => $user,
            ]);

            return $lockedTransfer;
        });
    }

    /**
     * هەڵوەشاندنەوەی گواستنەوەی ستۆک
     */
    public function cancelTransfer(StockTransfer $transfer, $user): StockTransfer
    {
        return DB::transaction(function () use ($transfer, $user) {
            $lockedTransfer = StockTransfer::lockForUpdate()->findOrFail($transfer->id);

            $currentStatus = strtolower($lockedTransfer->status);
            if ($currentStatus === 'cancelled' || $currentStatus === StockTransfer::STATUS_CANCELLED) {
                return $lockedTransfer;
            }

            if ($currentStatus === 'completed' || $currentStatus === StockTransfer::STATUS_COMPLETED) {
                throw ValidationException::withMessages(['status' => 'ناتوانرێت گواستنەوەی جێبەجێکراو هەڵبوەشێنرێتەوە.']);
            }

            $oldStatus = $lockedTransfer->status;
            $lockedTransfer->update(['status' => 'CANCELLED']);

            app(\App\Services\AuditService::class)->log([
                'action'      => 'STOCK_TRANSFER_CANCEL',
                'entity_type' => 'StockTransfer',
                'entity_id'   => $lockedTransfer->id,
                'table_name'  => 'stock_transfers',
                'old_values'  => ['status' => $oldStatus],
                'new_values'  => ['status' => 'CANCELLED'],
                'description' => "داواکاری گواستنەوەی ستۆک هەڵوەشێنرایەوە: {$lockedTransfer->transfer_number}",
                'user'        => $user,
            ]);

            return $lockedTransfer;
        });
    }
}
