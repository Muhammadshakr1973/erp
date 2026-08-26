<?php

namespace App\Http\Requests\Api\V1\Customer;

use Illuminate\Foundation\Http\FormRequest;

class StoreCustomerRequest extends FormRequest
{
    public function authorize(): bool
    {
        // دواتر دەتوانیت مافەکان (Permissions) لێرە دابنێیت
        return true;
    }

    public function rules(): array
    {
        return [
            'route_id'     => ['nullable', 'integer', 'exists:routes,id'],
            'name'         => ['required', 'string', 'max:255'],
            'phone'        => ['nullable', 'string', 'max:20', \Illuminate\Validation\Rule::unique('customers')->whereNull('deleted_at')],
            'phone2'       => ['nullable', 'string', 'max:20'],
            'address'      => ['nullable', 'string'],
            'latitude'     => ['nullable', 'numeric'],
            'longitude'    => ['nullable', 'numeric'],
            'price_type'   => ['nullable', 'in:N1,N2,N3'],
            'initial_debt' => ['nullable', 'numeric', 'min:0'],
            'is_active'    => ['boolean'],
        ];
    }
}
