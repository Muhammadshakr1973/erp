<?php

namespace App\Http\Controllers\Api\V1;

use App\Events\CategoryUpdated;
use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Product;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class CategoryController extends Controller
{
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
        ]);

        $name = trim($validated['name']);
        if ($name === '') {
            return response()->json([
                'message' => 'ناوی جۆر پێویستە',
                'errors' => ['name' => ['ناوی جۆر پێویستە']],
            ], 422);
        }

        [$category, $statusCode, $message] = DB::transaction(function () use ($name) {
            $existing = Category::withTrashed()
                ->where('name', $name)
                ->lockForUpdate()
                ->first();

            if ($existing) {
                if ($existing->trashed()) {
                    $existing->restore();
                    $existing->update([
                        'name' => $name,
                        'is_active' => true,
                    ]);

                    return [$existing->fresh(), 201, 'جۆرەکە گەڕێندرایەوە و زیادکرا'];
                }

                if (!$existing->is_active) {
                    $existing->update(['is_active' => true]);
                }

                return [$existing->fresh(), 200, 'ئەم جۆرە پێشتر بوونی هەبوو و هەڵبژێردرا'];
            }

            $created = Category::create([
                'name' => $name,
                'is_active' => true,
            ]);

            return [$created, 201, 'جۆرەکە زیادکرا'];
        });

        $category->loadCount('products');

        try {
            event(new CategoryUpdated($category, $statusCode === 201 ? 'create' : 'update'));
        } catch (\Throwable $e) {
            Log::warning('CategoryUpdated broadcast failed: ' . $e->getMessage());
        }

        return response()->json([
            'message' => $message,
            'data' => $category,
        ], $statusCode);
    }

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $query = Category::withCount('products')->orderBy('name');

        if ($user && method_exists($user, 'isCustomer') && $user->isCustomer()) {
            $allowedIds = $user->customer?->getNormalizedAllowedCategoryIds() ?? [];
            $query->where('is_active', true)
                  ->whereIn('id', empty($allowedIds) ? [-1] : $allowedIds);
        }

        $categories = $query->get();
        return response()->json([
            'message' => 'لیستی جۆرەکان',
            'data' => $categories
        ]);
    }

    public function show(Request $request, Category $category): JsonResponse
    {
        $user = $request->user();
        if ($user && method_exists($user, 'isCustomer') && $user->isCustomer()) {
            $allowedIds = $user->customer?->getNormalizedAllowedCategoryIds() ?? [];
            if (!$category->is_active || !in_array((int) $category->id, $allowedIds, true)) {
                return response()->json([
                    'message' => 'تۆ ڕێگەپێدراو نیت بۆ بینینی ئەم جۆرە.',
                    'error' => 'Forbidden.'
                ], 403);
            }
        }

        $category->loadCount('products');
        return response()->json([
            'message' => 'وردەکاری جۆر',
            'data' => $category
        ]);
    }

    public function update(Request $request, Category $category): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
        ]);

        $name = trim($validated['name']);
        if ($name === '') {
            return response()->json([
                'message' => 'ناوی جۆر پێویستە',
                'errors' => ['name' => ['ناوی جۆر پێویستە']],
            ], 422);
        }

        $result = DB::transaction(function () use ($category, $name) {
            $conflict = Category::withTrashed()
                ->where('name', $name)
                ->where('id', '!=', $category->id)
                ->lockForUpdate()
                ->first();

            if ($conflict) {
                if (!$conflict->trashed()) {
                    return [
                        'error' => true,
                        'message' => 'ئەم ناوی جۆرە پێشتر بۆ جۆرێکی تر بەکارهاتووە',
                    ];
                }

                Product::withTrashed()
                    ->where('category_id', $conflict->id)
                    ->update(['category_id' => $category->id]);
                Category::withTrashed()
                    ->where('parent_id', $conflict->id)
                    ->update(['parent_id' => $category->id]);
                $conflict->forceDelete();
            }

            $category->update(['name' => $name]);

            return [
                'error' => false,
                'data' => $category->fresh()->loadCount('products'),
            ];
        });

        if ($result['error']) {
            return response()->json([
                'message' => $result['message'],
                'errors' => ['name' => [$result['message']]],
            ], 422);
        }

        try {
            event(new CategoryUpdated($result['data'], 'update'));
        } catch (\Throwable $e) {
            Log::warning('CategoryUpdated broadcast failed: ' . $e->getMessage());
        }

        return response()->json([
            'message' => 'جۆرەکە نوێکرایەوە',
            'data' => $result['data'],
        ]);
    }

    public function destroy(Category $category): JsonResponse
    {
        $categoryId = (int) $category->id;
        $category->delete();

        try {
            event(new CategoryUpdated(null, 'delete', $categoryId));
        } catch (\Throwable $e) {
            Log::warning('CategoryUpdated broadcast failed: ' . $e->getMessage());
        }

        return response()->json([
            'message' => 'جۆرەکە سڕدرایەوە'
        ]);
    }
}
