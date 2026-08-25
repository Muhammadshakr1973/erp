<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class SupplierLedger extends Model
{
    use HasFactory;
    protected $table = 'supplier_ledger';
    protected $fillable = ['supplier_id', 'entry_type', 'type', 'debit', 'credit', 'amount', 'balance_after', 'reference_type', 'reference_id', 'description', 'created_by'];
    const TYPE_DEBIT = 'debit';
    const TYPE_CREDIT = 'credit';
    public function supplier()
    {
        return $this->belongsTo(Supplier::class);
    }
    protected static function booted()
    {
        static::updating(fn() => false);
        static::deleting(fn() => false);
    }
}
