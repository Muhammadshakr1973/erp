<?php

namespace App\Http\Requests\Api\V1\Purchase;

use Illuminate\Foundation\Http\FormRequest;

class StorePurchaseOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true; // دەتوانیت ڕۆڵی ئادمین یان کڕین لێرە دابنێیت
    }

    public function rules(): array
    {
        return [
            'supplier_id'  => ['required', 'integer', 'exists:suppliers,id'],
            'warehouse_id' => ['required', 'integer', 'exists:warehouses,id'],
            'notes'        => ['nullable', 'string'],

            // ئایتمەکانی ناو پسوڵەی کڕین
            'items'              => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'integer', 'exists:products,id'],
            'items.*.quantity'   => ['required', 'integer', 'min:1'],
            'items.*.unit_cost'  => ['required', 'integer', 'min:0'], // نرخی کڕینی یەک دانە
        ];
    }
}
