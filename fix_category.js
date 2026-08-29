const fs = require('fs');
let c = fs.readFileSync('backend/app/Http/Controllers/Api/V1/CategoryController.php', 'utf8');
if (!c.includes('update(Request')) {
c = c.replace(/}\s*$/, `
    public function show(Category $category): JsonResponse
    {
        return response()->json([
            'message' => 'وردەکاری جۆر',
            'data' => $category
        ]);
    }

    public function update(Request $request, Category $category): JsonResponse
    {
        $validated = $request->validate(['name' => 'required|string|max:255|unique:categories,name,' . $category->id]);
        $category->update($validated);
        return response()->json([
            'message' => 'جۆرەکە نوێکرایەوە',
            'data' => $category
        ]);
    }

    public function destroy(Category $category): JsonResponse
    {
        $category->delete();
        return response()->json([
            'message' => 'جۆرەکە سڕدرایەوە'
        ]);
    }
}
`);
fs.writeFileSync('backend/app/Http/Controllers/Api/V1/CategoryController.php', c);
}
let api = fs.readFileSync('backend/routes/api.php', 'utf8');
if (!api.includes('Route::put(\'/categories/{category}')) {
api = api.replace(/Route::post\('\/categories', \[CategoryController::class, 'store'\]\)->middleware\('permission:products.manage'\);/, `Route::post('/categories', [CategoryController::class, 'store'])->middleware('permission:products.manage');
        Route::get('/categories/{category}', [CategoryController::class, 'show']);
        Route::put('/categories/{category}', [CategoryController::class, 'update'])->middleware('permission:products.manage');
        Route::delete('/categories/{category}', [CategoryController::class, 'destroy'])->middleware('permission:products.manage');`);
fs.writeFileSync('backend/routes/api.php', api);
}
