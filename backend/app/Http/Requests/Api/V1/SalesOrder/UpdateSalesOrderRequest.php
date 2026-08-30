<?php

namespace App\Http\Requests\Api\V1\SalesOrder;

use Illuminate\Foundation\Http\FormRequest;

class UpdateSalesOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
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

            // داواکردنی ئایتمەکانی پسوڵەکە (لانی کەم دەبێت ١ کاڵای تێدابێت)
            'items' => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'integer', 'exists:products,id'],
            'items.*.quantity' => ['required', 'integer', 'min:1'],
            'status' => ['nullable', 'string', 'in:DRAFT,CONFIRMED'],
        ];
    }
}
