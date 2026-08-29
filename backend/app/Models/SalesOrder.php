<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class SalesOrder extends Model
{
    use HasFactory, SoftDeletes;
    protected $fillable = ['order_number', 'customer_id', 'salesman_id', 'warehouse_id', 'status', 'subtotal', 'discount_percent', 'discount_amount', 'total_amount', 'total_profit', 'notes', 'confirmed_at', 'ready_at', 'delivered_at'];
    protected $casts = ['discount_percent' => 'decimal:2', 'confirmed_at' => 'datetime', 'ready_at' => 'datetime', 'delivered_at' => 'datetime'];
    const STATUS_DRAFT = 'DRAFT';
    const STATUS_CONFIRMED = 'CONFIRMED';
    const STATUS_PACKING = 'PACKING';
    const STATUS_READY = 'READY';
    const STATUS_IN_DELIVERY = 'IN_DELIVERY';
    const STATUS_DELIVERED = 'DELIVERED';
    const STATUS_CANCELLED = 'CANCELLED';
    public function customer()
    {
        return $this->belongsTo(Customer::class);
    }
    public function salesman()
    {
        return $this->belongsTo(User::class, 'salesman_id');
    }
    public function warehouse()
    {
        return $this->belongsTo(Warehouse::class);
    }
    public function items()
    {
        return $this->hasMany(SalesOrderItem::class);
    }
    public function tripOrders()
    {
        return $this->hasMany(DeliveryTripOrder::class, 'sales_order_id');
    }
    public function scopeByStatus($q, $s)
    {
        return $q->where('status', $s);
    }
    public function scopeDeliveredBetween($q, $from, $to)
    {
        return $q->where('status', self::STATUS_DELIVERED)->whereBetween('delivered_at', [$from, $to]);
    }
    public function commissionDetail()
    {
        return $this->hasOne(SalesmanCommissionDetail::class, 'sales_order_id');
    }

    public function commissionDetails()
    {
        return $this->hasOne(SalesmanCommissionDetail::class, 'sales_order_id');
    }
}
