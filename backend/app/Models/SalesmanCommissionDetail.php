<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class SalesmanCommissionDetail extends Model
{
    use HasFactory;
    protected $table = 'salesman_commission_details';
    protected $fillable = ['commission_id', 'sales_order_id', 'sales_amount', 'profit_amount', 'commission_amount'];
    public function commission()
    {
        return $this->belongsTo(SalesmanCommission::class, 'commission_id');
    }
    public function order()
    {
        return $this->belongsTo(SalesOrder::class, 'sales_order_id');
    }
}
