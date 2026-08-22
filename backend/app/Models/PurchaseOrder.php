<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class PurchaseOrder extends Model
{
    use HasFactory, SoftDeletes;
    protected $fillable = ['order_number', 'supplier_id', 'warehouse_id', 'status', 'total_amount', 'notes', 'created_by', 'received_at'];
    protected $casts = ['received_at' => 'datetime'];
    const STATUS_DRAFT = 'draft';
    const STATUS_ORDERED = 'ordered';
    const STATUS_RECEIVED = 'received';
    public function supplier()
    {
        return $this->belongsTo(Supplier::class);
    }
    public function warehouse()
    {
        return $this->belongsTo(Warehouse::class);
    }
    public function items()
    {
        return $this->hasMany(PurchaseOrderItem::class);
    }
}
