<?php

namespace App\Services;

use App\Models\DeviceToken;
use App\Models\Setting;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class PushNotificationService
{
    /**
     * Send push notification to multiple device tokens
     *
     * @param array|int $userIds
     * @param string $title
     * @param string $body
     * @param array $data
     * @return array
     */
    public function sendToUsers(array|int $userIds, string $title, string $body, array $data = []): array
    {
        $userIds = is_array($userIds) ? $userIds : [$userIds];

        $tokens = DeviceToken::whereIn('user_id', $userIds)
            ->where('is_active', true)
            ->get();

        if ($tokens->isEmpty()) {
            return [
                'sent_count' => 0,
                'status' => 'NO_ACTIVE_TOKENS',
            ];
        }

        return $this->sendToTokens($tokens->pluck('token')->filter()->all(), $title, $body, $data);
    }

    /**
     * Send push notification to specific tokens via FCM
     *
     * @param array $tokenStrings
     * @param string $title
     * @param string $body
     * @param array $data
     * @return array
     */
    public function sendToTokens(array $tokenStrings, string $title, string $body, array $data = []): array
    {
        if (empty($tokenStrings)) {
            return ['sent_count' => 0, 'status' => 'EMPTY_TOKENS'];
        }

        $fcmServerKey = config('services.fcm.server_key') 
            ?? env('FCM_SERVER_KEY') 
            ?? Setting::getValue('fcm_server_key');

        if (!$fcmServerKey) {
            Log::info("FCM Push Notification Simulated (Server Key Not Configured): [{$title}] {$body}", [
                'token_count' => count($tokenStrings),
                'data' => $data,
            ]);

            return [
                'sent_count' => count($tokenStrings),
                'status' => 'SIMULATED_UNCONFIGURED_FCM',
                'message' => 'FCM server key is not configured in environment or settings. Notification logged successfully.',
            ];
        }

        try {
            $payload = [
                'registration_ids' => array_values($tokenStrings),
                'notification' => [
                    'title' => $title,
                    'body' => $body,
                    'sound' => 'default',
                ],
                'data' => $data,
            ];

            $response = Http::withHeaders([
                'Authorization' => 'key=' . $fcmServerKey,
                'Content-Type' => 'application/json',
            ])->post('https://fcm.googleapis.com/fcm/send', $payload);

            if ($response->successful()) {
                $result = $response->json();
                
                // Handle invalid tokens if any
                if (!empty($result['results'])) {
                    foreach ($result['results'] as $index => $res) {
                        if (isset($res['error']) && in_array($res['error'], ['NotRegistered', 'InvalidRegistration'])) {
                            if (isset($tokenStrings[$index])) {
                                DeviceToken::where('token', $tokenStrings[$index])
                                    ->update(['is_active' => false]);
                            }
                        }
                    }
                }

                return [
                    'sent_count' => $result['success'] ?? count($tokenStrings),
                    'failure_count' => $result['failure'] ?? 0,
                    'status' => 'SUCCESS',
                    'response' => $result,
                ];
            }

            Log::error('FCM HTTP Request Failed: ' . $response->body());
            return [
                'sent_count' => 0,
                'status' => 'FAILED',
                'error' => $response->body(),
            ];
        } catch (\Throwable $e) {
            Log::error('FCM Push Notification Exception: ' . $e->getMessage());
            return [
                'sent_count' => 0,
                'status' => 'ERROR',
                'error' => $e->getMessage(),
            ];
        }
    }
}
