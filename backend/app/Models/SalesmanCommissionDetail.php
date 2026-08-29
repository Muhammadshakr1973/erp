<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SalesmanCommissionDetail extends Model
{
    use HasFactory;

    protected $table = 'salesman_commission_details';

    protected $fillable = [
        'salesman_commission_id',
        'sales_order_id',
        'sales_amount',
        'profit_amount',
        'commission_amount',
    ];

    protected $casts = [
        'sales_amount'      => 'integer',
        'profit_amount'     => 'integer',
        'commission_amount' => 'integer',
    ];

    public function commission(): BelongsTo
    {
        return $this->belongsTo(SalesmanCommission::class, 'salesman_commission_id');
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(SalesOrder::class, 'sales_order_id');
    }
}
