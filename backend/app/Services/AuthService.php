<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthService
{
    public function login(array $credentials)
    {
        // هێنانی بەکارهێنەر لەگەڵ ڕۆڵەکەی
        $user = User::with('role')->where('phone', $credentials['phone'])->first();

        // پشکنینی پاسۆرد و بوونی بەکارهێنەر
        if (! $user || ! Hash::check($credentials['password'], $user->password)) {
            throw ValidationException::withMessages([
                'phone' => ['ژمارە مۆبایل یان وشەی نهێنی هەڵەیە.'],
            ]);
        }

        // پشکنین بزانین ئایا ئەکاونتەکەی ڕاگیراوە (inactive)؟
        if (! $user->is_active) {
            throw ValidationException::withMessages([
                'phone' => ['ئەم هەژمارە ناچالاک کراوە، پەیوەندی بە ئادمینەوە بکە.'],
            ]);
        }

        // نوێکردنەوەی کاتی کۆتا چوونەژوورەوە
        $user->update(['last_login_at' => now()]);

        // ناوی ئامێرەکە دیاری دەکەین یان وشەی گشتی دادەنێین
        $deviceName = $credentials['device_name'] ?? 'Unknown Device';

        // دروستکردنی تۆکنی Sanctum
        $token = $user->createToken($deviceName)->plainTextToken;

        return [
            'user' => $user,
            'token' => $token,
        ];
    }

    public function logout(User $user)
    {
        // سڕینەوەی تەنها ئەو تۆکنەی کە ئێستا بەکاریدەهێنێت
        /** @var \Laravel\Sanctum\HasApiTokens $user */
        $user->currentAccessToken()->delete();

        return true;
    }
}
