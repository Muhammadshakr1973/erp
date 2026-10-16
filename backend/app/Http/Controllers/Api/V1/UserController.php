<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Role;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;

class UserController extends Controller
{
    public function index(): JsonResponse
    {
        $users = User::with(['role', 'warehouse', 'routeSalesmen' => function ($query) {
            $query->whereNull('work_date')->with('route');
        }])->get();
        $roles = Role::all();

        return response()->json([
            'message' => 'لیستی بەکارهێنەران',
            'data' => [
                'users' => $users,
                'roles' => $roles
            ]
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'phone' => [
                'required',
                'string',
                'max:20',
                Rule::unique('users')->whereNull('deleted_at')
            ],
            'password' => 'required|string|min:4',
            'role_id' => 'required|exists:roles,id',
            'commission_rate' => 'nullable|numeric|min:0|max:100',
            'fixed_salary' => 'nullable|integer|min:0',
            'barcode' => [
                'nullable',
                'string',
                'max:50',
                Rule::unique('users')->whereNull('deleted_at')
            ],
            'is_active' => 'nullable|boolean',
            'is_cash_van' => 'nullable|boolean',
            'warehouse_id' => 'nullable|exists:warehouses,id',
            'image_url' => 'nullable|string|max:2048',
            'routing_cycle' => 'nullable|string|in:1_week,2_weeks'
        ], [
            'name.required' => 'تکایە ناوی بەکارهێنەر بنووسە',
            'phone.required' => 'تکایە ژمارەی مۆبایل بنووسە',
            'phone.unique' => 'ئەم ژمارەی مۆبایلە پێشتر بەکارهاتووە',
            'password.required' => 'تکایە وشەی تێپەڕ بنووسە',
            'password.min' => 'پێویستە وشەی تێپەڕ لانی کەم ٤ پیت بێت',
            'role_id.required' => 'تکایە ڕۆڵی بەکارهێنەر دیاری بکە',
            'role_id.exists' => 'ڕۆڵی دیاریکراو لە سیستەمدا بەردەست نییە',
            'barcode.unique' => 'ئەم بارکۆدە پێشتر بەکارهاتووە',
        ]);

        $isCashVan = (bool) ($validated['is_cash_van'] ?? false);
        $warehouseId = $validated['warehouse_id'] ?? null;

        // If user is a cash van and no warehouse was explicitly chosen, auto-create a dedicated van warehouse
        if ($isCashVan && !$warehouseId) {
            $vanWarehouse = \App\Models\Warehouse::create([
                'name' => 'کۆگای کاشڤان - ' . $validated['name'],
                'address' => 'ئۆتۆمبێلی کاشڤان (' . $validated['phone'] . ')',
                'phone' => $validated['phone'],
                'is_main' => false,
                'is_active' => true,
                'type' => 'VAN',
            ]);
            $warehouseId = $vanWarehouse->id;
        }

        $user = User::create([
            'name' => $validated['name'],
            'phone' => $validated['phone'],
            'password' => Hash::make($validated['password']),
            'role_id' => $validated['role_id'],
            'commission_rate' => $validated['commission_rate'] ?? 0,
            'fixed_salary' => $validated['fixed_salary'] ?? 0,
            'barcode' => $validated['barcode'] ?? null,
            'is_active' => $validated['is_active'] ?? true,
            'is_cash_van' => $isCashVan,
            'warehouse_id' => $warehouseId,
            'image_url' => $validated['image_url'] ?? null,
            'routing_cycle' => $validated['routing_cycle'] ?? '1_week',
        ]);

        // Save routing schedule if provided and user is a salesman
        if ($user->isSalesman() && $request->has('route_plans')) {
            $routePlans = $request->input('route_plans');
            if (is_array($routePlans)) {
                foreach ($routePlans as $plan) {
                    $day = $plan['day_of_week'] ?? null;
                    $week = $plan['week_number'] ?? 1;
                    $routeId = $plan['route_id'] ?? null;
                    
                    if (!$day) continue;

                    $kurdishToEnglishMap = [
                        'شەممە' => 'Saturday',
                        'یەکشەممە' => 'Sunday',
                        'دووشەممە' => 'Monday',
                        'سێشەممە' => 'Tuesday',
                        'چوارشەممە' => 'Wednesday',
                        'پێنجشەممە' => 'Thursday',
                        'هەینی' => 'Friday',
                        'جومعە' => 'Friday',
                    ];
                    if (isset($kurdishToEnglishMap[$day])) {
                        $day = $kurdishToEnglishMap[$day];
                    }

                    if (empty($routeId)) {
                        \App\Models\RouteSalesman::where('salesman_id', $user->id)
                            ->where('day_of_week', $day)
                            ->where('week_number', $week)
                            ->delete();
                    } else {
                        \App\Models\RouteSalesman::updateOrCreate(
                            [
                                'salesman_id' => $user->id,
                                'day_of_week' => $day,
                                'week_number' => $week,
                            ],
                            [
                                'route_id' => $routeId,
                                'work_date' => null,
                                'is_active' => true,
                                'assigned_by' => $request->user()?->id,
                            ]
                        );
                    }
                }
            }
        }

        return response()->json([
            'message' => 'بەکارهێنەر بە سەرکەوتوویی زیادکرا',
            'data' => $user->load(['role', 'routeSalesmen.route'])
        ], 201);
    }

    public function update(Request $request, $id): JsonResponse
    {
        $user = User::findOrFail($id);
        $currentUser = $request->user();

        // Admin/Owner restrictions
        if ($user->isOwner() && !$currentUser->isOwner()) {
            return response()->json([
                'message' => 'تەنها خاوەنکار (Owner) دەتوانێت گۆڕانکاری لە هەژماری خاوەنکاردا بکات.',
                'error' => 'Forbidden.'
            ], 403);
        }

        if ($user->isAdmin() && !$currentUser->isOwner() && $currentUser->id !== $user->id) {
            return response()->json([
                'message' => 'تەنها خاوەنکار (Owner) دەتوانێت گۆڕانکاری لە هەژماری سەرپەرشتیاردا (Admin) بکات.',
                'error' => 'Forbidden.'
            ], 403);
        }

        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'phone' => [
                'required',
                'string',
                'max:20',
                Rule::unique('users')->ignore($user->id)->whereNull('deleted_at')
            ],
            'password' => 'nullable|string|min:4',
            'role_id' => 'required|exists:roles,id',
            'commission_rate' => 'nullable|numeric|min:0|max:100',
            'fixed_salary' => 'nullable|integer|min:0',
            'barcode' => [
                'nullable',
                'string',
                'max:50',
                Rule::unique('users')->ignore($user->id)->whereNull('deleted_at')
            ],
            'is_active' => 'nullable|boolean',
            'is_cash_van' => 'nullable|boolean',
            'warehouse_id' => 'nullable|exists:warehouses,id',
            'image_url' => 'nullable|string|max:2048',
            'routing_cycle' => 'nullable|string|in:1_week,2_weeks'
        ], [
            'name.required' => 'تکایە ناوی بەکارهێنەر بنووسە',
            'phone.required' => 'تکایە ژمارەی مۆبایل بنووسە',
            'phone.unique' => 'ئەم ژمارەی مۆبایلە پێشتر بەکارهاتووە',
            'password.min' => 'پێویستە وشەی تێپەڕ لانی کەم ٤ پیت بێت',
            'role_id.required' => 'تکایە ڕۆڵی بەکارهێنەر دیاری بکە',
            'role_id.exists' => 'ڕۆڵی دیاریکراو لە سیستەمدا بەردەست نییە',
            'barcode.unique' => 'ئەم بارکۆدە پێشتر بەکارهاتووە',
        ]);

        $updateData = [
            'name' => $validated['name'],
            'phone' => $validated['phone'],
            'role_id' => $validated['role_id'],
        ];

        if (array_key_exists('commission_rate', $validated)) {
            $updateData['commission_rate'] = $validated['commission_rate'] ?? 0;
        }
        if (array_key_exists('fixed_salary', $validated)) {
            $updateData['fixed_salary'] = $validated['fixed_salary'] ?? 0;
        }
        if (array_key_exists('barcode', $validated)) {
            $updateData['barcode'] = $validated['barcode'];
        }
        if (array_key_exists('is_active', $validated)) {
            $updateData['is_active'] = $validated['is_active'] ?? true;
        }

        if (array_key_exists('is_cash_van', $validated)) {
            $updateData['is_cash_van'] = (bool) $validated['is_cash_van'];
        }

        $isNowCashVan = array_key_exists('is_cash_van', $validated)
            ? (bool) $validated['is_cash_van']
            : (bool) ($user->is_cash_van ?? false);

        $targetWarehouseId = array_key_exists('warehouse_id', $validated)
            ? $validated['warehouse_id']
            : $user->warehouse_id;

        if ($isNowCashVan && !$targetWarehouseId) {
            $vanWarehouse = \App\Models\Warehouse::create([
                'name' => 'کۆگای کاشڤان - ' . $validated['name'],
                'address' => 'ئۆتۆمبێلی کاشڤان (' . $validated['phone'] . ')',
                'phone' => $validated['phone'],
                'is_main' => false,
                'is_active' => true,
                'type' => 'VAN',
            ]);
            $targetWarehouseId = $vanWarehouse->id;
        }

        $updateData['warehouse_id'] = $targetWarehouseId;

        if (array_key_exists('image_url', $validated)) {
            $updateData['image_url'] = $validated['image_url'];
        }
        if (array_key_exists('routing_cycle', $validated)) {
            $updateData['routing_cycle'] = $validated['routing_cycle'] ?? '1_week';
        }

        if (!empty($validated['password'])) {
            $updateData['password'] = Hash::make($validated['password']);
        }

        $user->update($updateData);

        // Save routing schedule if provided and user is a salesman
        if ($user->isSalesman() && $request->has('route_plans')) {
            $routePlans = $request->input('route_plans');
            if (is_array($routePlans)) {
                foreach ($routePlans as $plan) {
                    $day = $plan['day_of_week'] ?? null;
                    $week = $plan['week_number'] ?? 1;
                    $routeId = $plan['route_id'] ?? null;
                    
                    if (!$day) continue;

                    $kurdishToEnglishMap = [
                        'شەممە' => 'Saturday',
                        'یەکشەممە' => 'Sunday',
                        'دووشەممە' => 'Monday',
                        'سێشەممە' => 'Tuesday',
                        'چوارشەممە' => 'Wednesday',
                        'پێنجشەممە' => 'Thursday',
                        'هەینی' => 'Friday',
                        'جومعە' => 'Friday',
                    ];
                    if (isset($kurdishToEnglishMap[$day])) {
                        $day = $kurdishToEnglishMap[$day];
                    }

                    if (empty($routeId)) {
                        \App\Models\RouteSalesman::where('salesman_id', $user->id)
                            ->where('day_of_week', $day)
                            ->where('week_number', $week)
                            ->delete();
                    } else {
                        // Enforce Rule 14: Clear any other salesman assigned to this route on this same day & week
                        \App\Models\RouteSalesman::where('route_id', $routeId)
                            ->where('day_of_week', $day)
                            ->where('week_number', $week)
                            ->where('salesman_id', '!=', $user->id)
                            ->delete();

                        \App\Models\RouteSalesman::updateOrCreate(
                            [
                                'salesman_id' => $user->id,
                                'day_of_week' => $day,
                                'week_number' => $week,
                            ],
                            [
                                'route_id' => $routeId,
                                'work_date' => null,
                                'is_active' => true,
                                'assigned_by' => $request->user()?->id,
                            ]
                        );
                    }
                }
            }
        }

        return response()->json([
            'message' => 'بەکارهێنەر بە سەرکەوتوویی نوێکرایەوە',
            'data' => $user->load(['role', 'routeSalesmen.route'])
        ]);
    }

    public function destroy(Request $request, $id): JsonResponse
    {
        $user = User::findOrFail($id);
        $currentUser = $request->user();

        // Admin/Owner restrictions
        if ($user->isOwner() && !$currentUser->isOwner()) {
            return response()->json([
                'message' => 'تەنها خاوەنکار (Owner) دەتوانێت ئەم هەژمارە بسڕێتەوە.',
                'error' => 'Forbidden.'
            ], 403);
        }

        if ($user->isAdmin() && !$currentUser->isOwner() && $currentUser->id !== $user->id) {
            return response()->json([
                'message' => 'تەنها خاوەنکار (Owner) دەتوانێت هەژماری سەرپەرشتیار بسڕێتەوە.',
                'error' => 'Forbidden.'
            ], 403);
        }
        
        // Prevent deleting the currently authenticated user
        if ($currentUser->id == $user->id) {
            return response()->json([
                'message' => 'ناتوانیت هەژماری خۆت بسڕیتەوە!'
            ], 400);
        }

        $user->delete();

        return response()->json([
            'message' => 'بەکارهێنەر بە سەرکەوتوویی سڕدرایەوە'
        ]);
    }
}
