<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class RestockRequest extends Model
{
    use HasFactory;
    protected $fillable = ['customer_id', 'product_id', 'quantity', 'salesman_id', 'status', 'notes'];
    const STATUS_OPEN = 'OPEN';
    const STATUS_ORDERED = 'ORDERED';
    const STATUS_CLOSED = 'CLOSED';

    const STATUS_OPEN_LOWER = 'open';
    const STATUS_ORDERED_LOWER = 'ordered';
    const STATUS_CLOSED_LOWER = 'closed';
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
