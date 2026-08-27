<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, SoftDeletes;

    protected $fillable = [
        'name',
        'phone',
        'password',
        'role_id',
        'commission_rate',
        'barcode',
        'is_active',
        'last_login_at'
    ];
    protected $hidden = ['password', 'remember_token'];
    protected $casts = [
        'commission_rate' => 'decimal:2',
        'is_active' => 'boolean',
        'last_login_at' => 'datetime',
        'password' => 'hashed',
    ];

    public function role(): BelongsTo
    {
        return $this->belongsTo(Role::class);
    }
    public function deviceTokens(): HasMany
    {
        return $this->hasMany(DeviceToken::class);
    }
    public function salesOrders(): HasMany
    {
        return $this->hasMany(SalesOrder::class, 'salesman_id');
    }
    public function deliveryTrips(): HasMany
    {
        return $this->hasMany(DeliveryTrip::class, 'driver_id');
    }
    public function commissions(): HasMany
    {
        return $this->hasMany(SalesmanCommission::class, 'salesman_id');
    }
    public function customerPayments(): HasMany
    {
        return $this->hasMany(CustomerPayment::class, 'collected_by');
    }

    public function scopeActive($q)
    {
        return $q->where('is_active', true);
    }
    public function scopeSalesmen($q)
    {
        return $q->whereHas('role', fn($r) => $r->where('name', Role::SALESMAN));
    }
    public function scopeDrivers($q)
    {
        return $q->whereHas('role', fn($r) => $r->where('name', Role::DRIVER));
    }

    public function isOwner(): bool
    {
        return $this->role?->name === Role::OWNER;
    }
    public function isAdmin(): bool
    {
        return in_array($this->role?->name, [Role::OWNER, Role::ADMIN]);
    }
}
