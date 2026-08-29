<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Supplier extends Model
{
    use HasFactory, SoftDeletes;
    protected $fillable = ['name', 'phone', 'address', 'contact_person', 'is_active'];
    protected $casts = ['is_active' => 'boolean'];
    protected $appends = ['debt'];

    public function products()
    {
        return $this->hasMany(Product::class);
    }
    public function purchaseOrders()
    {
        return $this->hasMany(PurchaseOrder::class);
    }
    public function ledger()
    {
        return $this->hasMany(SupplierLedger::class);
    }
    public function payments()
    {
        return $this->hasMany(SupplierPayment::class);
    }
    public function getDebtAttribute(): int
    {
        $lastLedger = $this->ledger()->orderByDesc('id')->first();
        return $lastLedger ? (int) $lastLedger->balance_after : 0;
    }

    public function reconcileBalance(): array
    {
        $entries = $this->ledger()->orderBy('id', 'asc')->get();
        $recalculatedBalance = 0;
        $discrepancies = [];

        foreach ($entries as $entry) {
            $previousBalance = $recalculatedBalance;
            if ($entry->type === 'credit') {
                $recalculatedBalance += $entry->amount;
            } else {
                $recalculatedBalance -= $entry->amount;
            }

            if ($entry->balance_before != $previousBalance) {
                $discrepancies[] = "Entry ID {$entry->id}: balance_before stored as {$entry->balance_before}, calculated as {$previousBalance}";
            }

            if ($entry->balance_after != $recalculatedBalance) {
                $discrepancies[] = "Entry ID {$entry->id}: balance_after stored as {$entry->balance_after}, calculated as {$recalculatedBalance}";
            }
        }

        $lastLedger = $this->ledger()->orderByDesc('id')->first();
        $lastLedgerBalance = $lastLedger ? $lastLedger->balance_after : 0;
        $isConsistent = empty($discrepancies) && ($lastLedgerBalance == $recalculatedBalance);

        return [
            'is_consistent' => $isConsistent,
            'last_ledger_balance' => (int) $lastLedgerBalance,
            'recalculated_balance' => (int) $recalculatedBalance,
            'discrepancies' => $discrepancies,
        ];
    }
}
