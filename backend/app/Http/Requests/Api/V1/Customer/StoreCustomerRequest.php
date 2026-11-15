<?php

namespace App\Http\Requests\Api\V1\Customer;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreCustomerRequest extends FormRequest
{
    public function authorize(): bool
    {
        // دواتر دەتوانیت مافەکان (Permissions) لێرە دابنێیت
        return true;
    }

    public function rules(): array
    {
        $user = $this->user();
        $isSalesman = $user && $user->isSalesman();
        $canLoginRequested = $this->boolean('can_login');

        return [
            'route_id'     => [
                $isSalesman ? 'required' : 'nullable',
                'integer',
                'exists:routes,id',
                function ($attribute, $value, $fail) use ($user, $isSalesman) {
                    if ($isSalesman) {
                        $assignedRoutes = $user->getAssignedRouteIds();
                        if (!in_array($value, $assignedRoutes)) {
                            $fail('تۆ ناتوانیت کڕیار بۆ ئەم گەڕەکە دروست بکەیت، چونکە لە دەرەوەی ڕاوتی خۆتە.');
                        }
                    }
                }
            ],
            'name'         => ['required', 'string', 'max:255'],
            'image_url'    => [
                'nullable',
                'string',
                'max:2048',
                function ($attribute, $value, $fail) use ($user) {
                    if ($value !== null && $value !== '' && $user && !$user->isAdmin()) {
                        $fail('تەنها خاوەن یان ئادمین دەتوانێت بەستەری وێنە دابنێت.');
                    }
                }
            ],
            'phone'        => ['nullable', 'string', 'max:20', Rule::unique('customers')->whereNull('deleted_at')],
            'customer_name' => ['nullable', 'string', 'max:255'],
            'address'      => ['nullable', 'string'],
            'latitude'     => ['nullable', 'numeric'],
            'longitude'    => ['nullable', 'numeric'],
            'price_type'   => ['nullable', 'in:N1,N2,N3'],
            'permanent_discount' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'initial_debt' => [
                'nullable',
                'numeric',
                'min:0',
                function ($attribute, $value, $fail) use ($user) {
                    if ($value !== null && $value != 0 && $user && !$user->isAdmin()) {
                        $fail('تەنها خاوەن یان ئادمین دەتوانێت قەرزی پێشینە دابنێت.');
                    }
                }
            ],
            'is_active'    => ['boolean'],
            'can_login'    => [
                'nullable',
                'boolean',
                function ($attribute, $value, $fail) use ($user) {
                    if (filter_var($value, FILTER_VALIDATE_BOOLEAN) && $user && !$user->isAdmin()) {
                        $fail('تەنها خاوەن یان ئادمین دەتوانێت چوونەژوورەوەی کڕیار چالاک بکات.');
                    }
                }
            ],
            'login_code'   => [
                $canLoginRequested ? 'required' : 'nullable',
                'string',
                'regex:/^\d{4}$/',
                Rule::unique('customers', 'login_code')->whereNull('deleted_at'),
                function ($attribute, $value, $fail) use ($user) {
                    if ($value !== null && $value !== '' && $user && !$user->isAdmin()) {
                        $fail('تەنها خاوەن یان ئادمین دەتوانێت کۆدی چوونەژوورەوەی کڕیار دابنێت.');
                    }
                }
            ],
            'allowed_category_ids' => [
                'nullable',
                'array',
                function ($attribute, $value, $fail) use ($user) {
                    if (!empty($value) && $user && !$user->isAdmin()) {
                        $fail('تەنها خاوەن یان ئادمین دەتوانێت کاتیگۆرییەکان بۆ کڕیار دیاری بکات.');
                    }
                }
            ],
            'allowed_category_ids.*' => ['integer', 'exists:categories,id'],
        ];
    }

    public function messages(): array
    {
        return [
            'name.required' => 'تکایە ناوی کڕیار بنووسە',
            'phone.unique' => 'ئەم ژمارەی مۆبایلە پێشتر بەکارهاتووە',
            'login_code.required' => 'تکایە کۆدی ٤ ژمارەیی چوونەژوورەوە بنووسە',
            'login_code.regex' => 'کۆدی چوونەژوورەوە دەبێت ڕێک ٤ ژمارە بێت',
            'login_code.unique' => 'ئەم کۆدە ٤ ژمارەییە پێشتر بۆ کڕیارێکی تر بەکارهاتووە',
        ];
    }
}
