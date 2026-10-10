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
        try {
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
        } catch (\Illuminate\Validation\ValidationException $ve) {
            throw $ve;
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::error('Gemini Assistant chat exception: ' . $e->getMessage(), [
                'trace' => $e->getTraceAsString(),
            ]);

            return response()->json([
                'status' => 'error',
                'reply' => '⚠️ نەتوانرا وەڵام وەربگیرێت: کێشەیەک لە پەیوەندی بە سیستەم ڕوویدا (' . $e->getMessage() . ')',
                'message' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * پشکنینی ڕاستەوخۆی پەیوەندی لەگەڵ گووگڵ
     * GET /api/v1/ai/assistant/test-key
     */
    public function testKey(): JsonResponse
    {
        $result = $this->assistantService->testKeyConnection();
        return response()->json($result);
    }
}
