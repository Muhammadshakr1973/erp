<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Services\GeminiAssistantService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class GeminiAssistantController extends Controller
{
    protected GeminiAssistantService $assistantService;

    public function __construct(GeminiAssistantService $assistantService)
    {
        $this->assistantService = $assistantService;
    }

    /**
     * گفتوگۆ لەگەڵ یاریدەدەری زیرەکی Gemini تایبەت بە خاوەن کار
     * POST /api/v1/ai/assistant/chat
     */
    public function chat(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'message' => 'required|string|max:2000',
            'history' => 'nullable|array|max:20',
            'history.*.role' => 'required_with:history|string|in:user,assistant',
            'history.*.content' => 'required_with:history|string|max:3000',
        ]);

        $userMessage = trim($validated['message']);
        $chatHistory = $validated['history'] ?? [];

        $result = $this->assistantService->ask($userMessage, $chatHistory);

        return response()->json([
            'status' => 'success',
            'reply' => $result['reply'],
            'source' => $result['source'],
            'context_summary' => $result['context_summary'] ?? [],
        ]);
    }
}
