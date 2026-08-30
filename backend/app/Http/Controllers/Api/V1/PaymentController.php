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
        $user = $request->user();
        $validated = $request->validated();

        if ($user && $user->isSalesman() && !$user->hasCustomerAccess($validated['customer_id'])) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ وەرگرتنی پارەی ئەم کڕیارە.',
                'error' => 'Forbidden.'
            ], 403);
        }

        $payment = $this->paymentService->collectPayment($validated, $user);

        return response()->json([
            'message' => 'پارەدانەکە بەسەرکەوتوویی تۆمارکرا',
            'data' => $payment
        ], 201);
    }
}
