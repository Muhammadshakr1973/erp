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
use App\Http\Controllers\Api\V1\PurchaseRequirementController;
use App\Http\Controllers\Api\V1\ReportController;
use App\Http\Controllers\Api\V1\ProductController;
use App\Http\Controllers\Api\V1\CategoryController;
use App\Http\Controllers\Api\V1\SupplierController;
use App\Http\Controllers\Api\V1\RouteController;
use App\Http\Controllers\Api\V1\UserController;
use App\Http\Controllers\Api\V1\WarehouseController;
use App\Http\Controllers\Api\V1\AuditLogController;
use App\Http\Controllers\Api\V1\NotificationController;
use App\Http\Controllers\Api\V1\SalesReturnController;

Route::prefix('v1')->group(function () {

    // ئەوانەی پێویستیان بە تۆکن نییە (Public)
    Route::post('/auth/login', [AuthController::class, 'login'])->middleware('throttle:5,1');

    // ئەوانەی پێویستیان بە تۆکنە (Protected)
    Route::middleware(['auth:sanctum', 'active', 'throttle:60,1'])->group(function () {

        Broadcast::routes();

        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::get('/auth/me', [AuthController::class, 'me']);
        Route::get('/broadcasting/config', [AuthController::class, 'broadcastingConfig']);
        
        // Products & Categories (Admins manage, anyone reads)
        Route::get('/products', [ProductController::class, 'index']);
        Route::get('/products/{product}', [ProductController::class, 'show']);
        Route::post('/products', [ProductController::class, 'store'])->middleware('permission:products.manage');
        Route::put('/products/{product}', [ProductController::class, 'update'])->middleware('permission:products.manage');
        Route::delete('/products/{product}', [ProductController::class, 'destroy'])->middleware('permission:products.manage');
        
        Route::get('/categories', [CategoryController::class, 'index']);
        Route::post('/categories', [CategoryController::class, 'store'])->middleware('permission:products.manage');
        Route::get('/categories/{category}', [CategoryController::class, 'show']);
        Route::put('/categories/{category}', [CategoryController::class, 'update'])->middleware('permission:products.manage');
        Route::delete('/categories/{category}', [CategoryController::class, 'destroy'])->middleware('permission:products.manage');
        
        // Routes & Salesmen Assign (Admins manage, anyone reads)
        Route::get('/salesmen', [RouteController::class, 'getSalesmen']);
        Route::get('/routes', [RouteController::class, 'index']);
        Route::get('/routes/{route}', [RouteController::class, 'show']);
        Route::post('/routes', [RouteController::class, 'store'])->middleware('permission:routes.manage');
        Route::put('/routes/{route}', [RouteController::class, 'update'])->middleware('permission:routes.manage');
        Route::delete('/routes/{route}', [RouteController::class, 'destroy'])->middleware('permission:routes.manage');
        Route::post('/routes/{route}/assign-salesman', [RouteController::class, 'assignSalesman'])->middleware('permission:routes.manage');
        Route::delete('/routes/{route}/remove-salesman/{salesmanId}', [RouteController::class, 'removeSalesman'])->middleware('permission:routes.manage');
        Route::get('/routes/{route}/customers', [RouteController::class, 'customers']);
        Route::post('/routes/{route}/reorder-customers', [RouteController::class, 'reorderCustomers'])->middleware('permission:routes.manage');
        Route::post('/routes/{route}/assign-customers', [RouteController::class, 'assignCustomers'])->middleware('permission:routes.manage');
        
        // Suppliers (Admins/Salesmen can view, Admins manage)
        Route::get('/suppliers', [SupplierController::class, 'index'])->middleware('permission:suppliers.view');
        Route::get('/suppliers/{id}', [SupplierController::class, 'show'])->middleware('permission:suppliers.view');
        Route::post('/suppliers', [SupplierController::class, 'store'])->middleware('permission:suppliers.manage');
        Route::put('/suppliers/{id}', [SupplierController::class, 'update'])->middleware('permission:suppliers.manage');
        Route::delete('/suppliers/{id}', [SupplierController::class, 'destroy'])->middleware('permission:suppliers.manage');
        Route::post('/suppliers/{id}/pay', [SupplierController::class, 'pay'])->middleware(['permission:suppliers.manage', 'idempotent']);
        Route::get('/suppliers/{id}/ledger', [SupplierController::class, 'ledger'])->middleware('permission:suppliers.manage');
        Route::get('/suppliers/{id}/reconcile', [SupplierController::class, 'reconcile'])->middleware('permission:users.manage');
        Route::post('/suppliers/{id}/reconcile', [SupplierController::class, 'reconcile'])->middleware('permission:users.manage');
        
        // Customers (Fine-grained: view vs manage)
        Route::get('/customers', [CustomerController::class, 'index'])->middleware('permission:customers.view');
        Route::get('/customers/{customer}', [CustomerController::class, 'show'])->middleware('permission:customers.view');
        Route::post('/customers', [CustomerController::class, 'store'])->middleware(['permission:customers.manage', 'idempotent']);
        Route::put('/customers/{customer}', [CustomerController::class, 'update'])->middleware(['permission:customers.manage', 'idempotent']);
        Route::delete('/customers/{customer}', [CustomerController::class, 'destroy'])->middleware('permission:customers.manage');
        Route::get('/customers/{customer}/reconcile', [CustomerController::class, 'reconcile'])->middleware('permission:users.manage');
        Route::post('/customers/{customer}/reconcile', [CustomerController::class, 'reconcile'])->middleware('permission:users.manage');
        
        // Users (Admin only)
        Route::apiResource('users', UserController::class)->middleware('permission:users.manage');
        
        // Orders
        Route::get('/orders', [SalesOrderController::class, 'index']);
        Route::post('/orders', [SalesOrderController::class, 'store'])->middleware(['permission:orders.create', 'idempotent']);
        Route::put('/orders/{id}', [SalesOrderController::class, 'update'])->middleware(['permission:orders.create', 'idempotent']);
        Route::get('/orders/{id}', [SalesOrderController::class, 'show']);
        Route::post('/orders/{id}/status', [SalesOrderController::class, 'updateStatus'])->middleware('idempotent'); // Status permissions checked inside controller method
        
        // Warehouses & Stock
        Route::get('/warehouses', [WarehouseController::class, 'index']);
        Route::post('/warehouses/{warehouseId}/stock/{productId}/adjust', [WarehouseController::class, 'adjustStock'])->middleware(['permission:stock.pack', 'idempotent']);
        Route::get('/warehouses/{warehouseId}/stock/{productId}/reconcile', [WarehouseController::class, 'reconcileStock'])->middleware('permission:stock.view');
        
        Route::get('/warehouse/orders-to-pack', [WarehouseController::class, 'ordersToPack'])->middleware('permission:stock.pack');
        Route::post('/warehouse/pack-item', [WarehouseController::class, 'packItem'])->middleware(['permission:stock.pack', 'idempotent']);
        Route::post('/warehouse/mark-ready', [WarehouseController::class, 'markReady'])->middleware(['permission:stock.pack', 'idempotent']);
        Route::get('/warehouse/stock', [WarehouseController::class, 'stockList'])->middleware('permission:stock.view');
        Route::get('/warehouse/transactions', [WarehouseController::class, 'transactions'])->middleware('permission:stock.view');
        Route::post('/payments', [PaymentController::class, 'store'])->middleware(['permission:orders.create', 'idempotent']);
        
        // Sales Returns (Requires orders permissions)
        Route::get('/sales-returns', [SalesReturnController::class, 'index'])->middleware('permission:orders.view');
        Route::get('/sales-returns/{id}', [SalesReturnController::class, 'show'])->middleware('permission:orders.view');
        Route::post('/sales-returns', [SalesReturnController::class, 'store'])->middleware(['permission:orders.create', 'idempotent']);
        
        // Stock Transfers (Requires stock permissions)
        Route::get('/stock-transfers', [StockTransferController::class, 'index'])->middleware('permission:stock.view');
        Route::get('/stock-transfers/{id}', [StockTransferController::class, 'show'])->middleware('permission:stock.view');
        Route::post('/stock-transfers', [StockTransferController::class, 'store'])->middleware(['permission:stock.pack', 'idempotent']);
        Route::post('/stock-transfers/{id}/complete', [StockTransferController::class, 'complete'])->middleware(['permission:stock.pack', 'idempotent']);
        Route::post('/stock-transfers/{id}/cancel', [StockTransferController::class, 'cancel'])->middleware(['permission:stock.pack', 'idempotent']);
        
        // Delivery Trips (Requires delivery permissions)
        Route::get('/delivery-trips', [DeliveryTripController::class, 'index'])->middleware('permission:delivery.view');
        Route::get('/delivery-trips/drivers', [DeliveryTripController::class, 'drivers'])->middleware('permission:delivery.view');
        Route::get('/delivery-trips/{id}', [DeliveryTripController::class, 'show'])->middleware('permission:delivery.view');
        Route::post('/delivery-trips', [DeliveryTripController::class, 'store'])->middleware(['permission:delivery.update', 'idempotent']);
        Route::post('/delivery-trips/orders/{tripOrderId}/deliver', [DeliveryTripController::class, 'deliverOrder'])->middleware(['permission:delivery.update', 'idempotent']);
        Route::post('/delivery-trips/orders/{tripOrderId}/fail', [DeliveryTripController::class, 'failOrder'])->middleware(['permission:delivery.update', 'idempotent']);
        
        // Commissions Lifecycle & Reports (Admin / Owner privileges + Salesman self-view)
        Route::get('/commissions', [CommissionController::class, 'index'])->middleware('permission:users.manage');
        Route::get('/commissions/summary', [CommissionController::class, 'summary'])->middleware('permission:users.manage');
        Route::get('/commissions/preview', [CommissionController::class, 'preview'])->middleware('permission:users.manage');
        Route::get('/commissions/my-commissions', [CommissionController::class, 'myCommissions']);
        Route::get('/commissions/{id}', [CommissionController::class, 'show']);
        Route::post('/commissions/calculate', [CommissionController::class, 'calculate'])->middleware(['permission:users.manage', 'idempotent']);
        Route::post('/commissions/{id}/approve', [CommissionController::class, 'approve'])->middleware(['permission:users.manage', 'idempotent']);
        Route::post('/commissions/{id}/pay', [CommissionController::class, 'pay'])->middleware(['permission:users.manage', 'idempotent']);
        Route::post('/commissions/{id}/cancel', [CommissionController::class, 'cancel'])->middleware(['permission:users.manage', 'idempotent']);
        
        Route::get('/purchase-orders', [PurchaseOrderController::class, 'index'])->middleware('permission:suppliers.manage');
        Route::get('/purchase-orders/{id}', [PurchaseOrderController::class, 'show'])->middleware('permission:suppliers.manage');
        Route::post('/purchase-orders', [PurchaseOrderController::class, 'store'])->middleware(['permission:suppliers.manage', 'idempotent']);
        Route::post('/purchase-orders/{id}/confirm', [PurchaseOrderController::class, 'confirm'])->middleware(['permission:suppliers.manage', 'idempotent']);
        Route::post('/purchase-orders/{id}/receive', [PurchaseOrderController::class, 'receive'])->middleware(['permission:suppliers.manage', 'idempotent']);
        Route::post('/purchase-orders/{id}/cancel', [PurchaseOrderController::class, 'cancel'])->middleware(['permission:suppliers.manage', 'idempotent']);
        
        Route::get('/purchase-requirements', [PurchaseRequirementController::class, 'index'])->middleware('permission:suppliers.manage');
        Route::get('/purchase-requirements/group', [PurchaseRequirementController::class, 'group'])->middleware('permission:suppliers.manage');
        Route::post('/purchase-requirements/convert', [PurchaseRequirementController::class, 'convert'])->middleware(['permission:suppliers.manage', 'idempotent']);
        
        Route::get('/reports/dashboard', [ReportController::class, 'dashboard'])->middleware('permission:users.manage');
        Route::get('/reports/sales', [ReportController::class, 'sales'])->middleware('permission:users.manage');
        Route::get('/reports/profit', [ReportController::class, 'profit'])->middleware('permission:users.manage');
        Route::get('/reports/sales-by-salesman', [ReportController::class, 'salesBySalesman'])->middleware('permission:users.manage');
        Route::get('/reports/customer-debts', [ReportController::class, 'customerDebts'])->middleware('permission:users.manage');
        Route::get('/reports/supplier-debts', [ReportController::class, 'supplierDebts'])->middleware('permission:users.manage');
        Route::get('/reports/payments-history', [ReportController::class, 'paymentsHistory'])->middleware('permission:users.manage');
        Route::get('/reports/low-stock', [ReportController::class, 'lowStock'])->middleware('permission:users.manage');
        Route::get('/reports/stock-movements', [ReportController::class, 'stockMovements'])->middleware('permission:users.manage');
        Route::get('/reports/stock-transfers', [ReportController::class, 'stockTransfers'])->middleware('permission:users.manage');

        // Audit Trail (Admin / Owner inspection)
        Route::get('/audit-logs', [AuditLogController::class, 'index'])->middleware('permission:users.manage');
        Route::get('/audit-logs/{id}', [AuditLogController::class, 'show'])->middleware('permission:users.manage');
        Route::get('/audit-logs/entity/{entityType}/{entityId}', [AuditLogController::class, 'entityHistory'])->middleware('permission:users.manage');

        // Notifications & Device Tokens
        Route::get('/notifications', [NotificationController::class, 'index']);
        Route::get('/notifications/unread-count', [NotificationController::class, 'unreadCount']);
        Route::post('/notifications/read', [NotificationController::class, 'markAllRead']);
        Route::post('/notifications/{id}/read', [NotificationController::class, 'markRead']);
        Route::post('/device-token', [NotificationController::class, 'registerDeviceToken']);
        Route::delete('/device-token', [NotificationController::class, 'removeDeviceToken']);
        Route::get('/notifications/whatsapp-logs', [NotificationController::class, 'whatsAppLogs'])->middleware('permission:users.manage');
        Route::post('/notifications/whatsapp/{id}/retry', [NotificationController::class, 'retryWhatsApp'])->middleware('permission:users.manage');
    });
});
