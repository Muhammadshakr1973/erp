<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\Role;
use App\Models\User;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class CustomerService
{
    /**
     * هێنانی کڕیارەکان بەپێی فلتەر و مافی بەکارهێنەر
     */
    public function getAllCustomers(array $filters, $user): LengthAwarePaginator
    {
        $query = Customer::with(['route', 'specialPrices']);

        if ($user->isCustomer()) {
            $customerId = $user->customer?->id ?? -1;
            $query->where('id', $customerId);
            return $query->paginate(1);
        }

        // ئەگەر بەکارهێنەر مەندوب بوو، تەنها کڕیارەکانی ئەو گەڕەکانە دەبینێت کە بۆی دانراون یان بەڕاستەوخۆ بۆی تەرخانکراون
        if ($user->isSalesman()) {
            $routeIds = $user->getAssignedRouteIds();
            $directCustomerIds = \DB::table('customer_assignments')
                ->where('salesman_id', $user->id)
                ->where('assigned_from', '<=', now()->toDateString())
                ->where(function ($q) {
                    $q->whereNull('assigned_until')
                      ->orWhere('assigned_until', '>=', now()->toDateString());
                })
                ->pluck('customer_id')
                ->toArray();

            $query->where(function ($q) use ($routeIds, $directCustomerIds) {
                $q->whereIn('route_id', $routeIds)
                  ->orWhereIn('id', $directCustomerIds)
                  ->orWhere('id', 0);
            });
        }

        // فلتەرکردن بەپێی گەڕەک ئەگەر نێردرابوو
        if (!empty($filters['route_id'])) {
            $query->where(function ($q) use ($filters) {
                $q->where('route_id', $filters['route_id'])
                  ->orWhere('id', 0);
            });
        }

        // گەڕان بەپێی ناو یان تەلەفۆن
        if (!empty($filters['search'])) {
            $search = $filters['search'];
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%")
                    ->orWhere('id', 0);
            });
        }

        // فلتەرکردن بەپێی قەرز (تەنها ئەوانەی قەرزدارن)
        if (isset($filters['has_debt']) && $filters['has_debt'] == 'true') {
            $query->where('current_balance', '>', 0);
        }

        // کڕیاری کاتی هەمیشە لە سەرەتای لیستەکە بێت
        $query->orderByRaw("CASE WHEN id = 0 THEN 0 ELSE 1 END");

        if ($user->isSalesman()) {
            // Order today's route customers first
            $todayRouteId = $user->getTodayRouteId();
            if ($todayRouteId) {
                $query->orderByRaw("CASE WHEN route_id = ? THEN 0 ELSE 1 END", [$todayRouteId]);
            }
        }

        // دانانی بەشەکان بەپێی per_page (یان ٢٠ بە دیفۆڵت)
        $perPage = !empty($filters['per_page']) ? (int)$filters['per_page'] : 20;
        if ($perPage <= 0 || $perPage > 500) {
            $perPage = 20;
        }
        return $query->paginate($perPage);
    }

    public function syncPortalUser(Customer $customer): ?User
    {
        $customerRole = Role::firstOrCreate(
            ['name' => Role::CUSTOMER],
            [
                'display_name' => 'Customer',
                'permissions' => ['orders.create', 'orders.view', 'products.view', 'customers.view'],
                'is_system' => true,
            ]
        );

        $portalUser = $customer->user_id
            ? User::withTrashed()->find($customer->user_id)
            : User::withTrashed()->where('barcode', 'CUST-' . $customer->id)->first();

        if (!$customer->can_login) {
            if ($portalUser) {
                $portalUser->update(['is_active' => false]);
                $portalUser->tokens()->delete();
            }
            return $portalUser;
        }

        $barcode = 'CUST-' . $customer->id;
        $internalPhone = 'CUSTPORTAL-' . $customer->id;
        $rawPassword = $customer->login_code ?: Str::random(16);

        if ($portalUser) {
            if ($portalUser->trashed()) {
                $portalUser->restore();
            }
            $portalUser->update([
                'name' => $customer->name,
                'phone' => $internalPhone,
                'password' => Hash::make($rawPassword),
                'role_id' => $customerRole->id,
                'barcode' => $barcode,
                'is_active' => (bool) $customer->is_active,
            ]);
            if (!$customer->is_active) {
                $portalUser->tokens()->delete();
            }
        } else {
            $portalUser = User::create([
                'name' => $customer->name,
                'phone' => $internalPhone,
                'password' => Hash::make($rawPassword),
                'role_id' => $customerRole->id,
                'barcode' => $barcode,
                'is_active' => (bool) $customer->is_active,
            ]);
        }

        if ((int) $customer->user_id !== (int) $portalUser->id) {
            $customer->user_id = $portalUser->id;
            $customer->saveQuietly();
        }

        return $portalUser->fresh();
    }

    private function normalizePortalAttributes(array $data): array
    {
        if (array_key_exists('allowed_category_ids', $data)) {
            $rawIds = is_array($data['allowed_category_ids']) ? $data['allowed_category_ids'] : [];
            $data['allowed_category_ids'] = array_values(array_unique(array_filter(
                array_map('intval', $rawIds),
                fn ($id) => $id > 0
            )));
        }

        if (array_key_exists('can_login', $data)) {
            $data['can_login'] = (bool) $data['can_login'];
            if (!$data['can_login'] && array_key_exists('login_code', $data) && $data['login_code'] === '') {
                $data['login_code'] = null;
            }
        }

        return $data;
    }

    public function createCustomer(array $data, int $userId): Customer
    {
        $customer = DB::transaction(function () use ($data, $userId) {
            $data['created_by'] = $userId;
            $data = $this->normalizePortalAttributes($data);

            $initialDebt = !empty($data['initial_debt']) ? (int)$data['initial_debt'] : 0;
            unset($data['initial_debt']);

            if (empty($data['route_id'])) {
                $defaultRoute = \App\Models\Route::firstOrCreate(
                    ['name' => 'گشتی'],
                    ['color' => '#888888', 'is_active' => true]
                );
                $data['route_id'] = $defaultRoute->id;
            }

            $data['current_balance'] = $initialDebt;

            $customer = Customer::create($data);

            if ($customer->can_login) {
                $this->syncPortalUser($customer);
            }

            if ($initialDebt > 0) {
                \App\Models\CustomerLedger::create([
                    'customer_id' => $customer->id,
                    'entry_type' => 'ADJUSTMENT',
                    'type' => 'debit',
                    'debit' => $initialDebt,
                    'credit' => 0,
                    'amount' => $initialDebt,
                    'balance_before' => 0,
                    'balance_after' => $initialDebt,
                    'description' => 'قەرزی پێشینە / قەرزی سەرەتا',
                    'created_by' => $userId,
                ]);
            }

            return $customer->fresh(['route', 'specialPrices']);
        });

        try {
            event(new \App\Events\CustomerAccountUpdated($customer, 'create'));
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning("Event broadcast failed for new customer: " . $e->getMessage());
        }

        // Notify new customer created AFTER database commit (NOT-013)
        try {
            $actor = \App\Models\User::find($userId);
            app(\App\Services\NotificationService::class)->notifyNewCustomerCreated($customer, $actor);
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning("Notification dispatch failed for new customer: " . $e->getMessage());
        }

        return $customer;
    }

    public function updateCustomer(Customer $customer, array $data): Customer
    {
        $updated = DB::transaction(function () use ($customer, $data) {
            $data = $this->normalizePortalAttributes($data);

            if (empty($data['route_id']) && !$customer->route_id) {
                $defaultRoute = \App\Models\Route::firstOrCreate(
                    ['name' => 'گشتی'],
                    ['color' => '#888888', 'is_active' => true]
                );
                $data['route_id'] = $defaultRoute->id;
            }

            $customer->update($data);
            $customer->refresh();

            if ($customer->can_login || $customer->user_id !== null) {
                $this->syncPortalUser($customer);
            }

            return $customer->fresh(['route', 'specialPrices']);
        });

        try {
            event(new \App\Events\CustomerAccountUpdated($updated, 'update'));
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning("Event broadcast failed for customer update: " . $e->getMessage());
        }

        return $updated;
    }

    public function deleteCustomer(Customer $customer): bool
    {
        $customerId = $customer->id;
        if ($customer->user_id) {
            $portalUser = User::find($customer->user_id);
            if ($portalUser) {
                $portalUser->update(['is_active' => false]);
                $portalUser->tokens()->delete();
                $portalUser->delete();
            }
        }
        $deleted = $customer->delete();
        
        if ($deleted) {
            event(new \App\Events\CustomerAccountUpdated(null, 'delete', $customerId));
        }
        
        return $deleted;
    }
}
