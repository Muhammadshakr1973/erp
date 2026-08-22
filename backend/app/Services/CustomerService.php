<?php

namespace App\Services;

use App\Models\Customer;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;

class CustomerService
{
    /**
     * هێنانی کڕیارەکان بەپێی فلتەر و مافی بەکارهێنەر
     */
    public function getAllCustomers(array $filters, $user): LengthAwarePaginator
    {
        $query = Customer::with('route');

        // ئەگەر بەکارهێنەر مەندوب بوو، تەنها کڕیارەکانی ئەو گەڕەکانە دەبینێت کە بۆی دانراون
        // تێبینی: دەبێت فەنکشنی (isSalesman) لە مۆدێلی User هەبێت
        if ($user->role->name === 'salesman') {
            $routeIds = $user->routeSalesmen()->where('is_active', true)->pluck('route_id');
            $query->whereIn('route_id', $routeIds);
        }

        // فلتەرکردن بەپێی گەڕەک ئەگەر نێردرابوو
        if (!empty($filters['route_id'])) {
            $query->where('route_id', $filters['route_id']);
        }

        // گەڕان بەپێی ناو یان تەلەفۆن
        if (!empty($filters['search'])) {
            $search = $filters['search'];
            $query->where(function ($q) use ($search) {
                $q->where('name', 'like', "%{$search}%")
                    ->orWhere('phone', 'like', "%{$search}%");
            });
        }

        // فلتەرکردن بەپێی قەرز (تەنها ئەوانەی قەرزدارن)
        if (isset($filters['has_debt']) && $filters['has_debt'] == 'true') {
            $query->where('current_balance', '>', 0);
        }

        // دانانی بەشەکان بە ٢٠ کڕیار بۆ هەر پەڕەیەک (Pagination)
        return $query->paginate(20);
    }

    public function createCustomer(array $data, int $userId): Customer
    {
        $data['created_by'] = $userId;

        // لەبەرئەوەی کڕیاری نوێیە، قەرزەکەی دەبێت سفر بێت
        $data['current_balance'] = 0;

        return Customer::create($data);
    }

    public function updateCustomer(Customer $customer, array $data): Customer
    {
        $customer->update($data);
        return $customer;
    }

    public function deleteCustomer(Customer $customer): bool
    {
        // سڕینەوەی نەرم (Soft Delete) جێبەجێ دەکات بەپێی مۆدێلەکەت
        return $customer->delete();
    }
}
