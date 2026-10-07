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

        $user = $this->user();
        $isSalesman = $user && $user->isSalesman();

        return [
            'route_id'   => [
                $isSalesman ? 'required' : 'nullable',
                'integer',
                'exists:routes,id',
                function ($attribute, $value, $fail) use ($user, $isSalesman) {
                    if ($isSalesman) {
                        $assignedRoutes = $user->getAssignedRouteIds();
                        if (!in_array($value, $assignedRoutes)) {
                            $fail('تۆ ناتوانیت کڕیار بۆ ئەم گەڕەکە بگوازیتەوە، چونکە لە دەرەوەی ڕاوتی خۆتە.');
                        }
                    }
                }
            ],
            'name'       => ['required', 'string', 'max:255'],
            'image_url'  => [
                'nullable',
                'string',
                'max:2048',
                function ($attribute, $value, $fail) use ($user) {
                    if ($value !== null && $value !== '' && $user && !$user->isAdmin()) {
                        // Check if the image url changed from current value
                        $customer = $this->route('customer');
                        $currentImageUrl = $customer instanceof \App\Models\Customer ? $customer->image_url : null;
                        if ($value !== $currentImageUrl) {
                            $fail('تەنها خاوەن یان ئادمین دەتوانێت بەستەری وێنە دابنێت.');
                        }
                    }
                }
            ],
            'phone'      => ['nullable', 'string', 'max:20', Rule::unique('customers')->ignore($customerId)->whereNull('deleted_at')],
            'phone2'     => ['nullable', 'string', 'max:20'],
            'address'    => ['nullable', 'string'],
            'latitude'   => ['nullable', 'numeric'],
            'longitude'  => ['nullable', 'numeric'],
            'price_type' => ['nullable', 'in:N1,N2,N3'],
            'permanent_discount' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'is_active'  => ['boolean'],
        ];
    }

    public function messages(): array
    {
        return [
            'name.required' => 'تکایە ناوی کڕیار بنووسە',
            'phone.unique' => 'ئەم ژمارەی مۆبایلە پێشتر بەکارهاتووە',
        ];
    }
}
