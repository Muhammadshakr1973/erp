<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureOwner
{
    /**
     * Allow access strictly to users with the 'owner' role.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if (!$user) {
            return response()->json([
                'message' => 'پێویستە سەرەتا بچیتە ژوورەوە.',
                'error' => 'Unauthenticated.',
            ], 401);
        }

        if (!$user->isOwner()) {
            return response()->json([
                'message' => 'تەنها خاوەنکار (Owner) مۆڵەتی گەیشتنی بەم بەشە هەیە.',
                'error' => 'Forbidden. Owner role required.',
            ], 403);
        }

        return $next($request);
    }
}
