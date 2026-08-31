<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class SalesReturn extends Model
{
    use HasFactory, SoftDeletes;
    protected $fillable = ['return_number', 'sales_order_id', 'customer_id', 'reason', 'status', 'total_return_amount', 'created_by'];
    const STATUS_PENDING = 'PENDING';
    const STATUS_COMPLETED = 'COMPLETED';

    const STATUS_PENDING_LOWER = 'pending';
    const STATUS_COMPLETED_LOWER = 'completed';
    public function order()
    {
        return $this->belongsTo(SalesOrder::class, 'sales_order_id');
    }
    public function customer()
    {
        return $this->belongsTo(Customer::class);
    }
    public function items()
    {
        return $this->hasMany(SalesReturnItem::class);
    }
}
