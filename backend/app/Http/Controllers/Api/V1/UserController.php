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
        $users = User::with('role')->get();
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
            'password' => 'required|string|min:6',
            'role_id' => 'required|exists:roles,id',
            'commission_rate' => 'nullable|numeric|min:0|max:100',
            'barcode' => [
                'nullable',
                'string',
                'max:50',
                Rule::unique('users')->whereNull('deleted_at')
            ],
            'is_active' => 'nullable|boolean',
            'warehouse_id' => 'nullable|exists:warehouses,id'
        ]);

        $user = User::create([
            'name' => $validated['name'],
            'phone' => $validated['phone'],
            'password' => Hash::make($validated['password']),
            'role_id' => $validated['role_id'],
            'commission_rate' => $validated['commission_rate'] ?? 0,
            'barcode' => $validated['barcode'] ?? null,
            'is_active' => $validated['is_active'] ?? true,
            'warehouse_id' => $validated['warehouse_id'] ?? null,
        ]);

        return response()->json([
            'message' => 'بەکارهێنەر بە سەرکەوتوویی زیادکرا',
            'data' => $user->load('role')
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
                Rule::unique('users')->ignore($id)->whereNull('deleted_at')
            ],
            'password' => 'nullable|string|min:6',
            'role_id' => 'required|exists:roles,id',
            'commission_rate' => 'nullable|numeric|min:0|max:100',
            'barcode' => [
                'nullable',
                'string',
                'max:50',
                Rule::unique('users')->ignore($id)->whereNull('deleted_at')
            ],
            'is_active' => 'nullable|boolean',
            'warehouse_id' => 'nullable|exists:warehouses,id'
        ]);

        $updateData = [
            'name' => $validated['name'],
            'phone' => $validated['phone'],
            'role_id' => $validated['role_id'],
        ];

        if (array_key_exists('commission_rate', $validated)) {
            $updateData['commission_rate'] = $validated['commission_rate'] ?? 0;
        }
        if (array_key_exists('barcode', $validated)) {
            $updateData['barcode'] = $validated['barcode'];
        }
        if (array_key_exists('is_active', $validated)) {
            $updateData['is_active'] = $validated['is_active'] ?? true;
        }
        if (array_key_exists('warehouse_id', $validated)) {
            $updateData['warehouse_id'] = $validated['warehouse_id'];
        }

        if (!empty($validated['password'])) {
            $updateData['password'] = Hash::make($validated['password']);
        }

        $user->update($updateData);

        return response()->json([
            'message' => 'بەکارهێنەر بە سەرکەوتوویی نوێکرایەوە',
            'data' => $user->load('role')
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
