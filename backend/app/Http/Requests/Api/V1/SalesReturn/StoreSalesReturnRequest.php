<?php

namespace App\Http\Requests\Api\V1\SalesReturn;

use Illuminate\Foundation\Http\FormRequest;

class StoreSalesReturnRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'sales_order_id'                  => ['required', 'integer', 'exists:sales_orders,id'],
            'reason'                          => ['nullable', 'string', 'max:500'],
            'items'                           => ['required', 'array', 'min:1'],
            'items.*.sales_order_item_id'     => ['required', 'integer', 'exists:sales_order_items,id'],
            'items.*.quantity'                => ['required', 'integer', 'min:1'],
            'items.*.reason'                  => ['nullable', 'string', 'max:255'],
        ];
    }
}
