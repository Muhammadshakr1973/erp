<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Route;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RouteController extends Controller
{
    public function index(): JsonResponse
    {
        $routes = Route::orderBy('name')->get();
        return response()->json([
            'data' => $routes
        ], 200);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255|unique:routes,name',
            'code' => 'required|string|max:50|unique:routes,code',
            'description' => 'nullable|string',
            'color' => 'nullable|string|max:20',
            'is_active' => 'boolean'
        ]);

        $route = Route::create($validated);

        return response()->json([
            'message' => 'ڕاوت بەسەرکەوتوویی زیادکرا',
            'data' => $route
        ], 201);
    }

    public function show(Route $route): JsonResponse
    {
        return response()->json([
            'data' => $route
        ], 200);
    }

    public function update(Request $request, Route $route): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255|unique:routes,name,' . $route->id,
            'code' => 'required|string|max:50|unique:routes,code,' . $route->id,
            'description' => 'nullable|string',
            'color' => 'nullable|string|max:20',
            'is_active' => 'boolean'
        ]);

        $route->update($validated);

        return response()->json([
            'message' => 'ڕاوت بەسەرکەوتوویی نوێکرایەوە',
            'data' => $route
        ], 200);
    }

    public function destroy(Route $route): JsonResponse
    {
        $route->delete();

        return response()->json([
            'message' => 'ڕاوت بەسەرکەوتوویی سڕایەوە'
        ], 200);
    }
}
