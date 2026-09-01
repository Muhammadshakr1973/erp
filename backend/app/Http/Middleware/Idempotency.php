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
        $idempotencyKey = $request->header('X-Idempotency-Key') ?: $request->header('Idempotency-Key');

        if (!$idempotencyKey) {
            return $next($request);
        }

        // Limit length/format for safety
        $idempotencyKey = substr(trim($idempotencyKey), 0, 255);
        $userId = $request->user()?->id;
        $requestHash = $this->computeRequestHash($request, $userId);
        $normalizedParams = $this->normalizePayload($request->all());

        try {
            // Try to register the key as processing with canonical request hash
            DB::table('idempotency_keys')->insert([
                'idempotency_key' => $idempotencyKey,
                'user_id' => $userId,
                'request_path' => $request->path(),
                'request_hash' => $requestHash,
                'request_params' => json_encode($normalizedParams, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
                'status' => 'processing',
                'created_at' => now(),
                'updated_at' => now()
            ]);
        } catch (QueryException $e) {
            // Unique constraint violation means it already exists (concurrent or previous submission)
            $existing = DB::table('idempotency_keys')->where('idempotency_key', $idempotencyKey)->first();

            if ($existing) {
                // 1. Security check: ensure requesting user owns this idempotency key
                if ($existing->user_id !== null && $existing->user_id !== $userId) {
                    return response()->json([
                        'message' => 'تۆ ڕێگەپێدراو نیت بۆ بەکارهێنانی ئەم کردارە.',
                        'error' => 'Forbidden. This idempotency key belongs to another user.'
                    ], 403);
                }

                // 2. Hash / Payload mismatch check
                // Compare calculated request hash against stored hash
                $storedHash = $existing->request_hash ?? null;
                $hashMatches = $storedHash ? hash_equals($storedHash, $requestHash) : ($existing->request_path === $request->path());

                if (!$hashMatches) {
                    return response()->json([
                        'message' => 'Idempotency key payload mismatch',
                        'error' => 'Idempotency key payload mismatch. The request parameters or endpoint do not match the original request.'
                    ], 422);
                }

                // 3. Processing check
                if ($existing->status === 'processing') {
                    return response()->json([
                        'message' => 'ئەم کردارە لە پرۆسەدایە، تکایە چاوەڕێ بکە.',
                        'error' => 'Conflict. A request with this key is already being processed.'
                    ], 409);
                }

                // 4. Completed check: replay original response
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

    /**
     * Build canonical representation and return its SHA-256 hash.
     */
    public function computeRequestHash(Request $request, ?int $userId): string
    {
        $normalizedParams = $this->normalizePayload($request->all());

        $canonicalData = [
            'method' => strtoupper($request->method()),
            'path' => trim($request->path(), '/'),
            'user_id' => $userId,
            'params' => $normalizedParams,
        ];

        $canonicalJson = json_encode($canonicalData, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

        return hash('sha256', $canonicalJson);
    }

    /**
     * Recursively sort associative array keys to ensure deterministic hashing.
     */
    private function normalizePayload(mixed $data): mixed
    {
        if (!is_array($data)) {
            return $data;
        }

        // Check if associative array
        $isAssoc = !empty($data) && array_keys($data) !== range(0, count($data) - 1);
        if ($isAssoc) {
            ksort($data);
        }

        foreach ($data as $key => $value) {
            $data[$key] = $this->normalizePayload($value);
        }

        return $data;
    }
}

