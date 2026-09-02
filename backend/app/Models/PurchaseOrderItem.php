<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class PurchaseOrderItem extends Model
{
    use HasFactory;
    protected $fillable = ['purchase_order_id', 'product_id', 'quantity', 'unit_cost', 'total_cost', 'received_quantity'];

    protected static function booted()
    {
        static::creating(function ($item) {
            $product = \App\Models\Product::find($item->product_id);
            if (is_null($item->unit_cost) || $item->unit_cost === '') {
                $item->unit_cost = $product ? (int)$product->cost_price : 0;
            }
            if (empty($item->total_cost)) {
                $item->total_cost = $item->quantity * $item->unit_cost;
            }
        });
    }
    public function order()
    {
        return $this->belongsTo(PurchaseOrder::class, 'purchase_order_id');
    }
    public function product()
    {
        return $this->belongsTo(Product::class);
    }
}
