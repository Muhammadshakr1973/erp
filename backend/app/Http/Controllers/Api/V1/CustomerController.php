<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Customer\StoreCustomerRequest;
use App\Http\Requests\Api\V1\Customer\UpdateCustomerRequest;
use App\Models\Customer;
use App\Services\CustomerService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class CustomerController extends Controller
{
    protected CustomerService $customerService;

    public function __construct(CustomerService $customerService)
    {
        $this->customerService = $customerService;
    }

    public function index(Request $request): JsonResponse
    {
        $customers = $this->customerService->getAllCustomers($request->all(), $request->user());
        
        return response()->json([
            'data' => $customers
        ], 200);
    }

    public function store(StoreCustomerRequest $request): JsonResponse
    {
        $customer = $this->customerService->createCustomer($request->validated(), $request->user()->id);
        
        return response()->json([
            'message' => 'کڕیار بەسەرکەوتوویی زیادکرا',
            'data' => $customer
        ], 201);
    }

    public function show(Request $request, Customer $customer): JsonResponse
    {
        if (!$request->user()->hasCustomerAccess($customer)) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ بینینی زانیاری ئەم کڕیارە.',
                'error' => 'Forbidden.'
            ], 403);
        }

        return response()->json([
            'data' => $customer->load('route')
        ], 200);
    }

    public function update(UpdateCustomerRequest $request, Customer $customer): JsonResponse
    {
        if (!$request->user()->hasCustomerAccess($customer)) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ نوێکردنەوەی زانیاری ئەم کڕیارە.',
                'error' => 'Forbidden.'
            ], 403);
        }

        $customer = $this->customerService->updateCustomer($customer, $request->validated());
        
        return response()->json([
            'message' => 'زانیاری کڕیار بەسەرکەوتوویی نوێکرایەوە',
            'data' => $customer
        ], 200);
    }

    public function destroy(Request $request, Customer $customer): JsonResponse
    {
        if (!$request->user()->hasCustomerAccess($customer)) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ سڕینەوەی ئەم کڕیارە.',
                'error' => 'Forbidden.'
            ], 403);
        }

        $this->customerService->deleteCustomer($customer);
        
        return response()->json([
            'message' => 'کڕیار بەسەرکەوتوویی سڕایەوە'
        ], 200);
    }

    public function reconcile(Request $request, Customer $customer): JsonResponse
    {
        if (!$request->user()->hasCustomerAccess($customer)) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ ئەنجامدانی کردار لێرەدا.',
                'error' => 'Forbidden.'
            ], 403);
        }

        if ($request->boolean('fix') && $request->user()->isAdmin()) {
            \Illuminate\Support\Facades\DB::transaction(function () use ($customer) {
                $customer->lockForUpdate();
                $reconciliation = $customer->reconcileBalance();
                if (!$reconciliation['is_consistent']) {
                    $customer->update(['current_balance' => $reconciliation['recalculated_balance']]);
                }
            });
            $customer->refresh();
        }

        $reconciliation = $customer->reconcileBalance();
        
        return response()->json([
            'message' => 'کڕیار لێکترازانی دارایی / Reconciliation report',
            'data' => $reconciliation
        ], 200);
    }
}