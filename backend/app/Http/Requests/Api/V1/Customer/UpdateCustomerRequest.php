<?php

namespace App\Http\Requests\Api\V1\Customer;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateCustomerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        // وەرگرتنی ئایدی کڕیارەکە لە URLـەکەوە بۆ ئەوەی ڕێگە بە هەمان ژمارە مۆبایل بداتەوە لەکاتی ئەپدەیت
        $customerId = $this->route('customer');

        return [
            'route_id'   => ['required', 'integer', 'exists:routes,id'],
            'name'       => ['required', 'string', 'max:255'],
            'phone'      => ['nullable', 'string', 'max:20', Rule::unique('customers')->ignore($customerId)],
            'phone2'     => ['nullable', 'string', 'max:20'],
            'address'    => ['nullable', 'string'],
            'latitude'   => ['nullable', 'numeric'],
            'longitude'  => ['nullable', 'numeric'],
            'price_type' => ['nullable', 'in:N1,N2,N3'],
            'is_active'  => ['boolean'],
        ];
    }
}
