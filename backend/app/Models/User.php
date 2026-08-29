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
        'last_login_at',
        'warehouse_id'
    ];
    protected $hidden = ['password', 'remember_token'];
    protected $casts = [
        'commission_rate' => 'decimal:2',
        'is_active' => 'boolean',
        'last_login_at' => 'datetime',
        'password' => 'hashed',
        'warehouse_id' => 'integer'
    ];

    public function role(): BelongsTo
    {
        return $this->belongsTo(Role::class);
    }
    public function warehouse(): BelongsTo
    {
        return $this->belongsTo(Warehouse::class);
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
    public function routeSalesmen(): HasMany
    {
        return $this->hasMany(RouteSalesman::class, 'salesman_id');
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

    public function getAssignedRouteIds(): array
    {
        if ($this->isAdmin() || $this->isOwner()) {
            return Route::pluck('id')->toArray();
        }
        return $this->routeSalesmen()->where('is_active', true)->pluck('route_id')->toArray();
    }

    public function hasCustomerAccess($customer): bool
    {
        if ($this->isAdmin() || $this->isOwner()) {
            return true;
        }

        $customerId = $customer instanceof Customer ? $customer->id : $customer;
        $customerModel = $customer instanceof Customer ? $customer : Customer::find($customerId);
        if (!$customerModel) {
            return false;
        }

        // Direct salesman-customer assignments check
        $hasDirectAssignment = \DB::table('customer_assignments')
            ->where('customer_id', $customerId)
            ->where('salesman_id', $this->id)
            ->where('assigned_from', '<=', now()->toDateString())
            ->where(function ($q) {
                $q->whereNull('assigned_until')
                  ->orWhere('assigned_until', '>=', now()->toDateString());
            })
            ->exists();

        if ($hasDirectAssignment) {
            return true;
        }

        // Check assigned routes
        $assignedRoutes = $this->getAssignedRouteIds();
        return in_array($customerModel->route_id, $assignedRoutes);
    }

    public function hasPermission(string $permission): bool
    {
        if ($this->isOwner() || $this->isAdmin()) {
            return true;
        }

        $permissions = $this->role?->permissions;
        
        // In Laravel casts, $permissions might be an array or JSON string depending on db connection/driver, but here it is cast as array
        if (!is_array($permissions)) {
            return false;
        }

        return in_array($permission, $permissions) || in_array('*', $permissions);
    }
}
