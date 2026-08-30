<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use App\Models\Traits\Auditable;

class SalesmanCommission extends Model
{
    use HasFactory, Auditable;

    protected $table = 'salesman_commissions';

    protected $fillable = [
        'salesman_id',
        'period_from',
        'period_to',
        'total_sales',
        'total_profit',
        'commission_rate',
        'commission_amount',
        'status',
        'calculated_by',
        'approved_by',
        'approved_at',
        'paid_by',
        'paid_at',
        'payment_method',
        'cancelled_by',
        'cancelled_at',
        'cancellation_reason',
        'notes',
    ];

    protected $casts = [
        'period_from'       => 'date:Y-m-d',
        'period_to'         => 'date:Y-m-d',
        'commission_rate'   => 'decimal:2',
        'total_sales'       => 'integer',
        'total_profit'      => 'integer',
        'commission_amount' => 'integer',
        'approved_at'       => 'datetime',
        'paid_at'           => 'datetime',
        'cancelled_at'      => 'datetime',
    ];

    const STATUS_CALCULATED = 'calculated';
    const STATUS_APPROVED = 'approved';
    const STATUS_PAID = 'paid';
    const STATUS_CANCELLED = 'cancelled';

    public function salesman(): BelongsTo
    {
        return $this->belongsTo(User::class, 'salesman_id');
    }

    public function details(): HasMany
    {
        return $this->hasMany(SalesmanCommissionDetail::class, 'salesman_commission_id');
    }

    public function calculator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'calculated_by');
    }

    public function approver(): BelongsTo
    {
        return $this->belongsTo(User::class, 'approved_by');
    }

    public function payer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'paid_by');
    }

    public function canceller(): BelongsTo
    {
        return $this->belongsTo(User::class, 'cancelled_by');
    }

    public function isCalculated(): bool
    {
        return $this->status === self::STATUS_CALCULATED;
    }

    public function isApproved(): bool
    {
        return $this->status === self::STATUS_APPROVED;
    }

    public function isPaid(): bool
    {
        return $this->status === self::STATUS_PAID;
    }

    public function isCancelled(): bool
    {
        return $this->status === self::STATUS_CANCELLED;
    }
}
