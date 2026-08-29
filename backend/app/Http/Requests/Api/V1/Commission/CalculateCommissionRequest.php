<?php

namespace App\Http\Requests\Api\V1\Commission;

use Illuminate\Foundation\Http\FormRequest;

class CalculateCommissionRequest extends FormRequest
{
    public function authorize(): bool
    {
        $user = $this->user();
        return $user && ($user->isAdmin() || $user->isOwner() || $user->hasPermission('users.manage'));
    }

    public function rules(): array
    {
        return [
            'salesman_id' => ['required', 'integer', 'exists:users,id'],
            'period_from' => ['required', 'date_format:Y-m-d'],
            'period_to'   => ['required', 'date_format:Y-m-d', 'after_or_equal:period_from'],
            'notes'       => ['nullable', 'string', 'max:1000'],
        ];
    }

    public function messages(): array
    {
        return [
            'salesman_id.required'     => 'دیاریکردنی مەندوب پێویستە.',
            'salesman_id.exists'       => 'مەندوبی داواکراو بوونی نییە.',
            'period_from.required'     => 'بەرواری سەرەتای ماوە پێویستە.',
            'period_from.date_format'  => 'فۆرماتی بەرواری سەرەتا دەبێت YYYY-MM-DD بێت.',
            'period_to.required'       => 'بەرواری کۆتایی ماوە پێویستە.',
            'period_to.date_format'    => 'فۆرماتی بەرواری کۆتایی دەبێت YYYY-MM-DD بێت.',
            'period_to.after_or_equal' => 'بەرواری کۆتایی دەبێت دوای یان یەکسان بێت بە بەرواری سەرەتا.',
        ];
    }
}
