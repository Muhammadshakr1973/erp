<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureHasPermission
{
    /**
     * Handle an incoming request.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     * @param  string  $permission
     * @return \Symfony\Component\HttpFoundation\Response
     */
    public function handle(Request $request, Closure $next, string $permission): Response
    {
        $user = $request->user();

        // 401 unauthenticated
        if (!$user) {
            return response()->json([
                'message' => 'پێویستە سەرەتا بچیتە ژوورەوە.',
                'error' => 'Unauthenticated.'
            ], 401);
        }

        // 403 unauthorized
        if (!$user->hasPermission($permission)) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ ئەنجامدانی ئەم کردارە.',
                'error' => 'Forbidden. Missing permission: ' . $permission
            ], 403);
        }

        return $next($request);
    }
}
