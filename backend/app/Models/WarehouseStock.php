<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class WarehouseStock extends Model
{
    use HasFactory;
    protected $table = 'warehouse_stock';
    protected $fillable = ['warehouse_id', 'product_id', 'quantity', 'reserved_quantity', 'min_stock_level', 'max_stock_level', 'average_cost'];
    protected $casts = ['quantity' => 'integer', 'reserved_quantity' => 'integer', 'min_stock_level' => 'integer'];
    public function warehouse()
    {
        return $this->belongsTo(Warehouse::class);
    }
    public function product()
    {
        return $this->belongsTo(Product::class);
    }
    public function getAvailableAttribute(): int
    {
        return $this->quantity - $this->reserved_quantity;
    }
    public function getIsLowAttribute(): bool
    {
        return $this->quantity <= $this->min_stock_level;
    }
    public function getIsOutAttribute(): bool
    {
        return $this->quantity <= 0;
    }
    public function scopeLowStock($q)
    {
        return $q->whereColumn('quantity', '<=', 'min_stock_level');
    }
    public function scopeInStock($q)
    {
        return $q->where('quantity', '>', 0);
    }

    public function adjustStock(int $quantityChange, string $type, $userId, $referenceType = null, $referenceId = null, $notes = null): StockTransaction
    {
        return DB::transaction(function () use ($quantityChange, $type, $userId, $referenceType, $referenceId, $notes) {
            // ١. قفڵکردنی ڕیزی پەیوەندیداری ستۆک (Step 1: Lock the stock row)
            $locked = self::lockForUpdate()->find($this->id);

            // ٢. سەرلەنوێ خوێندنەوەی بڕی فیزیکی پێشوو بە شێوەی باوەڕپێکراو (Step 2: Re-read authoritative current quantity)
            $currentQty = $locked->quantity;

            // ٣. سەرلەنوێ خوێندنەوەی بڕی حجزکراو بە شێوەی باوەڕپێکراو (Step 3: Re-read authoritative reserved quantity)
            $reservedQty = $locked->reserved_quantity;

            // ٤. هەژمارکردنی بڕی فیزیکی نوێ (Step 4: Calculate new quantity)
            $newQty = $currentQty + $quantityChange;

            // ٥. پشکنینی دروستیی گۆڕانکاری داواکراو (Step 5: Validate requested deduction)
            if ($newQty < 0) {
                // ٦. هەڵدانی هەڵەی گونجاو لە کاتی نەبوونی ستۆک (Step 6: Throw business validation exception if insufficient)
                throw ValidationException::withMessages([
                    'stock' => "بڕی پێویست لە ستۆکی فیزیکی بەردەست نییە. کۆی گشتی ستۆک ناتوانێت لە صفر کەمتر بێت. بەردەست: {$currentQty}، بڕی داواکراوی کەمکردنەوە: " . abs($quantityChange)
                ]);
            }

            // ٧. گۆڕینی ستۆک و پاشەکەوتکردن (Step 7: Only then modify stock)
            $upperType = strtoupper($type);
            $newReserved = $reservedQty;
            if ($quantityChange < 0 && in_array($upperType, ['DELIVERY', 'SALE'])) {
                $newReserved = max(0, $reservedQty - abs($quantityChange));
            } elseif ($quantityChange < 0 && $upperType === 'ADJUSTMENT') {
                if ($newQty < $reservedQty) {
                    throw ValidationException::withMessages([
                        'stock' => "ناتوانرێت ستۆک کەمبکرێتەوە بۆ خوار بڕی حجزکراو ({$reservedQty} یەکە حجزکراوە). بڕی فیزیکی پێشوو: {$currentQty}، بڕی داواکراو دوای کەمکردنەوە: {$newQty}"
                    ]);
                }
            } elseif ($quantityChange < 0 && $upperType === 'TRANSFER_OUT') {
                $available = $currentQty - $reservedQty;
                if ($available < abs($quantityChange)) {
                    throw ValidationException::withMessages([
                        'stock' => "ستۆکی بەردەست بەس نییە بۆ گواستنەوە. بەردەست: {$available}، بڕی گواستنەوە: " . abs($quantityChange)
                    ]);
                }
            }

            $locked->quantity = $newQty;
            $locked->reserved_quantity = $newReserved;
            $locked->save();

            $transaction = StockTransaction::create([
                'warehouse_id' => $locked->warehouse_id,
                'product_id' => $locked->product_id,
                'type' => $upperType,
                'quantity_change' => $quantityChange,
                'quantity_after' => $newQty,
                'reference_type' => $referenceType,
                'reference_id' => $referenceId,
                'notes' => $notes,
                'created_by' => $userId,
            ]);

            app(\App\Services\AuditService::class)->logStockMovement(
                $upperType,
                $locked->warehouse_id,
                $locked->product_id,
                $quantityChange,
                $newQty,
                $notes ?? "دەستکاری ستۆک: {$quantityChange} یەکە لە کۆگای #{$locked->warehouse_id}",
                $referenceType,
                $referenceId,
                $userId
            );

            return $transaction;
        });
    }

    public function reserveStock(int $amount, $userId, $referenceType = null, $referenceId = null, $notes = null): ?StockTransaction
    {
        if ($amount <= 0) {
            throw new \InvalidArgumentException('بڕی حجز دەبێت لە ٠ زیاتر بێت.');
        }

        return DB::transaction(function () use ($amount, $userId, $referenceType, $referenceId, $notes) {
            // ١. قفڵکردنی ڕیزی ستۆکی پەیوەندیدار (Step 1: Lock the stock row)
            $locked = self::lockForUpdate()->find($this->id);

            // ٢. سەرلەنوێ خوێندنەوەی بڕی فیزیکی بە شێوەی باوەڕپێکراو (Step 2: Re-read authoritative current quantity)
            $currentQty = $locked->quantity;

            // ٣. سەرلەنوێ خوێندنەوەی بڕی حجزکراوی پێشوو (Step 3: Re-read authoritative reserved quantity)
            $reservedQty = $locked->reserved_quantity;

            // ٤. هەژمارکردنی ستۆکی بەردەست بە شێوەی باوەڕپێکراو (Step 4: Calculate authoritative available quantity)
            $available = $currentQty - $reservedQty;

            // ٥. پشکنینی بڕی حجزکردنی داواکراو (Step 5: Validate requested reservation)
            if ($available < $amount) {
                // ٦. هەڵدانی هەڵەی گونجاوی بازرگانی لە کاتی نەبوونی ستۆکی بەردەست (Step 6: Throw business validation exception)
                throw ValidationException::withMessages([
                    'stock' => "بڕی پێویست لە ستۆکی بەردەست نییە بۆ حجزکردن. بەردەست بۆ حجز: {$available}، بڕی داواکراو: {$amount}"
                ]);
            }

            // ٧. ئەنجامدانی حجزەکە پاش سەرکەوتنی پشکنینەکان (Step 7: Only then modify stock)
            $locked->reserved_quantity += $amount;
            $locked->save();

            $transaction = StockTransaction::create([
                'warehouse_id' => $locked->warehouse_id,
                'product_id' => $locked->product_id,
                'type' => 'RESERVE',
                'quantity_change' => $amount,
                'quantity_after' => $locked->quantity,
                'reference_type' => $referenceType,
                'reference_id' => $referenceId,
                'notes' => $notes,
                'created_by' => $userId,
            ]);

            app(\App\Services\AuditService::class)->logStockMovement(
                'STOCK_RESERVE',
                $locked->warehouse_id,
                $locked->product_id,
                $amount,
                $locked->quantity,
                $notes ?? "حجزکردنی ستۆک: {$amount} یەکە بۆ کاڵا #{$locked->product_id}",
                $referenceType,
                $referenceId,
                $userId
            );

            return $transaction;
        });
    }

    public function releaseStock(int $amount, $userId, $referenceType = null, $referenceId = null, $notes = null): ?StockTransaction
    {
        if ($amount <= 0) {
            throw new \InvalidArgumentException('بڕی ئازادکردن دەبێت لە ٠ زیاتر بێت.');
        }

        return DB::transaction(function () use ($amount, $userId, $referenceType, $referenceId, $notes) {
            $locked = self::lockForUpdate()->find($this->id);

            $released = min($locked->reserved_quantity, $amount);
            if ($released > 0) {
                $locked->reserved_quantity -= $released;
                $locked->save();

                $transaction = StockTransaction::create([
                    'warehouse_id' => $locked->warehouse_id,
                    'product_id' => $locked->product_id,
                    'type' => 'RELEASE',
                    'quantity_change' => -$released,
                    'quantity_after' => $locked->quantity,
                    'reference_type' => $referenceType,
                    'reference_id' => $referenceId,
                    'notes' => $notes,
                    'created_by' => $userId,
                ]);

                app(\App\Services\AuditService::class)->logStockMovement(
                    'STOCK_RELEASE',
                    $locked->warehouse_id,
                    $locked->product_id,
                    -$released,
                    $locked->quantity,
                    $notes ?? "ئازادکردنی ستۆکی حجزکراو: {$released} یەکە",
                    $referenceType,
                    $referenceId,
                    $userId
                );

                return $transaction;
            }

            return null;
        });
    }

    public function reconcile(): array
    {
        $transactions = StockTransaction::where('warehouse_id', $this->warehouse_id)
            ->where('product_id', $this->product_id)
            ->orderBy('id', 'asc')
            ->get();

        $calculatedQty = 0;
        $calculatedReserved = 0;
        $discrepancies = [];

        foreach ($transactions as $tx) {
            $type = strtoupper($tx->type);
            if ($type === 'RESERVE' || $type === 'RESERVED') {
                $calculatedReserved += abs($tx->quantity_change);
            } elseif ($type === 'RELEASE' || $type === 'UNRESERVED') {
                $calculatedReserved = max(0, $calculatedReserved - abs($tx->quantity_change));
            } else {
                $calculatedQty += $tx->quantity_change;

                if (in_array($type, ['DELIVERY', 'SALE'])) {
                    $calculatedReserved = max(0, $calculatedReserved - abs($tx->quantity_change));
                }
            }

            if ($tx->quantity_after != $calculatedQty) {
                $discrepancies[] = "Transaction ID {$tx->id}: quantity_after stored as {$tx->quantity_after}, calculated as {$calculatedQty}";
            }
        }

        $isConsistent = empty($discrepancies)
            && ($this->quantity == $calculatedQty)
            && ($this->reserved_quantity == $calculatedReserved);

        return [
            'is_consistent' => $isConsistent,
            'stored_quantity' => (int) $this->quantity,
            'recalculated_quantity' => (int) $calculatedQty,
            'stored_reserved' => (int) $this->reserved_quantity,
            'recalculated_reserved' => (int) $calculatedReserved,
            'discrepancies' => $discrepancies,
        ];
    }
}
