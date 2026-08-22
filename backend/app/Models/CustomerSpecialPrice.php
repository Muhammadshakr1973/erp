<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class CustomerSpecialPrice extends Model
{
    use HasFactory;
    protected $fillable = ['customer_id', 'product_id', 'price', 'start_date', 'end_date', 'created_by'];
    protected $casts = ['start_date' => 'date', 'end_date' => 'date'];
    public function customer()
    {
        return $this->belongsTo(Customer::class);
    }
    public function product()
    {
        return $this->belongsTo(Product::class);
    }
    public function scopeActive($q)
    {
        return $q->where(fn($q) => $q->whereNull('end_date')->orWhere('end_date', '>=', now()))->where(fn($q) => $q->whereNull('start_date')->orWhere('start_date', '<=', now()));
    }
}
