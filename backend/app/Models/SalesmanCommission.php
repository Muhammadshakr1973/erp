<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class SalesmanCommission extends Model
{
    use HasFactory;
    protected $fillable = ['salesman_id', 'period_from', 'period_to', 'total_sales', 'total_profit', 'commission_rate', 'commission_amount', 'status', 'paid_at', 'paid_by'];
    protected $casts = ['period_from' => 'date', 'period_to' => 'date', 'commission_rate' => 'decimal:2', 'paid_at' => 'datetime'];
    const STATUS_CALCULATED = 'calculated';
    const STATUS_APPROVED = 'approved';
    const STATUS_PAID = 'paid';
    public function salesman()
    {
        return $this->belongsTo(User::class, 'salesman_id');
    }
    public function details()
    {
        return $this->hasMany(SalesmanCommissionDetail::class, 'commission_id');
    }
    public function payer()
    {
        return $this->belongsTo(User::class, 'paid_by');
    }
}
