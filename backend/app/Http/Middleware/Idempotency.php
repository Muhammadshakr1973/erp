<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Database\QueryException;
use Symfony\Component\HttpFoundation\Response;

class Idempotency
{
    /**
     * Handle an incoming request.
     *
     * @param  \Illuminate\Http\Request  $request
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     * @return \Symfony\Component\HttpFoundation\Response
     */
    public function handle(Request $request, Closure $next): Response
    {
        $idempotencyKey = $request->header('X-Idempotency-Key');

        if (!$idempotencyKey) {
            return $next($request);
        }

        // Limit length/format for safety
        $idempotencyKey = substr(trim($idempotencyKey), 0, 255);

        try {
            // Try to register the key as processing
            DB::table('idempotency_keys')->insert([
                'idempotency_key' => $idempotencyKey,
                'request_path' => $request->path(),
                'request_params' => json_encode($request->all()),
                'status' => 'processing',
                'created_at' => now(),
                'updated_at' => now()
            ]);
        } catch (QueryException $e) {
            // Unique constraint violation means it already exists (concurrent or previous submission)
            $existing = DB::table('idempotency_keys')->where('idempotency_key', $idempotencyKey)->first();

            if ($existing) {
                if ($existing->status === 'processing') {
                    return response()->json([
                        'message' => 'ئەم کردارە لە پرۆسەدایە، تکایە چاوەڕێ بکە.',
                        'error' => 'Conflict. A request with this key is already being processed.'
                    ], 409);
                }

                if ($existing->status === 'completed') {
                    $headers = [
                        'X-Cache-Lookup' => 'HIT',
                        'X-Idempotency-Key' => $idempotencyKey,
                        'Content-Type' => 'application/json'
                    ];

                    return response($existing->response_body, $existing->response_status, $headers);
                }
            }

            // Fallback
            return response()->json([
                'message' => 'هەڵەیەک ڕوویدا لە تۆمارکردنی کلیلەکە.',
                'error' => 'Conflict. Duplicate key entry.'
            ], 409);
        }

        try {
            // Proceed with request
            $response = $next($request);

            // If response is successful, persist the outcome
            if ($response->isSuccessful()) {
                DB::table('idempotency_keys')
                    ->where('idempotency_key', $idempotencyKey)
                    ->update([
                        'status' => 'completed',
                        'response_status' => $response->getStatusCode(),
                        'response_body' => $response->getContent(),
                        'updated_at' => now()
                    ]);
            } else {
                // If it failed (e.g. 422 validation, 400 bad request), delete key to allow retries with fixes
                DB::table('idempotency_keys')->where('idempotency_key', $idempotencyKey)->delete();
            }

            return $response;
        } catch (\Throwable $e) {
            // On exception, delete the key so transaction is retry-safe
            DB::table('idempotency_keys')->where('idempotency_key', $idempotencyKey)->delete();
            throw $e;
        }
    }
}
