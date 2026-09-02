<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use App\Models\Traits\Auditable;

class CustomerSpecialPrice extends Model
{
    use HasFactory, Auditable;
    protected $fillable = ['customer_id', 'product_id', 'price', 'created_by'];
    public function customer()
    {
        return $this->belongsTo(Customer::class);
    }
    public function product()
    {
        return $this->belongsTo(Product::class);
    }
}
