<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Delivery\StoreDeliveryTripRequest;
use App\Http\Requests\Api\V1\Delivery\DeliverOrderRequest;
use App\Services\DeliveryTripService;
use Illuminate\Http\JsonResponse;

class DeliveryTripController extends Controller
{
    protected DeliveryTripService $deliveryTripService;

    public function __construct(DeliveryTripService $deliveryTripService)
    {
        $this->deliveryTripService = $deliveryTripService;
    }

    // دروستکردنی گەشت
    public function store(StoreDeliveryTripRequest $request): JsonResponse
    {
        $trip = $this->deliveryTripService->createTrip($request->validated(), $request->user());

        return response()->json([
            'message' => 'گەشتەکە بەسەرکەوتوویی دروستکرا و پسوڵەکان دران بە شۆفێر',
            'data'    => $trip->load('orders.order.customer')
        ], 201);
    }

    // کاتی گەیاندنی پسوڵەیەک لەلایەن شۆفێرەوە
    public function deliverOrder(DeliverOrderRequest $request, $tripOrderId): JsonResponse
    {
        $tripOrder = $this->deliveryTripService->deliverOrder($tripOrderId, $request->validated(), $request->user());

        return response()->json([
            'message' => 'پسوڵەکە گەیندرا و زانیارییەکان تۆمارکران',
            'data'    => $tripOrder
        ], 200);
    }
}
