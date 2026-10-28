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
        $isAutoReceive = $this->boolean('auto_receive', false);
        return [
            'supplier_id'  => ['nullable', 'integer'],
            'warehouse_id' => ['required', 'integer', 'exists:warehouses,id'],
            'notes'        => ['nullable', 'string'],
            'paid_amount'  => ['nullable', 'numeric', 'min:0'],
            'auto_receive' => ['nullable', 'boolean'],

            // ئایتمەکانی ناو پسوڵەی کڕین
            'items'              => [$isAutoReceive ? 'required' : 'nullable', 'array'],
            'items.*.product_id' => ['required', 'integer', 'exists:products,id'],
            'items.*.quantity'   => ['required', 'integer', 'min:1'],
            'items.*.unit_cost'  => ['required', 'integer', 'min:0'], // نرخی کڕینی یەک دانە
        ];
    }
}
