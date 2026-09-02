<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class CustomerLedger extends Model
{
    use HasFactory;
    protected $table = 'customer_ledger';
    protected $fillable = ['customer_id', 'entry_type', 'type', 'debit', 'credit', 'amount', 'balance_before', 'balance_after', 'reference_type', 'reference_id', 'description', 'created_by'];
    const TYPE_DEBIT = 'debit';
    const TYPE_CREDIT = 'credit';
    public function customer()
    {
        return $this->belongsTo(Customer::class);
    }
    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }
    // Ledger is immutable - prevent update/delete
    protected static function booted(): void
    {
        static::creating(function ($ledger) {
            if (empty($ledger->created_by)) {
                $ledger->created_by = auth()->id() ?? 1;
            }
        });
        static::updating(fn() => false);
        static::deleting(fn() => false);
    }
    public function scopeDebits($q)
    {
        return $q->where('type', self::TYPE_DEBIT);
    }
    public function scopeCredits($q)
    {
        return $q->where('type', self::TYPE_CREDIT);
    }
}
