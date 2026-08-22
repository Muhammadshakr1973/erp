<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class PurchaseRequirement extends Model
{
    use HasFactory;
    protected $fillable = ['product_id', 'warehouse_id', 'supplier_id', 'required_quantity', 'current_stock', 'suggested_quantity', 'is_urgent', 'status'];
    protected $casts = ['is_urgent' => 'boolean'];
    const STATUS_PENDING = 'pending';
    public function product()
    {
        return $this->belongsTo(Product::class);
    }
    public function warehouse()
    {
        return $this->belongsTo(Warehouse::class);
    }
    public function supplier()
    {
        return $this->belongsTo(Supplier::class);
    }
}
