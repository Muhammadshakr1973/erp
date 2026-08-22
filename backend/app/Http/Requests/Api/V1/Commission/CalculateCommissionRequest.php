<?php

namespace App\Http\Requests\Api\V1\Commission;

use Illuminate\Foundation\Http\FormRequest;

class CalculateCommissionRequest extends FormRequest
{
    public function authorize(): bool
    {
        // تەنها ئادمین یان خاوەندارێت دەتوانێت کۆمسیۆن هەژمار بکات
        return $this->user()->role->name === 'admin' || $this->user()->role->name === 'owner';
    }

    public function rules(): array
    {
        return [
            'salesman_id' => ['required', 'integer', 'exists:users,id'],
            'period_from' => ['required', 'date'],
            'period_to'   => ['required', 'date', 'after_or_equal:period_from'],
        ];
    }
}
