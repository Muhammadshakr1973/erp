<?php

namespace App\Services;

use App\Models\Customer;
use App\Models\CustomerPayment;
use App\Models\DeliveryTrip;
use App\Models\DeviceToken;
use App\Models\Notification;
use App\Models\Product;
use App\Models\SalesmanCommission;
use App\Models\SalesOrder;
use App\Models\User;
use App\Models\WarehouseStock;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class NotificationService
{
    protected PushNotificationService $pushService;

    public function __construct(PushNotificationService $pushService)
    {
        $this->pushService = $pushService;
    }

    /**
     * Create in-app notification and trigger push notification
     */
    public function createNotification(
        int $userId,
        string $type,
        string $title,
        string $body,
        array $data = []
    ): Notification {
        $notification = Notification::create([
            'user_id' => $userId,
            'type'    => $type,
            'title'   => $title,
            'body'    => $body,
            'data'    => $data,
            'is_read' => false,
        ]);

        // Trigger push notification to user's registered devices
        $this->pushService->sendToUsers($userId, $title, $body, array_merge($data, [
            'notification_id' => $notification->id,
            'type' => $type,
        ]));

        return $notification;
    }

    /**
     * Notify a single user
     */
    public function notifyUser(
        User|int $user,
        string $type,
        string $title,
        string $body,
        array $data = []
    ): Notification {
        $userId = $user instanceof User ? $user->id : $user;
        return $this->createNotification($userId, $type, $title, $body, $data);
    }

    /**
     * Notify all active users with specific role(s)
     */
    public function notifyRole(
        string|array $roles,
        string $type,
        string $title,
        string $body,
        array $data = []
    ): array {
        $roles = is_array($roles) ? $roles : [$roles];
        
        $users = User::whereHas('role', fn($q) => $q->whereIn('name', $roles))
            ->where('is_active', true)
            ->get();

        $notifications = [];
        $userIds = [];

        foreach ($users as $user) {
            $notification = Notification::create([
                'user_id' => $user->id,
                'type'    => $type,
                'title'   => $title,
                'body'    => $body,
                'data'    => $data,
                'is_read' => false,
            ]);
            $notifications[] = $notification;
            $userIds[] = $user->id;
        }

        if (!empty($userIds)) {
            $this->pushService->sendToUsers($userIds, $title, $body, array_merge($data, ['type' => $type]));
        }

        return $notifications;
    }

    /**
     * Notify Admin and Owner users
     */
    public function notifyAdmins(string $type, string $title, string $body, array $data = []): array
    {
        return $this->notifyRole(['admin', 'owner'], $type, $title, $body, $data);
    }

    // =========================================================================
    // BUSINESS DOMAIN NOTIFICATIONS (NOT-001 to NOT-012)
    // =========================================================================

    /**
     * NOT-001: New Sales Order created -> notify Warehouse staff & Admins
     */
    public function notifyNewOrderCreated(SalesOrder $order, $actor = null): void
    {
        $customerName = $order->customer?->name ?? 'کڕیار';
        $title = 'پسوڵەی فرۆشتنی نوێ دروستکرا';
        $body = "پسوڵەی نوێ #{$order->order_number} بۆ کڕیار '{$customerName}' دروستکرا بە بڕی " . number_format($order->total_amount, 0) . " د.ع";

        $data = [
            'order_id' => $order->id,
            'order_number' => $order->order_number,
            'customer_id' => $order->customer_id,
            'action' => 'open_order',
        ];

        // Notify Warehouse & Admins
        $this->notifyRole(['warehouse', 'admin', 'owner'], Notification::TYPE_ORDER, $title, $body, $data);
    }

    /**
     * NOT-002: Order packed & Ready for delivery -> notify Drivers & Admins
     */
    public function notifyOrderReadyForDelivery(SalesOrder $order, $actor = null): void
    {
        $customerName = $order->customer?->name ?? 'کڕیار';
        $title = 'پسوڵە ئامادەیە بۆ گەیاندن';
        $body = "پسوڵەی #{$order->order_number} بۆ کڕیار '{$customerName}' پاکەت کرا و ئامادەی بارکردن و گەیاندنە.";

        $data = [
            'order_id' => $order->id,
            'order_number' => $order->order_number,
            'customer_id' => $order->customer_id,
            'action' => 'open_order',
        ];

        $this->notifyRole(['driver', 'admin', 'owner'], Notification::TYPE_ORDER, $title, $body, $data);
    }

    /**
     * NOT-003: Order Delivered -> notify Salesman, Admins, Owner
     */
    public function notifyOrderDelivered(SalesOrder $order, $actor = null): void
    {
        $customerName = $order->customer?->name ?? 'کڕیار';
        $title = 'پسوڵە بە سەرکەوتوویی گەیندرا';
        $body = "پسوڵەی #{$order->order_number} بۆ کڕیار '{$customerName}' گەیندرا.";

        $data = [
            'order_id' => $order->id,
            'order_number' => $order->order_number,
            'customer_id' => $order->customer_id,
            'action' => 'open_order',
        ];

        // Notify salesman who made the order
        if ($order->salesman_id) {
            $this->notifyUser($order->salesman_id, Notification::TYPE_ORDER, $title, $body, $data);
        }

        // Also notify admins/owner
        $this->notifyAdmins(Notification::TYPE_ORDER, $title, $body, $data);
    }

    /**
     * NOT-004: Payment received -> notify Admins, Owner
     */
    public function notifyPaymentReceived(CustomerPayment $payment, $actor = null): void
    {
        $customerName = $payment->customer?->name ?? 'کڕیار';
        $amountStr = number_format($payment->amount, 0) . ' د.ع';
        $title = 'پارەدانی کڕیار وەرگیرا';
        $body = "بڕی {$amountStr} لەلایەن کڕیار '{$customerName}' وەرگیرا بە پسوڵەی #{$payment->payment_number}.";

        $data = [
            'payment_id' => $payment->id,
            'payment_number' => $payment->payment_number,
            'customer_id' => $payment->customer_id,
            'amount' => $payment->amount,
            'action' => 'open_payment',
        ];

        $this->notifyAdmins(Notification::TYPE_PAYMENT, $title, $body, $data);
    }

    /**
     * NOT-005: Customer high debt threshold reached
     */
    public function notifyCustomerDebtLimitReached(Customer $customer, $actor = null): void
    {
        $balanceStr = number_format($customer->current_balance, 0) . ' د.ع';
        $title = 'ئاگاداری بەرزی قەرزی کڕیار';
        $body = "قەرزی کڕیار '{$customer->name}' گەیشتە {$balanceStr} کە لە سەرووی ئاستی دیاریکراوە.";

        $data = [
            'customer_id' => $customer->id,
            'customer_name' => $customer->name,
            'balance' => $customer->current_balance,
            'action' => 'open_customer',
        ];

        $this->notifyAdmins(Notification::TYPE_PAYMENT, $title, $body, $data);
    }

    /**
     * NOT-006: Stock low (< min_stock_level) -> notify Warehouse & Admins
     */
    public function notifyLowStock(WarehouseStock $stock, Product $product): void
    {
        $title = 'ئاگاداری کەمبوونەوەی کاڵا لە کۆگا';
        $body = "بڕی ماوەی کاڵای '{$product->name}' لە کۆگا تەنها {$stock->quantity} دانەیە (کەمترین ئاست: {$product->min_stock_level}).";

        $data = [
            'product_id' => $product->id,
            'warehouse_id' => $stock->warehouse_id,
            'quantity' => $stock->quantity,
            'action' => 'open_stock',
        ];

        $this->notifyRole(['warehouse', 'admin', 'owner'], Notification::TYPE_STOCK, $title, $body, $data);
    }

    /**
     * NOT-007: Stock out (0 quantity) -> notify Warehouse & Admins
     */
    public function notifyOutOfStock(WarehouseStock $stock, Product $product): void
    {
        $title = 'تەواوبوونی ستۆکی کاڵا';
        $body = "ستۆکی کاڵای '{$product->name}' لە کۆگا تەواو بوو (0 دانە ماوە).";

        $data = [
            'product_id' => $product->id,
            'warehouse_id' => $stock->warehouse_id,
            'quantity' => 0,
            'action' => 'open_stock',
        ];

        $this->notifyRole(['warehouse', 'admin', 'owner'], Notification::TYPE_STOCK, $title, $body, $data);
    }

    /**
     * NOT-009: Commission calculated -> notify Salesman & Owner
     */
    public function notifyCommissionCalculated(SalesmanCommission $commission): void
    {
        $salesman = $commission->salesman;
        $amountStr = number_format($commission->commission_amount, 0) . ' د.ع';
        $title = 'کۆمسیۆنی مانگانە هەژمارکرا';
        $body = "کۆمسیۆنی مانگی {$commission->period_month}/{$commission->period_year} هەژمارکرا بە بڕی {$amountStr}.";

        $data = [
            'commission_id' => $commission->id,
            'period' => "{$commission->period_year}-{$commission->period_month}",
            'amount' => $commission->commission_amount,
            'action' => 'open_commission',
        ];

        if ($salesman) {
            $this->notifyUser($salesman->id, Notification::TYPE_COMMISSION, $title, $body, $data);
        }
        $this->notifyRole(['owner', 'admin'], Notification::TYPE_COMMISSION, $title, "کۆمسیۆنی {$salesman?->name}: {$amountStr}", $data);
    }

    /**
     * NOT-010: Commission paid -> notify Salesman
     */
    public function notifyCommissionPaid(SalesmanCommission $commission): void
    {
        $amountStr = number_format($commission->commission_amount, 0) . ' د.ع';
        $title = 'کۆمسیۆنی مانگانەت خەرجکرا';
        $body = "کۆمسیۆنی بڕی {$amountStr} بە سەرکەوتوویی درا و ڕادەستت کرا.";

        $data = [
            'commission_id' => $commission->id,
            'period' => "{$commission->period_year}-{$commission->period_month}",
            'amount' => $commission->commission_amount,
            'action' => 'open_commission',
        ];

        if ($commission->salesman_id) {
            $this->notifyUser($commission->salesman_id, Notification::TYPE_COMMISSION, $title, $body, $data);
        }
    }

    /**
     * NOT-012: Delivery trip assigned to driver
     */
    public function notifyDeliveryTripAssigned(DeliveryTrip $trip): void
    {
        $title = 'گەشتی گەیاندنی نوێت بۆ دانرا';
        $body = "گەشتی ژمارە #{$trip->trip_number} بە {$trip->total_orders} پسوڵەوە بۆ بەڕێزت دیاریکرا.";

        $data = [
            'trip_id' => $trip->id,
            'trip_number' => $trip->trip_number,
            'total_orders' => $trip->total_orders,
            'action' => 'open_trip',
        ];

        if ($trip->driver_id) {
            $this->notifyUser($trip->driver_id, Notification::TYPE_ORDER, $title, $body, $data);
        }
    }

    /**
     * Notify about a failed delivery -> notify Salesman, Admins, Owner
     */
    public function notifyOrderDeliveryFailed(SalesOrder $order, string $reason, $actor = null): void
    {
        $customerName = $order->customer?->name ?? 'کڕیار';
        $title = 'کێشە لە گەیاندنی پسوڵە';
        $body = "گەیاندنی پسوڵەی #{$order->order_number} بۆ کڕیار '{$customerName}' سەرکەوتوو نەبوو بەهۆی: {$reason}";

        $data = [
            'order_id' => $order->id,
            'order_number' => $order->order_number,
            'customer_id' => $order->customer_id,
            'failed_reason' => $reason,
            'action' => 'open_order',
        ];

        if ($order->salesman_id) {
            $this->notifyUser($order->salesman_id, Notification::TYPE_ORDER, $title, $body, $data);
        }
        $this->notifyAdmins(Notification::TYPE_ORDER, $title, $body, $data);
    }

    /**
     * Notify about returned order -> notify Salesman, Admins, Owner
     */
    public function notifyOrderReturned(SalesOrder $order, int $amount, $actor = null): void
    {
        $customerName = $order->customer?->name ?? 'کڕیار';
        $title = 'کاڵای پسوڵە گەڕێندرایەوە';
        $body = "کاڵاکانی پسوڵەی #{$order->order_number} بۆ کڕیار '{$customerName}' بەشێکی یان تەواوی گەڕێندرایەوە بە بڕی " . number_format($amount, 0) . " د.ع";

        $data = [
            'order_id' => $order->id,
            'order_number' => $order->order_number,
            'customer_id' => $order->customer_id,
            'return_amount' => $amount,
            'action' => 'open_order',
        ];

        if ($order->salesman_id) {
            $this->notifyUser($order->salesman_id, Notification::TYPE_ORDER, $title, $body, $data);
        }
        $this->notifyAdmins(Notification::TYPE_ORDER, $title, $body, $data);
    }

    // =========================================================================
    // IN-APP NOTIFICATION QUERY & MANAGEMENT
    // =========================================================================

    /**
     * Get paginated notifications for the authenticated user
     */
    public function getNotificationsForUser(User $user, array $filters = [], int $perPage = 20): LengthAwarePaginator
    {
        $query = Notification::where('user_id', $user->id)
            ->latest('id');

        if (!empty($filters['type'])) {
            $query->where('type', $filters['type']);
        }

        if (isset($filters['is_read'])) {
            $isRead = filter_var($filters['is_read'], FILTER_VALIDATE_BOOLEAN);
            $query->where('is_read', $isRead);
        }

        return $query->paginate($perPage);
    }

    /**
     * Get unread count for user
     */
    public function getUnreadCount(User $user): int
    {
        return Notification::where('user_id', $user->id)
            ->where('is_read', false)
            ->count();
    }

    /**
     * Mark single notification as read
     */
    public function markAsRead(int $notificationId, User $user): Notification
    {
        $notification = Notification::where('user_id', $user->id)
            ->findOrFail($notificationId);

        if (!$notification->is_read) {
            $notification->update([
                'is_read' => true,
                'read_at' => now(),
            ]);
        }

        return $notification;
    }

    /**
     * Mark all notifications as read for user
     */
    public function markAllAsRead(User $user): int
    {
        return Notification::where('user_id', $user->id)
            ->where('is_read', false)
            ->update([
                'is_read' => true,
                'read_at' => now(),
            ]);
    }

    /**
     * Register or update device token for FCM push notifications
     */
    public function registerDeviceToken(
        User $user,
        string $token,
        string $deviceType = 'android',
        ?string $deviceName = null
    ): DeviceToken {
        return DeviceToken::updateOrCreate(
            ['token' => $token],
            [
                'user_id' => $user->id,
                'device_token' => $token,
                'device_type' => $deviceType,
                'device_name' => $deviceName,
                'is_active' => true,
                'last_used_at' => now(),
            ]
        );
    }

    /**
     * Remove or deactivate a device token on logout
     */
    public function removeDeviceToken(User $user, string $token): bool
    {
        return (bool) DeviceToken::where('user_id', $user->id)
            ->where(function ($q) use ($token) {
                $q->where('token', $token)
                  ->orWhere('device_token', $token);
            })
            ->update(['is_active' => false]);
    }
}
