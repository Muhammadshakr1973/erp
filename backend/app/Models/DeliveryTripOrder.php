<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class DeliveryTripOrder extends Model
{
    use HasFactory;
    protected $fillable = ['delivery_trip_id', 'sales_order_id', 'status', 'delivery_order', 'received_amount', 'delivered_at', 'failed_reason', 'notes'];
    protected $casts = ['delivered_at' => 'datetime', 'received_amount' => 'integer', 'delivery_order' => 'integer'];
    const STATUS_PENDING = 'PENDING';
    const STATUS_DELIVERED = 'DELIVERED';
    const STATUS_FAILED = 'FAILED';

    const STATUS_PENDING_LOWER = 'pending';
    const STATUS_DELIVERED_LOWER = 'delivered';
    const STATUS_FAILED_LOWER = 'failed';
    public function trip()
    {
        return $this->belongsTo(DeliveryTrip::class, 'delivery_trip_id');
    }
    public function order()
    {
        return $this->belongsTo(SalesOrder::class, 'sales_order_id');
    }
}
