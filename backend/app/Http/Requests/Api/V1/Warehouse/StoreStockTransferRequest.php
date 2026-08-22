<?php

namespace App\Http\Requests\Api\V1\Warehouse;

use Illuminate\Foundation\Http\FormRequest;

class StoreStockTransferRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'from_warehouse_id' => ['required', 'integer', 'exists:warehouses,id'],
            'to_warehouse_id'   => ['required', 'integer', 'exists:warehouses,id', 'different:from_warehouse_id'],
            'notes'             => ['nullable', 'string'],

            // داواکردنی کاڵاکان
            'items'              => ['required', 'array', 'min:1'],
            'items.*.product_id' => ['required', 'integer', 'exists:products,id'],
            'items.*.quantity'   => ['required', 'integer', 'min:1'],
        ];
    }

    public function messages(): array
    {
        return [
            'to_warehouse_id.different' => 'کۆگای ناردن و وەرگرتن نابێت هەمان کۆگا بن.',
        ];
    }
}
