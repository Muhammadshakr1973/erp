<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class DeliveryTripOrder extends Model
{
    use HasFactory;
    protected $fillable = ['delivery_trip_id', 'sales_order_id', 'status', 'delivery_order', 'received_amount', 'delivered_at', 'failed_reason', 'latitude', 'longitude'];
    protected $casts = ['delivered_at' => 'datetime', 'latitude' => 'decimal:8', 'longitude' => 'decimal:8'];
    const STATUS_PENDING = 'pending';
    const STATUS_DELIVERED = 'delivered';
    const STATUS_FAILED = 'failed';
    public function trip()
    {
        return $this->belongsTo(DeliveryTrip::class, 'delivery_trip_id');
    }
    public function order()
    {
        return $this->belongsTo(SalesOrder::class, 'sales_order_id');
    }
}
