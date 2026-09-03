<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Api\V1\Auth\LoginRequest;
use App\Services\AuthService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;

class AuthController extends Controller
{
    protected AuthService $authService;

    public function __construct(AuthService $authService)
    {
        $this->authService = $authService;
    }

    public function login(LoginRequest $request): JsonResponse
    {
        $data = $this->authService->login($request->validated());

        return response()->json([
            'message' => 'چوونەژوورەوە سەرکەوتوو بوو',
            'data' => $data
        ], 200);
    }

    public function logout(Request $request): JsonResponse
    {
        $this->authService->logout($request->user());

        return response()->json([
            'message' => 'چوونەدەرەوە سەرکەوتوو بوو'
        ], 200);
    }

    public function me(Request $request): JsonResponse
    {
        // دەتوانین ڕۆڵەکەش لەگەڵیدا بنێرینەوە بۆ فڕۆنتێند
        $user = $request->user()->load('role');

        return response()->json([
            'data' => [
                'user' => $user
            ]
        ], 200);
    }

    public function broadcastingConfig(Request $request): JsonResponse
    {
        return response()->json([
            'key' => config('broadcasting.connections.pusher.key'),
            'cluster' => config('broadcasting.connections.pusher.options.cluster'),
        ], 200);
    }
}