<?php

$content = file_get_contents('backend/app/Http/Controllers/Api/V1/SalesOrderController.php');
if (strpos($content, 'public function index') === false) {
    $indexMethod = <<<EOT
    public function index(): JsonResponse
    {
        \$orders = \App\Models\SalesOrder::with(['customer', 'salesman'])->orderBy('id', 'desc')->get();
        return response()->json([
            'message' => 'لیستی پسوڵەکان',
            'data' => \$orders
        ]);
    }

EOT;
    $content = str_replace('    public function store(', $indexMethod . '    public function store(', $content);
    file_put_contents('backend/app/Http/Controllers/Api/V1/SalesOrderController.php', $content);
}

$routes = file_get_contents('backend/routes/api.php');
if (strpos($routes, "Route::get('/orders'") === false) {
    $routes = str_replace("Route::post('/orders', [SalesOrderController::class, 'store']);", "Route::get('/orders', [SalesOrderController::class, 'index']);\n        Route::post('/orders', [SalesOrderController::class, 'store']);", $routes);
    file_put_contents('backend/routes/api.php', $routes);
}
