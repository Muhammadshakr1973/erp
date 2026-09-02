<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\SoftDeletes;

class SalesOrderItem extends Model
{
    use HasFactory, SoftDeletes;
    protected $fillable = ['sales_order_id', 'product_id', 'quantity', 'unit_price', 'cost_price', 'price_type', 'discount_percent', 'discount_amount', 'line_total', 'total_price', 'profit', 'is_packed', 'packed_at', 'packed_by'];

    protected static function booted()
    {
        static::creating(function ($item) {
            $product = \App\Models\Product::find($item->product_id);
            if (is_null($item->cost_price) || $item->cost_price === '') {
                $item->cost_price = $product ? (int)$product->cost_price : 0;
            }
            if (is_null($item->unit_price) || $item->unit_price === '') {
                $item->unit_price = $product ? (int)$product->price_n2 : 0;
            }
            if (empty($item->line_total)) {
                $item->line_total = $item->quantity * $item->unit_price;
            }
            if (empty($item->total_price)) {
                $item->total_price = $item->line_total;
            }
            if (is_null($item->profit) || $item->profit === '') {
                $item->profit = ($item->unit_price - $item->cost_price) * $item->quantity;
            }
        });
    }
    protected $casts = [
        'is_packed' => 'boolean',
        'discount_percent' => 'decimal:2',
        'packed_at' => 'datetime',
        'unit_price' => 'integer',
        'cost_price' => 'integer',
        'line_total' => 'integer',
        'total_price' => 'integer',
        'profit' => 'integer',
    ];
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
