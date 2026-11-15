<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthService
{
    public function login(array $credentials)
    {
        // هێنانی بەکارهێنەر لەگەڵ ڕۆڵەکەی
        if (!empty($credentials['barcode'])) {
            $barcode = trim((string) $credentials['barcode']);
            $user = User::with('role')->where('barcode', $barcode)->first();

            if (!$user && preg_match('/^CUST-(\d+)$/i', $barcode, $matches)) {
                $customer = Customer::find((int) $matches[1]);
                if ($customer) {
                    if (!$customer->is_active) {
                        throw ValidationException::withMessages([
                            'barcode' => ['ئەم هەژمارە ناچالاک کراوە، پەیوەندی بە ئادمینەوە بکە.'],
                        ]);
                    }
                    if (!$customer->can_login) {
                        throw ValidationException::withMessages([
                            'barcode' => ['چوونەژوورەوە بۆ ئەم کڕیارە چالاک نەکراوە.'],
                        ]);
                    }
                    $user = app(CustomerService::class)->syncPortalUser($customer);
                    $user?->load('role');
                }
            }

            if (!$user) {
                throw ValidationException::withMessages([
                    'barcode' => ['هیچ بەکارهێنەرێک بەم بارکۆدە نەدۆزرایەوە.'],
                ]);
            }

            if ($user->isCustomer()) {
                $user->load(['customer.route', 'customer.specialPrices']);
                if (!$user->customer || !$user->customer->is_active || !$user->customer->can_login) {
                    throw ValidationException::withMessages([
                        'barcode' => ['چوونەژوورەوە بۆ ئەم کڕیارە چالاک نەکراوە.'],
                    ]);
                }
            }
        } else {
            $phone = trim((string) ($credentials['phone'] ?? ''));
            $password = (string) ($credentials['password'] ?? '');

            $user = User::with('role')->where('phone', $phone)->first();

            if ($user && !$user->isCustomer()) {
                // پشکنینی پاسۆرد بۆ کارمەند و بەڕێوەبەر
                if (!Hash::check($password, $user->password)) {
                    throw ValidationException::withMessages([
                        'phone' => ['ژمارە مۆبایل یان وشەی نهێنی هەڵەیە.'],
                    ]);
                }
            } else {
                $user = null;

                // چوونەژوورەوەی کڕیار بە کۆدی ٤ ژمارەیی لە شوێنی مۆبایل و وشەی نهێنی
                if (preg_match('/^\d{4}$/', $phone) && $phone === $password) {
                    $customer = Customer::where('login_code', $phone)->first();
                    if ($customer) {
                        if (!$customer->is_active) {
                            throw ValidationException::withMessages([
                                'phone' => ['ئەم هەژمارە ناچالاک کراوە، پەیوەندی بە ئادمینەوە بکە.'],
                            ]);
                        }
                        if (!$customer->can_login) {
                            throw ValidationException::withMessages([
                                'phone' => ['چوونەژوورەوە بۆ ئەم کڕیارە چالاک نەکراوە.'],
                            ]);
                        }
                        $user = app(CustomerService::class)->syncPortalUser($customer);
                        $user?->load(['role', 'customer.route', 'customer.specialPrices']);
                    }
                }

                if (!$user) {
                    throw ValidationException::withMessages([
                        'phone' => ['ژمارە مۆبایل یان وشەی نهێنی هەڵەیە.'],
                    ]);
                }
            }
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

        // تۆمارکردنی لە دەفتەری چاودێری (Audit Log)
        app(AuditService::class)->logAuthEvent('LOGIN', $user, null, $deviceName);

        return [
            'user' => $user,
            'token' => $token,
        ];
    }

    public function logout(User $user)
    {
        // تۆمارکردنی لە دەفتەری چاودێری (Audit Log)
        app(AuditService::class)->logAuthEvent('LOGOUT', $user);

        // سڕینەوەی تەنها ئەو تۆکنەی کە ئێستا بەکاریدەهێنێت
        /** @var \Laravel\Sanctum\HasApiTokens $user */
        $user->currentAccessToken()->delete();

        return true;
    }
}
