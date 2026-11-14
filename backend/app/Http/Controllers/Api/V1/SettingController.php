<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Setting;
use App\Services\AuditService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;

class SettingController extends Controller
{
    public function __construct(protected AuditService $auditService)
    {
    }

    /**
     * GET /api/v1/settings
     * Owner-only system settings retrieval.
     */
    public function index(Request $request): JsonResponse
    {
        if (!$request->user()?->isOwner()) {
            return response()->json([
                'message' => 'تەنها خاوەنکار (Owner) مۆڵەتی گەیشتنی بەم بەشە هەیە.',
                'error' => 'Forbidden.',
            ], 403);
        }

        return response()->json([
            'data' => $this->buildSettingsPayload(),
        ], 200);
    }

    /**
     * PUT /api/v1/settings
     * Owner-only system settings update.
     */
    public function update(Request $request): JsonResponse
    {
        $user = $request->user();
        if (!$user || !$user->isOwner()) {
            return response()->json([
                'message' => 'تەنها خاوەنکار (Owner) دەتوانێت ڕێکخستنەکانی سیستەم بگۆڕێت.',
                'error' => 'Forbidden.',
            ], 403);
        }

        $validated = $request->validate([
            'company_name' => 'nullable|string|max:150',
            'company_phone' => 'nullable|string|max:30',
            'company_address' => 'nullable|string|max:255',
            'receipt_footer_text' => 'nullable|string|max:255',
            'fcm_server_key' => 'nullable|string|max:500',
            'clear_fcm_server_key' => 'nullable|boolean',
            'default_commission_rate' => 'nullable|numeric|min:0|max:100',
            'default_credit_limit' => 'nullable|integer|min:0',
            'low_stock_default_threshold' => 'nullable|integer|min:0|max:100000',
            'require_order_notes' => 'nullable|boolean',
        ]);

        $oldValues = $this->buildSettingsPayload();

        DB::transaction(function () use ($validated, $user) {
            if (array_key_exists('company_name', $validated)) {
                $name = trim((string) ($validated['company_name'] ?? ''));
                Setting::setValue(
                    'company_name',
                    $name !== '' ? $name : 'کۆمپانیای گەردی (GARDI ERP)',
                    $user->id
                );
            }

            if (array_key_exists('company_phone', $validated)) {
                Setting::setValue('company_phone', trim((string) ($validated['company_phone'] ?? '')), $user->id);
            }

            if (array_key_exists('company_address', $validated)) {
                Setting::setValue('company_address', trim((string) ($validated['company_address'] ?? '')), $user->id);
            }

            if (array_key_exists('receipt_footer_text', $validated)) {
                $footer = trim((string) ($validated['receipt_footer_text'] ?? ''));
                Setting::setValue(
                    'receipt_footer_text',
                    $footer !== '' ? $footer : 'سوپاس بۆ مامەڵەکردنتان',
                    $user->id
                );
            }

            if (!empty($validated['clear_fcm_server_key'])) {
                Setting::setValue('fcm_server_key', null, $user->id);
            } elseif (!empty($validated['fcm_server_key'])) {
                Setting::setValue('fcm_server_key', trim((string) $validated['fcm_server_key']), $user->id);
            }

            if (array_key_exists('default_commission_rate', $validated)) {
                Setting::setValue(
                    'default_commission_rate',
                    (float) ($validated['default_commission_rate'] ?? 0),
                    $user->id
                );
            }

            if (array_key_exists('default_credit_limit', $validated)) {
                Setting::setValue(
                    'default_credit_limit',
                    (int) ($validated['default_credit_limit'] ?? 0),
                    $user->id
                );
            }

            if (array_key_exists('low_stock_default_threshold', $validated)) {
                Setting::setValue(
                    'low_stock_default_threshold',
                    (int) ($validated['low_stock_default_threshold'] ?? 10),
                    $user->id
                );
            }

            if (array_key_exists('require_order_notes', $validated)) {
                Setting::setValue(
                    'require_order_notes',
                    !empty($validated['require_order_notes']) ? '1' : '0',
                    $user->id
                );
            }
        });

        $newValues = $this->buildSettingsPayload();

        $this->auditService->log([
            'action' => 'UPDATE',
            'entity_type' => 'Setting',
            'table_name' => 'settings',
            'old_values' => $oldValues,
            'new_values' => $newValues,
            'description' => 'ڕێکخستنەکانی سیستەم لەلایەن خاوەنکارەوە نوێکرانەوە',
            'user' => $user,
        ]);

        return response()->json([
            'message' => 'ڕێکخستنەکان بە سەرکەوتوویی پاشەکەوت کران',
            'data' => $newValues,
        ], 200);
    }

    /**
     * POST /api/v1/settings/clear-cache
     * Owner-only system cache clear action.
     */
    public function clearCache(Request $request): JsonResponse
    {
        $user = $request->user();
        if (!$user || !$user->isOwner()) {
            return response()->json([
                'message' => 'تەنها خاوەنکار (Owner) مۆڵەتی پاککردنەوەی کاشی هەیە.',
                'error' => 'Forbidden.',
            ], 403);
        }

        Artisan::call('cache:clear');
        Artisan::call('config:clear');

        $this->auditService->log([
            'action' => 'CACHE_CLEAR',
            'entity_type' => 'Setting',
            'table_name' => 'settings',
            'description' => 'کاشی سیستەم لەلایەن خاوەنکارەوە پاککرایەوە',
            'user' => $user,
        ]);

        return response()->json([
            'message' => 'کاشی سیستەم بە سەرکەوتوویی پاککرایەوە',
            'data' => $this->buildSettingsPayload(),
        ], 200);
    }

    private function buildSettingsPayload(): array
    {
        $requireOrderNotesRaw = Setting::getValue('require_order_notes', '0');

        return [
            'company_name' => (string) Setting::getValue('company_name', 'کۆمپانیای گەردی (GARDI ERP)'),
            'company_phone' => (string) Setting::getValue('company_phone', ''),
            'company_address' => (string) Setting::getValue('company_address', ''),
            'receipt_footer_text' => (string) Setting::getValue('receipt_footer_text', 'سوپاس بۆ مامەڵەکردنتان'),
            'fcm_server_key_configured' => !empty(Setting::getValue('fcm_server_key')),
            'default_commission_rate' => (float) Setting::getValue('default_commission_rate', 0),
            'default_credit_limit' => (int) Setting::getValue('default_credit_limit', 0),
            'low_stock_default_threshold' => (int) Setting::getValue('low_stock_default_threshold', 10),
            'require_order_notes' => $requireOrderNotesRaw === '1' || $requireOrderNotesRaw === true || $requireOrderNotesRaw === 1,
        ];
    }
}
