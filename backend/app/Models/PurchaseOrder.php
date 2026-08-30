<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class PurchaseOrder extends Model
{
    use HasFactory, SoftDeletes;

    protected $fillable = [
        'order_number',
        'supplier_id',
        'warehouse_id',
        'status',
        'total_amount',
        'notes',
        'created_by',
        'received_at',
    ];

    protected $casts = [
        'received_at' => 'datetime',
        'total_amount' => 'integer',
        'supplier_id' => 'integer',
        'warehouse_id' => 'integer',
        'created_by' => 'integer',
    ];

    const STATUS_DRAFT = 'DRAFT';
    const STATUS_CONFIRMED = 'CONFIRMED';
    const STATUS_RECEIVED = 'RECEIVED';
    const STATUS_CANCELLED = 'CANCELLED';

    // Legacy lowercase aliases for backward compatibility
    const STATUS_DRAFT_LOWER = 'draft';
    const STATUS_ORDERED_LOWER = 'ordered';
    const STATUS_RECEIVED_LOWER = 'received';

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

    public function requirements()
    {
        return $this->hasMany(PurchaseRequirement::class, 'purchase_order_id');
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }
}
