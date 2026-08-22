<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

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
}
