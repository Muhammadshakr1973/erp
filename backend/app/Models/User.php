<?php

namespace App\Models;

use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Laravel\Sanctum\HasApiTokens;
use App\Models\Traits\Auditable;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, SoftDeletes, Auditable;

    protected $fillable = [
        'name',
        'phone',
        'password',
        'role_id',
        'commission_rate',
        'fixed_salary',
        'barcode',
        'is_active',
        'last_login_at',
        'warehouse_id',
        'image_url',
        'routing_cycle'
    ];
    protected $hidden = ['password', 'remember_token'];
    protected $casts = [
        'commission_rate' => 'decimal:2',
        'fixed_salary' => 'integer',
        'is_active' => 'boolean',
        'last_login_at' => 'datetime',
        'password' => 'hashed',
        'warehouse_id' => 'integer',
        'routing_cycle' => 'string'
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
        return strtolower($this->role?->name ?? '') === Role::OWNER;
    }
    public function isAdmin(): bool
    {
        return in_array(strtolower($this->role?->name ?? ''), [Role::OWNER, Role::ADMIN]);
    }
    public function isSalesman(): bool
    {
        return strtolower($this->role?->name ?? '') === Role::SALESMAN;
    }
    public function isWarehouse(): bool
    {
        return in_array(strtolower($this->role?->name ?? ''), [Role::WAREHOUSE, 'packer']);
    }
    public function isDriver(): bool
    {
        return strtolower($this->role?->name ?? '') === Role::DRIVER;
    }

    public function getAssignedRouteIds(): array
    {
        if ($this->isAdmin() || $this->isOwner()) {
            return Route::pluck('id')->toArray();
        }

        $today = now()->toDateString();
        $cycle = $this->routing_cycle ?? '1_week';

        return $this->routeSalesmen()
            ->where('is_active', true)
            ->where(function ($query) use ($today, $cycle) {
                // 1. Specific override for today
                $query->where('work_date', $today)
                // 2. Or recurring schedule within the active routing cycle
                ->orWhere(function ($q) use ($cycle) {
                    $q->whereNull('work_date')
                      ->whereNotNull('day_of_week');
                    if ($cycle === '1_week') {
                        $q->where('week_number', 1);
                    } else {
                        $q->whereIn('week_number', [1, 2]);
                    }
                });
            })
            ->distinct()
            ->pluck('route_id')
            ->toArray();
    }

    public function getTodayRouteId(): ?int
    {
        $today = now()->toDateString();
        $currentDayOfWeek = now()->format('l');

        if ($currentDayOfWeek === 'Friday') {
            return null;
        }

        // Specific override work_date
        $routeSalesman = $this->routeSalesmen()
            ->where('is_active', true)
            ->where('work_date', $today)
            ->first();

        if (!$routeSalesman) {
            $cycle = $this->routing_cycle ?? '1_week';
            $weekNumber = 1;
            if ($cycle === '2_weeks') {
                $weekNumber = (now()->weekOfYear % 2 === 0) ? 2 : 1;
            }

            $routeSalesman = $this->routeSalesmen()
                ->where('is_active', true)
                ->where('day_of_week', $currentDayOfWeek)
                ->where('week_number', $weekNumber)
                ->first();
        }

        return $routeSalesman ? $routeSalesman->route_id : null;
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

        if ($this->isSalesman()) {
            if (in_array($permission, [
                'orders.create',
                'orders.view',
                'customers.view',
                'customers.manage',
                'products.view',
                'commissions.view',
                'suppliers.view',
            ])) {
                return true;
            }
        }

        if ($this->isWarehouse()) {
            if (in_array($permission, [
                'stock.view',
                'stock.pack',
                'stock.reconcile',
                'stock.transfer',
                'stock.adjust',
                'purchases.receive',
                'orders.view',
                'delivery.view',
                'delivery.update',
            ])) {
                return true;
            }
        }

        if ($this->isDriver()) {
            if (in_array($permission, [
                'delivery.view',
                'delivery.update',
                'delivery.confirm',
                'orders.view',
            ])) {
                return true;
            }
        }

        $permissions = $this->role?->permissions;

        if (is_string($permissions)) {
            $decoded = json_decode($permissions, true);
            while (is_string($decoded)) {
                $decoded = json_decode($decoded, true);
            }
            $permissions = is_array($decoded) ? $decoded : [];
        }

        if (!is_array($permissions)) {
            return false;
        }

        return in_array($permission, $permissions) || in_array('*', $permissions);
    }
}
