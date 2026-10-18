<?php

namespace App\Http\Requests\Api\V1\SalesOrder;

use Illuminate\Foundation\Http\FormRequest;

class StoreSalesOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        $user = $this->user();
        if ($user && $user->role?->name === 'salesman' && $user->warehouse_id) {
            if ($user->isCashVan() || !$this->has('warehouse_id')) {
                $this->merge([
                    'warehouse_id' => $user->warehouse_id,
                ]);
            }
        }

        if ($this->has('customer_id') && (int)$this->input('customer_id') === 0) {
            $tempCustomer = \App\Models\Customer::where('id', 0)->first();
            if (!$tempCustomer) {
                $defaultRoute = \App\Models\Route::firstOrCreate(
                    ['name' => 'گشتی'],
                    ['color' => '#888888', 'is_active' => true]
                );
                \Illuminate\Support\Facades\DB::statement('SET SESSION sql_mode = "NO_AUTO_VALUE_ON_ZERO";');
                \App\Models\Customer::create([
                    'id' => 0,
                    'name' => 'کڕیاری کاتی (بێ ناو)',
                    'phone' => '00000000000',
                    'route_id' => $defaultRoute->id,
                    'price_type' => 'N3',
                    'current_balance' => 0,
                    'is_active' => true,
                ]);
            }
        }
    }

    public function rules(): array
    {
        return [
            'customer_id' => ['required', 'integer', 'exists:customers,id'],
            'warehouse_id' => ['required', 'integer', 'exists:warehouses,id'],
            'discount_percent' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'discount_amount' => ['nullable', 'numeric', 'min:0'],
            'discount_type' => ['nullable', 'string', 'in:PERCENT,FIXED,percent,fixed'],
            'notes' => ['nullable', 'string'],
            'shared_key' => ['nullable', 'string', 'max:100'],
            'version' => ['nullable', 'integer', 'min:1'],
            'price_type' => ['nullable', 'string', 'in:N1,N2,N3,n1,n2,n3'],

            // پشکنینی ئایتمەکانی پسوڵەکە (ڕێگە بە بەتاڵبوون دەدرێت بۆ دراوتی سەرەتایی)
            'items' => ['nullable', 'array'],
            'items.*.product_id' => ['required', 'integer', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'items.*.notes' => ['nullable', 'string'],
            'status' => ['nullable', 'string', 'in:PACKING,READY,DRAFT,CONFIRMED'],

            // پشکنینی کاڵا گەڕاوەکان لە هەمان پسوڵەدا
            'returned_items' => ['nullable', 'array'],
            'returned_items.*.product_id' => ['required', 'integer', 'exists:products,id'],
            'returned_items.*.quantity' => ['required', 'integer', 'min:1'],
            'returned_items.*.unit_price' => ['nullable', 'numeric', 'min:0'],
            'returned_items.*.reason' => ['nullable', 'string', 'max:255'],
        ];
    }
}
