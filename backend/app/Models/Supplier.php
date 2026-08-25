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
}
