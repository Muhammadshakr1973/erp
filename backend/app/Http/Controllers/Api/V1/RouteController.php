<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Route;
use App\Models\RouteSalesman;
use App\Models\User;
use App\Models\Role;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RouteController extends Controller
{
    public function index(): JsonResponse
    {
        $routes = Route::withCount('customers')
            ->with(['salesmen' => function ($query) {
                $query->where('is_active', true)->with('salesman:id,name,phone');
            }])
            ->orderBy('name')
            ->get();

        return response()->json([
            'data' => $routes
        ], 200);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255|unique:routes,name',
            'color' => 'nullable|string|max:20',
            'is_active' => 'boolean'
        ]);

        $route = Route::create($validated);
        $route->loadCount('customers')->load(['salesmen.salesman:id,name,phone']);

        return response()->json([
            'message' => 'ڕاوت بەسەرکەوتوویی زیادکرا',
            'data' => $route
        ], 201);
    }

    public function show(Route $route): JsonResponse
    {
        $route->loadCount('customers')
            ->load([
                'customers' => function ($q) {
                    $q->select('id', 'route_id', 'name', 'phone', 'address', 'current_balance', 'is_active');
                },
                'salesmen.salesman:id,name,phone'
            ]);

        return response()->json([
            'data' => $route
        ], 200);
    }

    public function update(Request $request, Route $route): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255|unique:routes,name,' . $route->id,
            'code' => 'required|string|max:50|unique:routes,code,' . $route->id,
            'color' => 'nullable|string|max:20',
            'is_active' => 'boolean'
        ]);

        $route->update($validated);
        $route->loadCount('customers')->load(['salesmen.salesman:id,name,phone']);

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

    public function assignSalesman(Request $request, Route $route): JsonResponse
    {
        $validated = $request->validate([
            'salesman_id' => 'required|exists:users,id',
            'work_date' => 'nullable|date',
        ]);

        $workDate = $request->input('work_date') ?? now()->toDateString();

        $assignment = RouteSalesman::updateOrCreate(
            [
                'route_id' => $route->id,
                'work_date' => $workDate,
            ],
            [
                'salesman_id' => $validated['salesman_id'],
                'is_active' => true,
                'assigned_by' => $request->user()?->id,
            ]
        );

        return response()->json([
            'message' => 'مەندوب بەسەرکەوتوویی بۆ ئەم ڕاوتە دیاریکرا',
            'data' => $assignment->load('salesman:id,name,phone')
        ], 200);
    }

    public function removeSalesman(Route $route, $salesmanId): JsonResponse
    {
        RouteSalesman::where('route_id', $route->id)
            ->where('salesman_id', $salesmanId)
            ->delete();

        return response()->json([
            'message' => 'دیاریکردنی مەندوب سڕایەوە'
        ], 200);
    }

    public function getSalesmen(): JsonResponse
    {
        $salesmen = User::whereHas('role', function ($q) {
            $q->where('name', Role::SALESMAN);
        })->where('is_active', true)->select('id', 'name', 'phone')->get();

        return response()->json([
            'data' => $salesmen
        ], 200);
    }

    public function customers(Route $route): JsonResponse
    {
        $customers = $route->customers()
            ->select('id', 'route_id', 'name', 'phone', 'address', 'current_balance', 'is_active')
            ->orderBy('name')
            ->get();

        return response()->json([
            'data' => $customers
        ], 200);
    }
}

