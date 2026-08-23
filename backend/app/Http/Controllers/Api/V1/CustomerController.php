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

    public function show(Customer $customer): JsonResponse
    {
        return response()->json([
            'data' => $customer->load('route')
        ], 200);
    }

    public function update(UpdateCustomerRequest $request, Customer $customer): JsonResponse
    {
        $customer = $this->customerService->updateCustomer($customer, $request->validated());
        
        return response()->json([
            'message' => 'زانیاری کڕیار بەسەرکەوتوویی نوێکرایەوە',
            'data' => $customer
        ], 200);
    }

    public function destroy(Customer $customer): JsonResponse
    {
        $this->customerService->deleteCustomer($customer);
        
        return response()->json([
            'message' => 'کڕیار بەسەرکەوتوویی سڕایەوە'
        ], 200);
    }
}