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
        $query = \App\Models\DeliveryTrip::with(['driver', 'orders.order.customer'])->orderBy('id', 'desc');

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
        $trip = \App\Models\DeliveryTrip::with(['driver', 'orders.order.customer', 'orders.order.items.product'])->findOrFail($id);

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

    // دروستکردنی گەشت
    public function store(StoreDeliveryTripRequest $request): JsonResponse
    {
        $trip = $this->deliveryTripService->createTrip($request->validated(), $request->user());

        return response()->json([
            'message' => 'گەشتەکە بەسەرکەوتوویی دروستکرا و پسوڵەکان دران بە شۆفێر',
            'data'    => $trip->load(['driver', 'orders.order.customer'])
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
}
