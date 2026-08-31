<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class StockTransfer extends Model
{
    use HasFactory;
    protected $fillable = ['transfer_number', 'from_warehouse_id', 'to_warehouse_id', 'status', 'notes', 'created_by', 'approved_by', 'transferred_at', 'completed_at'];
    protected $casts = ['transferred_at' => 'datetime', 'completed_at' => 'datetime'];
    const STATUS_DRAFT = 'DRAFT';
    const STATUS_IN_TRANSIT = 'IN_TRANSIT';
    const STATUS_COMPLETED = 'COMPLETED';
    const STATUS_CANCELLED = 'CANCELLED';

    const STATUS_DRAFT_LOWER = 'draft';
    const STATUS_IN_TRANSIT_LOWER = 'in_transit';
    const STATUS_COMPLETED_LOWER = 'completed';
    const STATUS_CANCELLED_LOWER = 'cancelled';
    public function fromWarehouse()
    {
        return $this->belongsTo(Warehouse::class, 'from_warehouse_id');
    }
    public function toWarehouse()
    {
        return $this->belongsTo(Warehouse::class, 'to_warehouse_id');
    }
    public function items()
    {
        return $this->hasMany(StockTransferItem::class);
    }
}
