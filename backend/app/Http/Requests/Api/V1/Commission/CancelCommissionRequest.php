<?php

namespace App\Http\Requests\Api\V1\Commission;

use Illuminate\Foundation\Http\FormRequest;

class CancelCommissionRequest extends FormRequest
{
    public function authorize(): bool
    {
        $user = $this->user();
        return $user && ($user->isAdmin() || $user->isOwner() || $user->hasPermission('users.manage'));
    }

    public function rules(): array
    {
        return [
            'reason' => ['required', 'string', 'min:3', 'max:1000'],
        ];
    }

    public function messages(): array
    {
        return [
            'reason.required' => 'تکایە هۆکاری هەڵوەشاندنەوەی کۆمسیۆن بنووسە.',
            'reason.min'      => 'هۆکاری هەڵوەشاندنەوە دەبێت لانیکەم ٣ پیت بێت.',
        ];
    }
}
