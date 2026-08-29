<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

use Illuminate\Support\Facades\DB;

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
            $locked = self::lockForUpdate()->find($this->id);

            $newQty = $locked->quantity + $quantityChange;
            if ($newQty < 0) {
                throw new \Exception("کۆی گشتی ستۆک ناتوانێت لە صفر کەمتر بێت. بڕی پێشتر: {$locked->quantity}، گۆڕانکاری: {$quantityChange}");
            }

            $newReserved = $locked->reserved_quantity;
            if ($quantityChange < 0 && in_array(strtoupper($type), ['DELIVERY', 'SALE'])) {
                $newReserved = max(0, $locked->reserved_quantity - abs($quantityChange));
            }

            $locked->quantity = $newQty;
            $locked->reserved_quantity = $newReserved;
            $locked->save();

            return StockTransaction::create([
                'warehouse_id' => $locked->warehouse_id,
                'product_id' => $locked->product_id,
                'type' => strtoupper($type),
                'quantity_change' => $quantityChange,
                'quantity_after' => $newQty,
                'reference_type' => $referenceType,
                'reference_id' => $referenceId,
                'notes' => $notes,
                'created_by' => $userId,
            ]);
        });
    }

    public function reserveStock(int $amount, $userId, $referenceType = null, $referenceId = null, $notes = null): ?StockTransaction
    {
        if ($amount <= 0) {
            throw new \InvalidArgumentException('بڕی حجز دەبێت لە ٠ زیاتر بێت.');
        }

        return DB::transaction(function () use ($amount, $userId, $referenceType, $referenceId, $notes) {
            $locked = self::lockForUpdate()->find($this->id);

            $available = $locked->quantity - $locked->reserved_quantity;
            if ($available < $amount) {
                throw new \Exception("بڕی پێویست لە ستۆکی بەردەست نییە بۆ حجزکردن. بەردەست: {$available}");
            }

            $locked->reserved_quantity += $amount;
            $locked->save();

            return StockTransaction::create([
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

                return StockTransaction::create([
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
            if ($tx->type === 'RESERVE') {
                $calculatedReserved += $tx->quantity_change;
            } elseif ($tx->type === 'RELEASE') {
                $calculatedReserved -= abs($tx->quantity_change);
            } else {
                $calculatedQty += $tx->quantity_change;

                if (in_array(strtoupper($tx->type), ['DELIVERY', 'SALE'])) {
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
