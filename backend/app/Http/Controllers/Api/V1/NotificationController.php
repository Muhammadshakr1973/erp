<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class NotificationController extends Controller
{
    protected NotificationService $notificationService;

    public function __construct(NotificationService $notificationService)
    {
        $this->notificationService = $notificationService;
    }

    /**
     * GET /api/v1/notifications
     * List user's notifications with filters and unread count
     */
    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $perPage = (int) $request->input('per_page', 20);

        $notifications = $this->notificationService->getNotificationsForUser(
            $user,
            $request->only(['type', 'is_read']),
            $perPage
        );

        $unreadCount = $this->notificationService->getUnreadCount($user);

        return response()->json([
            'data' => $notifications->items(),
            'unread_count' => $unreadCount,
            'meta' => [
                'current_page' => $notifications->currentPage(),
                'last_page' => $notifications->lastPage(),
                'per_page' => $notifications->perPage(),
                'total' => $notifications->total(),
            ],
        ]);
    }

    /**
     * GET /api/v1/notifications/unread-count
     * Quick check for unread badge
     */
    public function unreadCount(Request $request): JsonResponse
    {
        $unreadCount = $this->notificationService->getUnreadCount($request->user());

        return response()->json([
            'unread_count' => $unreadCount,
        ]);
    }

    /**
     * POST /api/v1/notifications/{id}/read
     * Mark single notification as read
     */
    public function markRead(int $id, Request $request): JsonResponse
    {
        $notification = $this->notificationService->markAsRead($id, $request->user());

        return response()->json([
            'success' => true,
            'data' => $notification,
            'message' => 'ئاگادارکردنەوەکە خوێندرایەوە',
        ]);
    }

    /**
     * POST /api/v1/notifications/read or POST /api/v1/notifications/mark-all-read
     * Mark all unread notifications as read
     */
    public function markAllRead(Request $request): JsonResponse
    {
        $updatedCount = $this->notificationService->markAllAsRead($request->user());

        return response()->json([
            'success' => true,
            'updated_count' => $updatedCount,
            'message' => 'هەموو ئاگادارکردنەوەکان بە خوێندراوە دۆران',
        ]);
    }

    /**
     * POST /api/v1/device-token or POST /api/v1/notifications/device-token
     * Register or update device push token
     */
    public function registerDeviceToken(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'token' => 'required_without:device_token|string|nullable',
            'device_token' => 'required_without:token|string|nullable',
            'device_type' => ['nullable', 'string', Rule::in(['android', 'ios', 'web'])],
            'device_name' => 'nullable|string|max:150',
        ]);

        $token = $validated['device_token'] ?? $validated['token'];
        $deviceType = $validated['device_type'] ?? 'android';
        $deviceName = $validated['device_name'] ?? null;

        $deviceToken = $this->notificationService->registerDeviceToken(
            $request->user(),
            $token,
            $deviceType,
            $deviceName
        );

        return response()->json([
            'success' => true,
            'data' => $deviceToken,
            'message' => 'تۆکنی ئامێر بە سەرکەوتوویی تۆمارکرا',
        ]);
    }

    /**
     * DELETE /api/v1/device-token
     * Remove/deactivate device token on logout
     */
    public function removeDeviceToken(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'token' => 'required_without:device_token|string|nullable',
            'device_token' => 'required_without:token|string|nullable',
        ]);

        $token = $validated['device_token'] ?? $validated['token'];

        $this->notificationService->removeDeviceToken($request->user(), $token);

        return response()->json([
            'success' => true,
            'message' => 'تۆکنی ئامێر ناچالاک کرا',
        ]);
    }
}
