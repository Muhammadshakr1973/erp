<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class CustomerPayment extends Model
{
    use HasFactory;
    protected $fillable = ['payment_number', 'customer_id', 'sales_order_id', 'amount', 'payment_method', 'collected_by', 'notes'];
    // DEC-010: sales_order_id NULLABLE - payment for total debt
    public function customer()
    {
        return $this->belongsTo(Customer::class);
    }
    public function order()
    {
        return $this->belongsTo(SalesOrder::class, 'sales_order_id');
    }
    public function collector()
    {
        return $this->belongsTo(User::class, 'collected_by');
    }
}
