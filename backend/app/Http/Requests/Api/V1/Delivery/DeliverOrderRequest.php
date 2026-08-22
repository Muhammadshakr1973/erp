<?php

namespace App\Http\Requests\Api\V1\Delivery;

use Illuminate\Foundation\Http\FormRequest;

class DeliverOrderRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            // بڕی ئەو پارەیەی شۆفێرەکە لە کڕیارەکەی وەرگرتووە (دەکرێت سفر بێت ئەگەر هەمووی بە قەرز ببات)
            'received_amount' => ['required', 'integer', 'min:0'],
            'notes'           => ['nullable', 'string'],
        ];
    }
}
