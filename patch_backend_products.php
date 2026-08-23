<?php

// ProductController patch
$productCtrl = <<<EOT
<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Product;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class ProductController extends Controller
{
    public function index(): JsonResponse
    {
        \$products = Product::with(['category', 'stocks'])->orderBy('id', 'desc')->get();
        return response()->json([
            'message' => 'لیستی کاڵاکان',
            'data' => \$products
        ]);
    }

    public function store(Request \$request): JsonResponse
    {
        \$validated = \$request->validate([
            'name' => 'required|string|max:255',
            'sku' => 'nullable|string|max:255',
            'barcode' => 'nullable|string|max:255',
            'category_id' => 'nullable|exists:categories,id',
            'unit' => 'nullable|string|max:255',
            'units_per_carton' => 'nullable|integer|min:1',
            'cost_price' => 'nullable|numeric|min:0',
            'price_n1' => 'nullable|numeric|min:0',
            'price_n2' => 'nullable|numeric|min:0',
            'price_n3' => 'nullable|numeric|min:0',
            'is_active' => 'boolean'
        ]);

        \$product = Product::create(\$validated);

        return response()->json([
            'message' => 'کاڵاکە بە سەرکەوتوویی زیادکرا',
            'data' => \$product->load(['category', 'stocks'])
        ], 201);
    }

    public function update(Request \$request, Product \$product): JsonResponse
    {
        \$validated = \$request->validate([
            'name' => 'required|string|max:255',
            'sku' => 'nullable|string|max:255',
            'barcode' => 'nullable|string|max:255',
            'category_id' => 'nullable|exists:categories,id',
            'unit' => 'nullable|string|max:255',
            'units_per_carton' => 'nullable|integer|min:1',
            'cost_price' => 'nullable|numeric|min:0',
            'price_n1' => 'nullable|numeric|min:0',
            'price_n2' => 'nullable|numeric|min:0',
            'price_n3' => 'nullable|numeric|min:0',
            'is_active' => 'boolean'
        ]);

        \$product->update(\$validated);

        return response()->json([
            'message' => 'کاڵاکە بە سەرکەوتوویی نوێکرایەوە',
            'data' => \$product->load(['category', 'stocks'])
        ]);
    }

    public function destroy(Product \$product): JsonResponse
    {
        \$product->delete();
        return response()->json([
            'message' => 'کاڵاکە سڕدرایەوە'
        ]);
    }
}
EOT;

file_put_contents('backend/app/Http/Controllers/Api/V1/ProductController.php', $productCtrl);

// CategoryController create
$categoryCtrl = <<<EOT
<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Category;
use Illuminate\Http\JsonResponse;

class CategoryController extends Controller
{
    public function index(): JsonResponse
    {
        \$categories = Category::orderBy('name')->get();
        return response()->json([
            'message' => 'لیستی جۆرەکان',
            'data' => \$categories
        ]);
    }
}
EOT;

file_put_contents('backend/app/Http/Controllers/Api/V1/CategoryController.php', $categoryCtrl);

// update routes
\$routes = file_get_contents('backend/routes/api.php');
if (strpos(\$routes, "Route::apiResource('products', ProductController::class);") === false) {
    \$routes = str_replace("Route::get('/products', [ProductController::class, 'index']);", "Route::apiResource('products', ProductController::class);\n        Route::get('/categories', [CategoryController::class, 'index']);", \$routes);
    // add use CategoryController
    \$routes = str_replace("use App\Http\Controllers\Api\V1\ProductController;", "use App\Http\Controllers\Api\V1\ProductController;\nuse App\Http\Controllers\Api\V1\CategoryController;", \$routes);
    file_put_contents('backend/routes/api.php', \$routes);
}

