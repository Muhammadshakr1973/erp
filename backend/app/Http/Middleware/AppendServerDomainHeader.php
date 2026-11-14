<?php

namespace App\Http\Middleware;

use App\Models\Setting;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AppendServerDomainHeader
{
    /**
     * Attach the active system-wide server domain header to API responses
     * so all connected client apps stay synced when the Owner updates it.
     */
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        try {
            $domain = (string) (Setting::getValue('server_domain', '') ?? '');
            $response->headers->set('X-Server-Domain', $domain);
        } catch (\Throwable $e) {
            // Do not block API responses if settings cache/DB is unavailable
        }

        return $response;
    }
}
