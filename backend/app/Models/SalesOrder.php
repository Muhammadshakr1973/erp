<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class SalesOrder extends Model
{
    use HasFactory, SoftDeletes;
    protected $fillable = [
        'order_number',
        'order_date',
        'shared_key',
        'version',
        'customer_id',
        'salesman_id',
        'warehouse_id',
        'status',
        'subtotal',
        'permanent_discount_percent',
        'permanent_discount_amount',
        'discount_percent',
        'discount_amount',
        'discount_type',
        'total_amount',
        'total_profit',
        'notes',
        'confirmed_at',
        'ready_at',
        'delivered_at',
        'created_by',
    ];
    protected $casts = [
        'order_date' => 'date',
        'permanent_discount_percent' => 'decimal:2',
        'discount_percent' => 'decimal:2',
        'confirmed_at' => 'datetime',
        'ready_at' => 'datetime',
        'delivered_at' => 'datetime',
        'version' => 'integer',
    ];

    protected static function booted()
    {
        static::creating(function ($order) {
            if (empty($order->order_number)) {
                $order->order_number = 'ORD-' . strtoupper(\Illuminate\Support\Str::random(8));
            }
            if (empty($order->salesman_id)) {
                $order->salesman_id = $order->created_by ?: (auth()->id() ?: (\App\Models\User::whereHas('role', function($q) {
                    $q->where('name', \App\Models\Role::SALESMAN);
                })->first()?->id ?: \App\Models\User::first()?->id));
            }
            if (empty($order->warehouse_id)) {
                $order->warehouse_id = \App\Models\Warehouse::where('is_main', true)->first()?->id 
                    ?: (\App\Models\Warehouse::first()?->id 
                        ?: \App\Models\Warehouse::create(['name' => 'Default Warehouse', 'is_main' => true, 'is_active' => true])->id);
            }
            if (empty($order->created_by)) {
                $order->created_by = auth()->id() ?: ($order->salesman_id ?: \App\Models\User::first()?->id);
            }
        });

        static::saving(function ($order) {
            if (empty($order->order_date)) {
                $order->order_date = now()->toDateString();
            }
        });
    }
    const STATUS_DRAFT = 'DRAFT';
    const STATUS_CONFIRMED = 'CONFIRMED';
    const STATUS_PACKING = 'PACKING';
    const STATUS_READY = 'READY';
    const STATUS_IN_DELIVERY = 'IN_DELIVERY';
    const STATUS_DELIVERED = 'DELIVERED';
    const STATUS_CANCELLED = 'CANCELLED';

    public static function allStatuses(): array
    {
        return [
            self::STATUS_DRAFT,
            self::STATUS_CONFIRMED,
            self::STATUS_PACKING,
            self::STATUS_READY,
            self::STATUS_IN_DELIVERY,
            self::STATUS_DELIVERED,
            self::STATUS_CANCELLED,
        ];
    }
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
