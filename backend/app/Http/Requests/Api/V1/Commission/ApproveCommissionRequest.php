<?php

namespace App\Http\Requests\Api\V1\Commission;

use Illuminate\Foundation\Http\FormRequest;

class ApproveCommissionRequest extends FormRequest
{
    public function authorize(): bool
    {
        $user = $this->user();
        return $user && ($user->isAdmin() || $user->isOwner() || $user->hasPermission('users.manage'));
    }

    public function rules(): array
    {
        return [
            'notes' => ['nullable', 'string', 'max:1000'],
        ];
    }
}
