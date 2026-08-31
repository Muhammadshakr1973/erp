<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class RestockRequest extends Model
{
    use HasFactory;
    protected $fillable = ['customer_id', 'product_id', 'quantity', 'salesman_id', 'status', 'notes'];
    const STATUS_PENDING = 'PENDING';
    const STATUS_FULFILLED = 'FULFILLED';

    const STATUS_PENDING_LOWER = 'pending';
    const STATUS_FULFILLED_LOWER = 'fulfilled';
    public function customer()
    {
        return $this->belongsTo(Customer::class);
    }
    public function product()
    {
        return $this->belongsTo(Product::class);
    }
    public function salesman()
    {
        return $this->belongsTo(User::class, 'salesman_id');
    }
}
