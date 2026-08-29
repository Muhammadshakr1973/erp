<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class SalesOrderItem extends Model
{
    use HasFactory;
    protected $fillable = ['sales_order_id', 'product_id', 'quantity', 'unit_price', 'cost_price', 'price_type', 'discount_percent', 'discount_amount', 'line_total', 'total_price', 'profit', 'is_packed', 'packed_at', 'packed_by'];
    protected $casts = ['is_packed' => 'boolean', 'discount_percent' => 'decimal:2', 'packed_at' => 'datetime'];
    public function order()
    {
        return $this->belongsTo(SalesOrder::class, 'sales_order_id');
    }
    public function product()
    {
        return $this->belongsTo(Product::class);
    }
    public function packer()
    {
        return $this->belongsTo(User::class, 'packed_by');
    }
    public function scopePacked($q)
    {
        return $q->where('is_packed', true);
    }
    public function scopeUnpacked($q)
    {
        return $q->where('is_packed', false);
    }
}
