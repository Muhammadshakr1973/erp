<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class PurchaseOrderItem extends Model
{
    use HasFactory;
    protected $fillable = ['purchase_order_id', 'product_id', 'quantity', 'cost_price', 'total', 'received_quantity'];
    public function order()
    {
        return $this->belongsTo(PurchaseOrder::class, 'purchase_order_id');
    }
    public function product()
    {
        return $this->belongsTo(Product::class);
    }
}
