<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Payment\StorePaymentRequest;
use App\Services\PaymentService;
use Illuminate\Http\JsonResponse;

class PaymentController extends Controller
{
    protected PaymentService $paymentService;

    public function __construct(PaymentService $paymentService)
    {
        $this->paymentService = $paymentService;
    }

    public function store(StorePaymentRequest $request): JsonResponse
    {
        $payment = $this->paymentService->collectPayment($request->validated(), $request->user());

        return response()->json([
            'message' => 'پارەدانەکە بەسەرکەوتوویی تۆمارکرا',
            'data' => $payment
        ], 201);
    }
}
