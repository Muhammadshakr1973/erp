<?php

namespace App\Http\Requests\Api\V1\Auth;

use Illuminate\Foundation\Http\FormRequest;

class LoginRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // لە داتابەیسەکەت phone بەکاردێت بۆ لۆگین بەپێی سیدەرەکانت
            'phone' => ['required', 'string'],
            'password' => ['required', 'string', 'min:6'],
            'device_name' => ['nullable', 'string'], // بۆ نموونە: iPhone 14 یان Web
        ];
    }
}
