<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Delivery\StoreDeliveryTripRequest;
use App\Http\Requests\Api\V1\Delivery\DeliverOrderRequest;
use App\Http\Requests\Api\V1\Delivery\FailOrderRequest;
use App\Services\DeliveryTripService;
use Illuminate\Http\JsonResponse;

class DeliveryTripController extends Controller
{
    protected DeliveryTripService $deliveryTripService;

    public function __construct(DeliveryTripService $deliveryTripService)
    {
        $this->deliveryTripService = $deliveryTripService;
    }

    // لیستی گەشتەکان
    public function index(\Illuminate\Http\Request $request): JsonResponse
    {
        $user = $request->user();
        $query = \App\Models\DeliveryTrip::with(['driver', 'orders.order.customer.route'])->orderBy('id', 'desc');

        if ($user && $user->isDriver()) {
            $query->where('driver_id', $user->id);
        }

        $trips = $query->get();

        return response()->json([
            'message' => 'لیستی گەشتەکانی گەیاندن',
            'data'    => $trips
        ], 200);
    }

    // لیستی شۆفێرە چالاکەکان بۆ ناردنی گەشت
    public function drivers(): JsonResponse
    {
        $drivers = \App\Models\User::active()
            ->drivers()
            ->select('id', 'name', 'phone')
            ->get();

        return response()->json([
            'message' => 'لیستی شۆفێرە چالاکەکان',
            'data'    => $drivers
        ], 200);
    }

    // پیشاندانی وردەکاری گەشت
    public function show(\Illuminate\Http\Request $request, $id): JsonResponse
    {
        $user = $request->user();
        $trip = \App\Models\DeliveryTrip::with(['driver', 'orders.order.customer.route', 'orders.order.items.product'])->findOrFail($id);

        if ($user && $user->isDriver() && (int)$trip->driver_id !== (int)$user->id) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ بینینی زانیاری ئەم گەشتە.',
                'error'   => 'Forbidden.'
            ], 403);
        }

        return response()->json([
            'message' => 'وردەکاری گەشت',
            'data'    => $trip
        ], 200);
    }

    // دروستکردنی گەشت (تەنها ئادمین و کارمەندی کۆگا)
    public function store(StoreDeliveryTripRequest $request): JsonResponse
    {
        $user = $request->user();
        $validated = $request->validated();

        if ($user->isDriver()) {
            return response()->json([
                'message' => 'شۆفێر ڕێگەپێدراو نییە بۆ دروستکردنی گەشت. تەنها کارمەندی کۆگا و ئادمین دەتوانن گەشت دروست بکەن.',
                'error'   => 'Forbidden.'
            ], 403);
        }

        $trip = $this->deliveryTripService->createTrip($validated, $user);

        return response()->json([
            'message' => 'گەشتەکە بەسەرکەوتوویی دروستکرا و پسوڵەکان دران بە شۆفێر',
            'data'    => $trip->load(['driver', 'orders.order.customer.route'])
        ], 201);
    }

    // کاتی گەیاندنی پسوڵەیەک لەلایەن شۆفێرەوە
    public function deliverOrder(DeliverOrderRequest $request, $tripOrderId): JsonResponse
    {
        $user = $request->user();
        $tripOrder = \App\Models\DeliveryTripOrder::with('trip')->findOrFail($tripOrderId);

        // IDOR/assignment restriction for drivers
        if ($user->role?->name === 'driver' && $tripOrder->trip->driver_id !== $user->id) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ ئەنجامدانی ئەم کردارە لەم گەشتەدا چونکە گەشتەکە بۆ تۆ نییە.',
                'error' => 'Forbidden.'
            ], 403);
        }

        $tripOrder = $this->deliveryTripService->deliverOrder($tripOrderId, $request->validated(), $user);

        return response()->json([
            'message' => 'پسوڵەکە گەیندرا و زانیارییەکان تۆمارکران',
            'data'    => $tripOrder
        ], 200);
    }

    // کاتی شکست هێنانی گەیاندنی پسوڵەیەک لەلایەن شۆفێرەوە
    public function failOrder(FailOrderRequest $request, $tripOrderId): JsonResponse
    {
        $user = $request->user();
        $tripOrder = \App\Models\DeliveryTripOrder::with('trip')->findOrFail($tripOrderId);

        // IDOR/assignment restriction for drivers
        if ($user->role?->name === 'driver' && $tripOrder->trip->driver_id !== $user->id) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ ئەنجامدانی ئەم کردارە لەم گەشتەدا چونکە گەشتەکە بۆ تۆ نییە.',
                'error' => 'Forbidden.'
            ], 403);
        }

        $tripOrder = $this->deliveryTripService->failOrder($tripOrderId, $request->validated(), $user);

        return response()->json([
            'message' => 'شکستی گەیاندنی پسوڵەکە تۆمارکرا و دۆخی گۆڕدرا بۆ ئامادە',
            'data'    => $tripOrder
        ], 200);
    }

    // وەرگرتنی کورتەی پارەی سەرجەم شۆفێرەکان
    public function getDriversCashSummary(\Illuminate\Http\Request $request): JsonResponse
    {
        $user = $request->user();

        if ($user && $user->isDriver()) {
            $totalCollected = \DB::table('delivery_trip_orders')
                ->join('delivery_trips', 'delivery_trip_orders.delivery_trip_id', '=', 'delivery_trips.id')
                ->where('delivery_trips.driver_id', $user->id)
                ->where('delivery_trip_orders.status', 'DELIVERED')
                ->sum('delivery_trip_orders.received_amount');

            $totalPaid = \DB::table('driver_collections')
                ->where('driver_id', $user->id)
                ->sum('amount');

            $remainingAmount = $totalCollected - $totalPaid;

            return response()->json([
                'message' => 'کورتەی حیسابی پارەی وەرگیراوی شۆفێر',
                'data' => [
                    [
                        'driver' => [
                            'id' => $user->id,
                            'name' => $user->name,
                            'phone' => $user->phone,
                        ],
                        'total_collected' => (int)$totalCollected,
                        'total_paid' => (int)$totalPaid,
                        'remaining_amount' => (int)$remainingAmount,
                    ]
                ]
            ], 200);
        }

        if (!$user || (!$user->hasPermission('users.manage') && !$user->hasPermission('delivery.view'))) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ ئەنجامدانی ئەم کردارە.',
                'error' => 'Forbidden.'
            ], 403);
        }

        $drivers = \App\Models\User::active()
            ->drivers()
            ->select('id', 'name', 'phone')
            ->get();

        $data = [];
        foreach ($drivers as $driver) {
            $totalCollected = \DB::table('delivery_trip_orders')
                ->join('delivery_trips', 'delivery_trip_orders.delivery_trip_id', '=', 'delivery_trips.id')
                ->where('delivery_trips.driver_id', $driver->id)
                ->where('delivery_trip_orders.status', 'DELIVERED')
                ->sum('delivery_trip_orders.received_amount');

            $totalPaid = \DB::table('driver_collections')
                ->where('driver_id', $driver->id)
                ->sum('amount');

            $remainingAmount = $totalCollected - $totalPaid;

            $data[] = [
                'driver' => $driver,
                'total_collected' => (int)$totalCollected,
                'total_paid' => (int)$totalPaid,
                'remaining_amount' => (int)$remainingAmount,
            ];
        }

        return response()->json([
            'message' => 'کورتەی حیسابی پارەی وەرگیراوی شۆفێرەکان',
            'data' => $data
        ], 200);
    }

    // لیستی پارە وەرگرتنەکان لە شۆفێر
    public function getDriverCollections(\Illuminate\Http\Request $request): JsonResponse
    {
        $collections = \App\Models\DriverCollection::with(['driver:id,name', 'collector:id,name'])
            ->orderBy('id', 'desc')
            ->get();

        return response()->json([
            'message' => 'لیستی پارەی وەرگیراو لە شۆفێرەکان',
            'data' => $collections
        ], 200);
    }

    // تۆمارکردنی پارەی وەرگیراو لە شۆفێر
    public function storeDriverCollection(\Illuminate\Http\Request $request): JsonResponse
    {
        $validated = $request->validate([
            'driver_id' => 'required|exists:users,id',
            'amount' => 'required|integer|min:1',
            'collected_at' => 'required|date',
            'notes' => 'nullable|string',
        ]);

        $user = $request->user();

        $collection = \DB::transaction(function () use ($validated, $user) {
            $collection = \App\Models\DriverCollection::create([
                'driver_id' => $validated['driver_id'],
                'amount' => $validated['amount'],
                'collected_at' => $validated['collected_at'],
                'collected_by' => $user->id,
                'notes' => $validated['notes'] ?? null,
            ]);

            app(\App\Services\AuditService::class)->log([
                'action'      => 'CREATE',
                'entity_type' => 'DriverCollection',
                'entity_id'   => $collection->id,
                'table_name'  => 'driver_collections',
                'old_values'  => null,
                'new_values'  => [
                    'driver_id' => $collection->driver_id,
                    'amount' => $collection->amount,
                    'collected_at' => $collection->collected_at,
                ],
                'description' => "بڕی {$collection->amount} دینار وەرگیرا لە شۆفێر: " . ($collection->driver->name ?? $collection->driver_id),
                'user'        => $user,
            ]);

            return $collection;
        });

        // Calculate driver's remaining cash balance
        $totalCollected = \DB::table('delivery_trip_orders')
            ->join('delivery_trips', 'delivery_trip_orders.delivery_trip_id', '=', 'delivery_trips.id')
            ->where('delivery_trips.driver_id', $collection->driver_id)
            ->where('delivery_trip_orders.status', 'DELIVERED')
            ->sum('delivery_trip_orders.received_amount');

        $totalPaid = \DB::table('driver_collections')
            ->where('driver_id', $collection->driver_id)
            ->sum('amount');

        $remainingAmount = (int) ($totalCollected - $totalPaid);

        // Send WhatsApp notification to driver
        try {
            app(\App\Services\WhatsAppService::class)->sendDriverCollectionNotification(
                $collection,
                $remainingAmount,
                $user
            );
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::error("Failed sending driver collection WhatsApp notification: " . $e->getMessage());
        }

        event(new \App\Events\DeliveryTripUpdated(null, 'driver_collection'));

        return response()->json([
            'message' => 'پارەکە بە سەرکەوتوویی لە شۆفێرەکە وەرگیرا و تۆمارکرا',
            'data' => $collection->load(['driver:id,name', 'collector:id,name'])
        ], 201);
    }
}
