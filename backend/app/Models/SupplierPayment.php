<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class SupplierPayment extends Model
{
    use HasFactory;
    protected $fillable = ['supplier_id', 'purchase_order_id', 'amount', 'payment_method', 'notes', 'created_by'];
    public function supplier()
    {
        return $this->belongsTo(Supplier::class);
    }
    public function order()
    {
        return $this->belongsTo(PurchaseOrder::class, 'purchase_order_id');
    }
}
