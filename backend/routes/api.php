<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\CustomerController;
use App\Http\Controllers\Api\V1\SalesOrderController;
use App\Http\Controllers\Api\V1\PaymentController;
use App\Http\Controllers\Api\V1\StockTransferController;
use App\Http\Controllers\Api\V1\DeliveryTripController;
use App\Http\Controllers\Api\V1\CommissionController;
use App\Http\Controllers\Api\V1\PurchaseOrderController;
use App\Http\Controllers\Api\V1\ReportController;
use App\Http\Controllers\Api\V1\ProductController;
use App\Http\Controllers\Api\V1\CategoryController;
use App\Http\Controllers\Api\V1\SupplierController;

Route::prefix('v1')->group(function () {

    // ئەوانەی پێویستیان بە تۆکن نییە (Public)
    Route::post('/auth/login', [AuthController::class, 'login']);

    // ئەوانەی پێویستیان بە تۆکنە (Protected)
    Route::middleware('auth:sanctum')->group(function () {

        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::get('/auth/me', [AuthController::class, 'me']);
        Route::apiResource('products', ProductController::class);
        Route::get('/categories', [CategoryController::class, 'index']);
        Route::post('/categories', [CategoryController::class, 'store']);
        Route::get('/suppliers', [SupplierController::class, 'index']);
        Route::post('/suppliers', [SupplierController::class, 'store']);
        Route::put('/suppliers/{id}', [SupplierController::class, 'update']);
        Route::delete('/suppliers/{id}', [SupplierController::class, 'destroy']);
        Route::post('/suppliers/{id}/pay', [SupplierController::class, 'pay']);
        Route::apiResource('customers', CustomerController::class);
        Route::get('/orders', [SalesOrderController::class, 'index']);
        Route::post('/orders', [SalesOrderController::class, 'store']);
        Route::post('/payments', [PaymentController::class, 'store']);
        Route::post('/stock-transfers', [StockTransferController::class, 'store']);
        Route::post('/stock-transfers/{id}/complete', [StockTransferController::class, 'complete']);
        Route::post('/delivery-trips', [DeliveryTripController::class, 'store']);
        Route::post('/delivery-trips/orders/{tripOrderId}/deliver', [DeliveryTripController::class, 'deliverOrder']);
        Route::get('/commissions', [CommissionController::class, 'index']);
        Route::post('/commissions/calculate', [CommissionController::class, 'calculate']);
        Route::post('/purchase-orders', [PurchaseOrderController::class, 'store']);
        Route::post('/purchase-orders/{id}/receive', [PurchaseOrderController::class, 'receive']);
        Route::get('/reports/dashboard', [ReportController::class, 'dashboard']);
    });
});
