<?php

namespace App\Http\Requests\Api\V1\Commission;

use Illuminate\Foundation\Http\FormRequest;

class PayCommissionRequest extends FormRequest
{
    public function authorize(): bool
    {
        $user = $this->user();
        return $user && ($user->isAdmin() || $user->isOwner() || $user->hasPermission('users.manage'));
    }

    public function rules(): array
    {
        return [
            'payment_method' => ['nullable', 'string', 'in:cash,bank,transfer,CASH,BANK,TRANSFER'],
            'paid_at'        => ['nullable', 'date'],
            'notes'          => ['nullable', 'string', 'max:1000'],
        ];
    }

    public function messages(): array
    {
        return [
            'payment_method.in' => 'شێوازی پارەدان دەبێت کاش (cash) یان بانک (bank) یان حەواڵە (transfer) بێت.',
        ];
    }
}
