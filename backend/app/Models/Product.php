<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use App\Models\Traits\Auditable;

class Product extends Model
{
    use HasFactory, SoftDeletes, Auditable;
    protected $fillable = ['name', 'sku', 'barcode', 'category_id', 'supplier_id', 'unit', 'units_per_carton', 'cost_price', 'price_n1', 'price_n2', 'price_n3', 'image_path', 'is_active'];
    protected $casts = ['is_active' => 'boolean', 'units_per_carton' => 'integer'];
    public function category()
    {
        return $this->belongsTo(Category::class);
    }
    public function supplier()
    {
        return $this->belongsTo(Supplier::class);
    }
    public function stocks()
    {
        return $this->hasMany(WarehouseStock::class);
    }
    public function salesItems()
    {
        return $this->hasMany(SalesOrderItem::class);
    }
    public function getPriceForType(string $type): int
    {
        return (int) match ($type) {
            'N1' => $this->price_n1,
            'N2' => $this->price_n2,
            'N3' => $this->price_n3,
            'special' => $this->price_n1,
            default => $this->price_n1
        };
    }
    public function scopeActive($q)
    {
        return $q->where('is_active', true);
    }
}
