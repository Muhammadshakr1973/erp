<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class StockTransaction extends Model
{
    use HasFactory;
    protected $fillable = ['warehouse_id', 'product_id', 'type', 'quantity', 'quantity_after', 'reference_type', 'reference_id', 'notes', 'created_by'];
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
        static::creating(function ($model) { /* quantity_after calculated in service */
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
