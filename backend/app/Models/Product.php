<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use App\Models\Traits\Auditable;

class Product extends Model
{
    use HasFactory, SoftDeletes, Auditable;
    protected $fillable = [
        'parent_id',
        'is_parent',
        'name',
        'variant_name',
        'sku',
        'barcode',
        'category_id',
        'supplier_id',
        'unit',
        'units_per_carton',
        'cost_price',
        'price_n1',
        'price_n2',
        'price_n3',
        'use_parent_price',
        'image_path',
        'is_active',
    ];
    protected $casts = [
        'parent_id' => 'integer',
        'is_parent' => 'boolean',
        'use_parent_price' => 'boolean',
        'is_active' => 'boolean',
        'units_per_carton' => 'integer',
    ];

    protected static function booted()
    {
        static::saving(function ($product) {
            if (empty($product->unit)) {
                $product->unit = 'دانە';
            }
            if (!isset($product->cost_price) || $product->cost_price === null) {
                $product->cost_price = 0;
            }
            if (!isset($product->price_n1) || $product->price_n1 === null) {
                $product->price_n1 = 0;
            }
            if (!isset($product->price_n2) || $product->price_n2 === null) {
                $product->price_n2 = $product->price_n1;
            }
            if (!isset($product->price_n3) || $product->price_n3 === null) {
                $product->price_n3 = $product->price_n1;
            }
        });
    }
    public function parent()
    {
        return $this->belongsTo(Product::class, 'parent_id');
    }
    public function variants()
    {
        return $this->hasMany(Product::class, 'parent_id');
    }
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
        return (int) match (strtoupper($type)) {
            'N1' => $this->price_n1 ?? 0,
            'N2' => $this->price_n2 ?? 0,
            'N3' => $this->price_n3 ?? 0,
            'SPECIAL' => $this->price_n3 ?? 0,
            default => $this->price_n3 ?? 0
        };
    }
    public function scopeActive($q)
    {
        return $q->where('is_active', true);
    }
    public function scopeSellable($q)
    {
        return $q->where('is_parent', false);
    }
    public function scopeTopLevel($q)
    {
        return $q->whereNull('parent_id');
    }
}
