<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class PurchaseRequirement extends Model
{
    use HasFactory;
    protected $fillable = ['product_id', 'warehouse_id', 'supplier_id', 'required_quantity', 'current_stock', 'suggested_quantity', 'is_urgent', 'status', 'created_by', 'sales_order_id', 'purchase_order_id'];
    protected $casts = [
        'is_urgent' => 'boolean',
        'required_quantity' => 'integer',
        'current_stock' => 'integer',
        'suggested_quantity' => 'integer',
        'sales_order_id' => 'integer',
        'purchase_order_id' => 'integer',
    ];
    const STATUS_OPEN = 'OPEN';
    const STATUS_PENDING = 'OPEN';
    const STATUS_ORDERED = 'ORDERED';
    const STATUS_CLOSED = 'CLOSED';

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
    public function salesOrder()
    {
        return $this->belongsTo(SalesOrder::class, 'sales_order_id');
    }
    public function purchaseOrder()
    {
        return $this->belongsTo(PurchaseOrder::class, 'purchase_order_id');
    }
    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
