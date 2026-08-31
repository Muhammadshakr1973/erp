<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\SalesReturn\StoreSalesReturnRequest;
use App\Services\SalesReturnService;
use App\Services\NotificationService;
use App\Services\WhatsAppService;
use App\Models\SalesReturn;
use App\Models\Customer;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SalesReturnController extends Controller
{
    protected SalesReturnService $salesReturnService;
    protected NotificationService $notificationService;
    protected WhatsAppService $whatsAppService;

    public function __construct(
        SalesReturnService $salesReturnService,
        NotificationService $notificationService,
        WhatsAppService $whatsAppService
    ) {
        $this->salesReturnService = $salesReturnService;
        $this->notificationService = $notificationService;
        $this->whatsAppService = $whatsAppService;
    }

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $query = SalesReturn::with(['customer', 'order'])->orderBy('id', 'desc');

        if ($user->role?->name === 'salesman') {
            $query->whereHas('order', function ($q) use ($user) {
                $q->where('salesman_id', $user->id);
            });
        }

        $returns = $query->get();

        return response()->json([
            'message' => 'لیستی کاڵا ڕاگەڕێندراوەکان',
            'data' => $returns
        ], 200);
    }

    public function show(Request $request, int $id): JsonResponse
    {
        $user = $request->user();
        $return = SalesReturn::with(['customer', 'order', 'items.product', 'items.orderItem'])->findOrFail($id);

        if ($user->role?->name === 'salesman' && $return->order->salesman_id !== $user->id) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ بینینی زانیاری ئەم گەڕانەوەیە.',
                'error' => 'Forbidden.'
            ], 403);
        }

        return response()->json([
            'message' => 'وردەکاری کاڵای ڕاگەڕێندراو',
            'data' => $return
        ], 200);
    }

    public function store(StoreSalesReturnRequest $request): JsonResponse
    {
        $user = $request->user();
        $orderId = $request->input('sales_order_id');
        $order = \App\Models\SalesOrder::findOrFail($orderId);

        // IDOR prevention: check if salesman is assigned to the customer or order
        if ($user->role?->name === 'salesman' && $order->salesman_id !== $user->id) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ ئەنجامدانی کردار لەسەر ئەم پسوڵەیە.',
                'error' => 'Forbidden.'
            ], 403);
        }

        // Get previous customer balance before transaction
        $customer = Customer::findOrFail($order->customer_id);
        $previousBalance = $customer->current_balance;

        // Create the return in a safe database transaction
        $salesReturn = $this->salesReturnService->createReturn($request->validated(), $user);

        // Reload customer for new balance
        $customer->refresh();
        $newBalance = $customer->current_balance;

        // Post-commit Notifications
        $this->notificationService->notifyOrderReturned($order, $salesReturn->total_return_amount, $user);

        // Send WhatsApp notification to customer about the return and their new balance
        $this->whatsAppService->sendReturnDebtNotification(
            $order,
            $previousBalance,
            $salesReturn->total_return_amount,
            $newBalance,
            $user
        );

        return response()->json([
            'message' => 'کاڵاکە بە سەرکەوتوویی گەڕێندرایەوە و باڵانسی کڕیار نوێکرایەوە',
            'data' => $salesReturn->load('items.product')
        ], 201);
    }
}
