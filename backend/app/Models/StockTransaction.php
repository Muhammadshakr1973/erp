<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class StockTransaction extends Model
{
    use HasFactory;
    protected $fillable = ['warehouse_id', 'product_id', 'type', 'quantity_change', 'quantity_after', 'reference_type', 'reference_id', 'notes', 'created_by'];
    const TYPE_IN = 'in';
    const TYPE_OUT = 'out';
    const TYPE_RESERVED = 'reserved';
    const TYPE_UNRESERVED = 'unreserved';
    const TYPE_PACKED = 'packed';
    const TYPE_TRANSFER_IN = 'transfer_in';
    const TYPE_TRANSFER_OUT = 'transfer_out';
    const TYPE_ADJUSTMENT = 'adjustment';
    const TYPE_RETURN = 'return';
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
}
