<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class StockTransaction extends Model
{
    use HasFactory;
    protected $fillable = ['warehouse_id', 'product_id', 'type', 'quantity_change', 'quantity_after', 'reference_type', 'reference_id', 'notes', 'created_by'];

    // Standard authoritative movement types
    const TYPE_PURCHASE = 'PURCHASE';
    const TYPE_SALE = 'SALE';
    const TYPE_DELIVERY = 'DELIVERY';
    const TYPE_ADJUSTMENT = 'ADJUSTMENT';
    const TYPE_RETURN = 'RETURN';
    const TYPE_RESERVE = 'RESERVE';
    const TYPE_RELEASE = 'RELEASE';
    const TYPE_TRANSFER_OUT = 'TRANSFER_OUT';
    const TYPE_TRANSFER_IN = 'TRANSFER_IN';

    // Legacy lowercase aliases
    const TYPE_IN = 'in';
    const TYPE_OUT = 'out';
    const TYPE_RESERVED = 'reserved';
    const TYPE_UNRESERVED = 'unreserved';
    const TYPE_PACKED = 'packed';
    const TYPE_TRANSFER_IN_LOWER = 'transfer_in';
    const TYPE_TRANSFER_OUT_LOWER = 'transfer_out';
    const TYPE_ADJUSTMENT_LOWER = 'adjustment';
    const TYPE_RETURN_LOWER = 'return';
    protected static function booted()
    {
        static::creating(function ($model) {
            // Automatically calculate quantity_after if not provided
            if (is_null($model->quantity_after)) {
                $stock = \App\Models\WarehouseStock::where('warehouse_id', $model->warehouse_id)
                    ->where('product_id', $model->product_id)
                    ->first();
                $model->quantity_after = $stock ? (int)$stock->quantity : 0;
            }
        });

        // Strict immutability of transaction logs
        static::updating(function ($model) {
            return false;
        });

        static::deleting(function ($model) {
            return false;
        });
    }
    public function warehouse()
    {
        return $this->belongsTo(Warehouse::class);
    }
    public function product()
    {
        return $this->belongsTo(Product::class);
    }
    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
