<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use App\Models\Traits\Auditable;

class Customer extends Model
{
    use HasFactory, SoftDeletes, Auditable;
    protected $fillable = ['name', 'phone', 'phone2', 'route_id', 'price_type', 'permanent_discount', 'address', 'latitude', 'longitude', 'current_balance', 'is_active', 'created_by', 'image_url', 'visit_order'];
    protected $casts = ['latitude' => 'decimal:8', 'longitude' => 'decimal:8', 'permanent_discount' => 'decimal:2', 'is_active' => 'boolean', 'visit_order' => 'integer'];
    const PRICE_N1 = 'N1';
    const PRICE_N2 = 'N2';
    const PRICE_N3 = 'N3';
    public function route(): BelongsTo
    {
        return $this->belongsTo(Route::class);
    }
    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }
    public function salesOrders(): HasMany
    {
        return $this->hasMany(SalesOrder::class);
    }
    public function ledger(): HasMany
    {
        return $this->hasMany(CustomerLedger::class);
    }
    public function payments(): HasMany
    {
        return $this->hasMany(CustomerPayment::class);
    }
    public function specialPrices(): HasMany
    {
        return $this->hasMany(CustomerSpecialPrice::class);
    }
    public function restockRequests(): HasMany
    {
        return $this->hasMany(RestockRequest::class);
    }
    public function getDebtAttribute(): int
    {
        return (int) $this->ledger()->selectRaw("SUM(CASE WHEN type='debit' THEN amount ELSE -amount END) as bal")->value('bal');
    }
    public function scopeActive($q)
    {
        return $q->where('is_active', true);
    }
    public function getCurrentPriceForProduct(Product $product): int
    {
        return $this->getPriceDetailsForProduct($product)['price'];
    }

    public function getPriceDetailsForProduct(Product $product): array
    {
        $today = now()->toDateString();
        $special = $this->specialPrices()
            ->where('product_id', $product->id)
            ->where(function ($q) use ($today) {
                $q->whereNull('start_date')->orWhere('start_date', '<=', $today);
            })
            ->where(function ($q) use ($today) {
                $q->whereNull('end_date')->orWhere('end_date', '>=', $today);
            })
            ->first();

        if ($special) {
            return [
                'price' => (int) $special->price,
                'price_type' => 'SPECIAL',
            ];
        }

        $tier = strtoupper($this->price_type ?? 'N2');
        $effectiveTier = in_array($tier, ['N1', 'N2', 'N3']) ? $tier : 'N2';

        return [
            'price' => (int) $product->getPriceForType($effectiveTier),
            'price_type' => $effectiveTier,
        ];
    }

    public function reconcileBalance(): array
    {
        $entries = $this->ledger()->orderBy('id', 'asc')->get();
        $recalculatedBalance = 0;
        $discrepancies = [];

        foreach ($entries as $entry) {
            $previousBalance = $recalculatedBalance;
            if ($entry->type === 'debit') {
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

        $isConsistent = empty($discrepancies) && ($this->current_balance == $recalculatedBalance);

        return [
            'is_consistent' => $isConsistent,
            'stored_balance' => (int) $this->current_balance,
            'recalculated_balance' => (int) $recalculatedBalance,
            'discrepancies' => $discrepancies,
        ];
    }
}
