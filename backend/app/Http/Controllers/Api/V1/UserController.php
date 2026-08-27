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
            'is_active' => 'nullable|boolean'
        ]);

        $user = User::create([
            'name' => $validated['name'],
            'phone' => $validated['phone'],
            'password' => Hash::make($validated['password']),
            'role_id' => $validated['role_id'],
            'commission_rate' => $validated['commission_rate'] ?? 0,
            'barcode' => $validated['barcode'] ?? null,
            'is_active' => $validated['is_active'] ?? true,
        ]);

        return response()->json([
            'message' => 'بەکارهێنەر بە سەرکەوتوویی زیادکرا',
            'data' => $user->load('role')
        ], 201);
    }

    public function update(Request $request, $id): JsonResponse
    {
        $user = User::findOrFail($id);

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
            'is_active' => 'nullable|boolean'
        ]);

        $updateData = [
            'name' => $validated['name'],
            'phone' => $validated['phone'],
            'role_id' => $validated['role_id'],
            'commission_rate' => $validated['commission_rate'] ?? 0,
            'barcode' => $validated['barcode'] ?? null,
            'is_active' => $validated['is_active'] ?? true,
        ];

        if (!empty($validated['password'])) {
            $updateData['password'] = Hash::make($validated['password']);
        }

        $user->update($updateData);

        return response()->json([
            'message' => 'بەکارهێنەر بە سەرکەوتوویی نوێکرایەوە',
            'data' => $user->load('role')
        ]);
    }

    public function destroy($id): JsonResponse
    {
        $user = User::findOrFail($id);
        
        // Prevent deleting the currently authenticated user
        if (auth()->id() == $user->id) {
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
