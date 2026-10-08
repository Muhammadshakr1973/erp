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
        if ($user && $user->role?->name === 'salesman' && $user->warehouse_id && !$this->has('warehouse_id')) {
            $this->merge([
                'warehouse_id' => $user->warehouse_id,
            ]);
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
        ];
    }
}
