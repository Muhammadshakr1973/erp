<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class SalesReturnItem extends Model
{
    use HasFactory;
    protected $fillable = ['sales_return_id', 'sales_order_item_id', 'product_id', 'quantity', 'unit_price', 'total', 'reason'];
    public function salesReturn()
    {
        return $this->belongsTo(SalesReturn::class, 'sales_return_id');
    }
    public function product()
    {
        return $this->belongsTo(Product::class);
    }
    public function orderItem()
    {
        return $this->belongsTo(SalesOrderItem::class, 'sales_order_item_id');
    }
}
