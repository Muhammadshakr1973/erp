<?php

namespace App\Http\Requests\Api\V1\Delivery;

use Illuminate\Foundation\Http\FormRequest;

class FailOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'failed_reason' => ['required', 'string', 'max:255'],
            'notes'         => ['nullable', 'string'],
        ];
    }
}
