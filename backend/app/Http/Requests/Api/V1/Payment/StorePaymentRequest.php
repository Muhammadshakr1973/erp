<?php

namespace App\Http\Requests\Api\V1\Payment;

use Illuminate\Foundation\Http\FormRequest;

class StorePaymentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function rules(): array
    {
        return [
            'customer_id' => ['required', 'integer', 'exists:customers,id'],
            // sales_order_id دەتوانێت بەتاڵ بێت بەپێی DEC-010
            'sales_order_id' => ['nullable', 'integer', 'exists:sales_orders,id'],
            'amount' => ['required', 'integer', 'min:1'], // پارە دەبێت ژمارەی تەواو بێت (DEC-012)
            'payment_method' => ['nullable', 'in:CASH,BANK'],
            'notes' => ['nullable', 'string'],
        ];
    }
}