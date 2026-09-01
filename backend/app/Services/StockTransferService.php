<?php

namespace App\Services;

use App\Models\StockTransfer;
use App\Models\WarehouseStock;
use App\Models\Warehouse;
use App\Models\Product;
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
            $fromWarehouseId = (int)$data['from_warehouse_id'];
            $toWarehouseId   = (int)$data['to_warehouse_id'];

            if ($fromWarehouseId === $toWarehouseId) {
                throw ValidationException::withMessages([
                    'to_warehouse_id' => 'کۆگای ناردن و وەرگرتن نابێت هەمان کۆگا بن.',
                ]);
            }

            $fromWarehouse = Warehouse::where('id', $fromWarehouseId)->where('is_active', true)->first();
            $toWarehouse   = Warehouse::where('id', $toWarehouseId)->where('is_active', true)->first();

            if (!$fromWarehouse || !$toWarehouse) {
                throw ValidationException::withMessages([
                    'warehouses' => 'کۆگای دیاریکراو چالاک نییە یان بوونی نییە.',
                ]);
            }

            if (empty($data['items']) || !is_array($data['items'])) {
                throw ValidationException::withMessages([
                    'items' => 'پێویستە لانی کەم یەک کاڵا دیاری بکرێت بۆ گواستنەوە.',
                ]);
            }

            // Normalize and aggregate items by product_id to prevent duplicate database constraints
            $normalizedItems = [];
            foreach ($data['items'] as $item) {
                $pId = (int)($item['product_id'] ?? 0);
                $qty = (int)($item['quantity'] ?? 0);

                if ($qty <= 0) {
                    throw ValidationException::withMessages([
                        'items' => 'بڕی کاڵا دەبێت لە 0 زیاتر بێت.',
                    ]);
                }

                $product = Product::where('id', $pId)->first();
                if (!$product) {
                    throw ValidationException::withMessages([
                        'items' => "کاڵای دیاریکراو بە ناسنامەی {$pId} بوونی نییە.",
                    ]);
                }

                if (isset($normalizedItems[$pId])) {
                    $normalizedItems[$pId]['quantity'] += $qty;
                } else {
                    $normalizedItems[$pId] = [
                        'product_id' => $pId,
                        'quantity'   => $qty,
                        'notes'      => $item['notes'] ?? null,
                    ];
                }
            }

            $transferNumber = 'TRF-' . strtoupper(Str::random(8));

            $transfer = StockTransfer::create([
                'transfer_number'   => $transferNumber,
                'from_warehouse_id' => $fromWarehouseId,
                'to_warehouse_id'   => $toWarehouseId,
                'status'            => StockTransfer::STATUS_DRAFT,
                'notes'             => $data['notes'] ?? null,
                'created_by'        => $user->id,
            ]);

            foreach ($normalizedItems as $itemData) {
                $transfer->items()->create([
                    'product_id' => $itemData['product_id'],
                    'quantity'   => $itemData['quantity'],
                    'notes'      => $itemData['notes'] ?? null,
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
                    'items_count'       => count($normalizedItems),
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
            $lockedTransfer = StockTransfer::lockForUpdate()->with('items')->findOrFail($transfer->id);

            $currentStatus = strtoupper($lockedTransfer->status);
            if ($currentStatus === StockTransfer::STATUS_COMPLETED || $currentStatus === 'COMPLETED') {
                return $lockedTransfer;
            }

            if ($currentStatus === StockTransfer::STATUS_CANCELLED || $currentStatus === 'CANCELLED') {
                throw ValidationException::withMessages([
                    'status' => 'ناتوانرێت گواستنەوەی هەڵوەشاوە جێبەجێ بكرێت.',
                ]);
            }

            // Group items deterministically by product_id ASC to eliminate deadlock risks
            $groupedItems = $lockedTransfer->items
                ->groupBy('product_id')
                ->map(function ($items, $productId) {
                    return [
                        'product_id' => (int)$productId,
                        'quantity'   => (int)$items->sum('quantity'),
                    ];
                })
                ->sortBy('product_id');

            $firstWId = min($lockedTransfer->from_warehouse_id, $lockedTransfer->to_warehouse_id);
            $secondWId = max($lockedTransfer->from_warehouse_id, $lockedTransfer->to_warehouse_id);

            foreach ($groupedItems as $item) {
                $productId = $item['product_id'];
                $quantity  = $item['quantity'];

                // Lock warehouse stock rows in deterministic order of warehouse_id (smaller ID first) to prevent deadlocks
                $firstStock = WarehouseStock::lockForUpdate()->firstOrCreate(
                    ['warehouse_id' => $firstWId, 'product_id' => $productId],
                    ['quantity' => 0, 'reserved_quantity' => 0]
                );
                $secondStock = WarehouseStock::lockForUpdate()->firstOrCreate(
                    ['warehouse_id' => $secondWId, 'product_id' => $productId],
                    ['quantity' => 0, 'reserved_quantity' => 0]
                );

                $sourceStock      = ($lockedTransfer->from_warehouse_id === $firstWId) ? $firstStock : $secondStock;
                $destinationStock = ($lockedTransfer->to_warehouse_id === $firstWId) ? $firstStock : $secondStock;

                // 1. Check physical quantity and reserved quantity
                $currentQty     = $sourceStock->quantity;
                $reservedQty    = $sourceStock->reserved_quantity;
                $availableStock = $currentQty - $reservedQty;

                // 2. Validate available stock for transfer
                if ($availableStock < $quantity) {
                    throw ValidationException::withMessages([
                        'stock' => "کاڵای ژمارە {$productId} بڕی پێویست بەردەست نییە لە کۆگای نێرەر. بەردەست بۆ ناردن: {$availableStock}، بڕی داواکراو: {$quantity}",
                    ]);
                }

                // 3. Deduct stock from source warehouse (TRANSFER_OUT)
                $sourceStock->adjustStock(
                    -$quantity,
                    'TRANSFER_OUT',
                    $user->id,
                    'stock_transfer',
                    $lockedTransfer->id
                );

                // 4. Increase stock in destination warehouse (TRANSFER_IN)
                $destinationStock->adjustStock(
                    $quantity,
                    'TRANSFER_IN',
                    $user->id,
                    'stock_transfer',
                    $lockedTransfer->id
                );
            }

            // 5. Update transfer status to COMPLETED
            $oldStatus = $lockedTransfer->status;
            $lockedTransfer->update([
                'status'         => StockTransfer::STATUS_COMPLETED,
                'completed_at'   => now(),
                'transferred_at' => now(),
                'approved_by'    => $user->id,
            ]);

            app(\App\Services\AuditService::class)->log([
                'action'      => 'STOCK_TRANSFER_COMPLETE',
                'entity_type' => 'StockTransfer',
                'entity_id'   => $lockedTransfer->id,
                'table_name'  => 'stock_transfers',
                'old_values'  => ['status' => $oldStatus],
                'new_values'  => [
                    'status'            => StockTransfer::STATUS_COMPLETED,
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
     * هەڵوەشاندنەوەی داواکاری گواستنەوەی ستۆک (CANCELLED)
     */
    public function cancelTransfer(StockTransfer $transfer, $user): StockTransfer
    {
        return DB::transaction(function () use ($transfer, $user) {
            $lockedTransfer = StockTransfer::lockForUpdate()->findOrFail($transfer->id);

            $currentStatus = strtoupper($lockedTransfer->status);
            if ($currentStatus === StockTransfer::STATUS_CANCELLED || $currentStatus === 'CANCELLED') {
                return $lockedTransfer;
            }

            if ($currentStatus === StockTransfer::STATUS_COMPLETED || $currentStatus === 'COMPLETED') {
                throw ValidationException::withMessages([
                    'status' => 'ناتوانرێت گواستنەوەی جێبەجێکراو هەڵبوەشێنرێتەوە.',
                ]);
            }

            $oldStatus = $lockedTransfer->status;
            $lockedTransfer->update([
                'status' => StockTransfer::STATUS_CANCELLED,
            ]);

            app(\App\Services\AuditService::class)->log([
                'action'      => 'STOCK_TRANSFER_CANCEL',
                'entity_type' => 'StockTransfer',
                'entity_id'   => $lockedTransfer->id,
                'table_name'  => 'stock_transfers',
                'old_values'  => ['status' => $oldStatus],
                'new_values'  => ['status' => StockTransfer::STATUS_CANCELLED],
                'description' => "داواکاری گواستنەوەی ستۆک هەڵوەشێنرایەوە: {$lockedTransfer->transfer_number}",
                'user'        => $user,
            ]);

            return $lockedTransfer;
        });
    }
}

