const fs = require('fs');
let c = fs.readFileSync('backend/app/Http/Controllers/Api/V1/SupplierController.php', 'utf8');
if (!c.includes('function show')) {
c = c.replace(/public function update/, `
    public function show($id): JsonResponse
    {
        $supplier = Supplier::findOrFail($id);
        return response()->json([
            'message' => 'وردەکاری دابینکەر',
            'data' => $supplier
        ]);
    }

    public function update`);
fs.writeFileSync('backend/app/Http/Controllers/Api/V1/SupplierController.php', c);
}
let api = fs.readFileSync('backend/routes/api.php', 'utf8');
if (!api.includes('Route::get(\'/suppliers/{id}\'')) {
api = api.replace(/Route::get\('\/suppliers', \[SupplierController::class, 'index'\]\);/, `Route::get('/suppliers', [SupplierController::class, 'index']);
        Route::get('/suppliers/{id}', [SupplierController::class, 'show']);`);
fs.writeFileSync('backend/routes/api.php', api);
}
