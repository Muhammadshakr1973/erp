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
        $customer->load('route');
        
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

    public function ledger(Request $request, Customer $customer): JsonResponse
    {
        if (!$request->user()->hasCustomerAccess($customer)) {
            return response()->json([
                'message' => 'تۆ ڕێگەپێدراو نیت بۆ بینینی زانیاری ئەم کڕیارە.',
                'error' => 'Forbidden.'
            ], 403);
        }

        $query = $customer->ledger()
            ->with(['customer:id,name', 'creator:id,name'])
            ->orderByDesc('created_at')
            ->orderByDesc('id');

        if ($request->filled('entry_type') && $request->entry_type !== 'ALL') {
            $query->where('entry_type', $request->entry_type);
        }

        if ($request->filled('start_date')) {
            $query->whereDate('created_at', '>=', $request->start_date);
        }

        if ($request->filled('end_date')) {
            $query->whereDate('created_at', '<=', $request->end_date);
        }

        return response()->json([
            'message' => 'مێژووی قەرز و پارەدانی کڕیار',
            'data' => $query->get()
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

    public function proxyImage(Request $request)
    {
        $url = $request->query('url');
        if (!$url || !filter_var($url, FILTER_VALIDATE_URL)) {
            return response()->json(['error' => 'Invalid URL'], 400);
        }

        $scheme = parse_url($url, PHP_URL_SCHEME);
        if (!in_array(strtolower($scheme), ['http', 'https'])) {
            return response()->json(['error' => 'Invalid scheme'], 400);
        }

        try {
            $ch = curl_init();
            curl_setopt($ch, CURLOPT_URL, $url);
            curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
            curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
            curl_setopt($ch, CURLOPT_MAXREDIRS, 5);
            curl_setopt($ch, CURLOPT_TIMEOUT, 10);
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
            curl_setopt($ch, CURLOPT_USERAGENT, 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');

            $content = curl_exec($ch);
            $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
            $contentType = curl_getinfo($ch, CURLINFO_CONTENT_TYPE);
            curl_close($ch);

            if ($httpCode >= 200 && $httpCode < 300 && $content) {
                return response($content, 200, [
                    'Content-Type' => $contentType ?: 'image/jpeg',
                    'Cache-Control' => 'public, max-age=86400',
                    'Access-Control-Allow-Origin' => '*',
                ]);
            }

            return response()->json(['error' => 'Failed to fetch image', 'status' => $httpCode], 404);
        } catch (\Exception $e) {
            return response()->json(['error' => $e->getMessage()], 500);
        }
    }
}