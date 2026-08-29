<?php

namespace App\Services;

use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class AuditService
{
    /**
     * Keys containing sensitive information that must be redacted.
     */
    protected array $sensitiveKeys = [
        'password',
        'password_confirmation',
        'remember_token',
        'token',
        'access_token',
        'secret',
        'api_key',
        'device_token',
        'plain_text_token',
        'personal_access_token',
        'credit_card',
        'cvv',
    ];

    /**
     * Columns that should not trigger model change audits if they are the only changes.
     */
    protected array $ignoredAttributes = [
        'updated_at',
        'remember_token',
    ];

    /**
     * Primary audit logging method.
     */
    public function log(array $params): AuditLog
    {
        $request = request();
        $user = $params['user'] ?? Auth::user();

        $userId = $params['user_id'] ?? ($user instanceof User ? $user->id : ($user ? $user->id ?? null : null));
        $userName = $params['user_name'] ?? ($user instanceof User ? $user->name : ($user ? $user->name ?? null : 'سیستەم'));
        $userRole = $params['user_role'] ?? ($user instanceof User ? ($user->role?->name ?? 'user') : ($user ? $user->role ?? null : 'system'));

        $ipAddress = $params['ip_address'] ?? ($request ? $request->ip() : null);
        $userAgent = $params['user_agent'] ?? ($request ? $request->userAgent() : null);
        $deviceId = $params['device_id'] ?? ($request ? ($request->header('X-Device-Id') ?? $request->input('device_id') ?? $request->input('device_name')) : null);
        $requestUrl = $params['request_url'] ?? ($request ? substr($request->fullUrl(), 0, 500) : null);
        $requestMethod = $params['request_method'] ?? ($request ? $request->method() : null);

        $oldValues = isset($params['old_values']) ? $this->sanitizeValues($params['old_values']) : null;
        $newValues = isset($params['new_values']) ? $this->sanitizeValues($params['new_values']) : null;

        $entityType = $params['entity_type'] ?? 'General';
        if ($entityType instanceof Model) {
            $entityType = class_basename($entityType);
        }

        $auditData = [
            'user_id'        => $userId,
            'user_name'      => $userName,
            'user_role'      => $userRole,
            'entity_type'    => $entityType,
            'entity_id'      => $params['entity_id'] ?? null,
            'table_name'     => $params['table_name'] ?? null,
            'action'         => strtoupper($params['action'] ?? 'ACTION'),
            'old_values'     => $oldValues,
            'new_values'     => $newValues,
            'description'    => $params['description'] ?? null,
            'ip_address'     => $ipAddress,
            'user_agent'     => $userAgent ? substr($userAgent, 0, 1000) : null,
            'device_id'      => $deviceId,
            'request_url'    => $requestUrl,
            'request_method' => $requestMethod,
            'created_at'     => now(),
        ];

        // Insert directly into audit_logs
        $auditLog = AuditLog::create($auditData);

        // Also record to legacy sync_logs for backwards compatibility if table exists
        try {
            DB::table('sync_logs')->insert([
                'user_id'     => $userId,
                'entity_type' => $entityType,
                'entity_id'   => $params['entity_id'] ?? null,
                'table_name'  => $params['table_name'] ?? strtolower($entityType),
                'action'      => strtoupper($params['action'] ?? 'ACTION'),
                'status'      => 'success',
                'payload'     => json_encode([
                    'audit_log_id' => $auditLog->id,
                    'user_name'    => $userName,
                    'description'  => $params['description'] ?? null,
                    'old'          => $oldValues,
                    'new'          => $newValues,
                    'timestamp'    => now()->toDateTimeString(),
                ]),
                'created_at'  => now(),
                'updated_at'  => now(),
            ]);
        } catch (\Throwable $e) {
            // Non-blocking for sync_logs
        }

        return $auditLog;
    }

    /**
     * Sanitizes arrays or objects by redacting passwords, secrets, and auth tokens.
     */
    public function sanitizeValues($values)
    {
        if (!is_array($values)) {
            if ($values instanceof Model) {
                $values = $values->toArray();
            } else {
                return $values;
            }
        }

        $sanitized = [];
        foreach ($values as $key => $value) {
            $lowerKey = strtolower((string) $key);
            $isSensitive = false;
            foreach ($this->sensitiveKeys as $sensitiveKey) {
                if (str_contains($lowerKey, $sensitiveKey)) {
                    $isSensitive = true;
                    break;
                }
            }

            if ($isSensitive) {
                $sanitized[$key] = '[REDACTED]';
            } elseif (is_array($value)) {
                $sanitized[$key] = $this->sanitizeValues($value);
            } else {
                $sanitized[$key] = $value;
            }
        }

        return $sanitized;
    }

    /**
     * Logs Eloquent model lifecycle events (CREATE, UPDATE, DELETE, RESTORE).
     */
    public function logModelEvent(
        string $action,
        Model $model,
        ?array $customOld = null,
        ?array $customNew = null,
        ?string $description = null,
        $user = null
    ): ?AuditLog {
        $entityType = class_basename($model);
        $tableName = $model->getTable();
        $entityId = $model->getKey();

        $action = strtoupper($action);
        $oldValues = null;
        $newValues = null;

        if ($action === 'CREATE') {
            $newValues = $customNew ?? $model->getAttributes();
            $description = $description ?? "تۆماری نوێ زیادکرا: {$entityType} #{$entityId}";
        } elseif ($action === 'UPDATE') {
            $changes = $model->getChanges();
            // Remove ignored attributes like updated_at
            foreach ($this->ignoredAttributes as $ignored) {
                unset($changes[$ignored]);
            }

            if (empty($changes) && empty($customNew)) {
                return null; // No meaningful change
            }

            $original = $model->getOriginal();
            $diffOld = [];
            foreach (array_keys($changes) as $key) {
                $diffOld[$key] = $original[$key] ?? null;
            }

            $oldValues = $customOld ?? $diffOld;
            $newValues = $customNew ?? $changes;
            $description = $description ?? "تۆمار نوێکرایەوە: {$entityType} #{$entityId}";
        } elseif ($action === 'DELETE') {
            $oldValues = $customOld ?? $model->getAttributes();
            $description = $description ?? "تۆمار سڕایەوە: {$entityType} #{$entityId}";
        } elseif ($action === 'RESTORE') {
            $newValues = $customNew ?? ['deleted_at' => null];
            $description = $description ?? "تۆمار گەڕێندرایەوە: {$entityType} #{$entityId}";
        }

        return $this->log([
            'action'      => $action,
            'entity_type' => $entityType,
            'entity_id'   => $entityId,
            'table_name'  => $tableName,
            'old_values'  => $oldValues,
            'new_values'  => $newValues,
            'description' => $description,
            'user'        => $user,
        ]);
    }

    /**
     * Logs high-level status changes (Sales Orders, Purchase Orders, Trips, etc.).
     */
    public function logStatusChange(
        Model $entity,
        string $oldStatus,
        string $newStatus,
        ?string $description = null,
        $user = null
    ): AuditLog {
        $entityType = class_basename($entity);
        $orderNumber = $entity->order_number ?? $entity->trip_number ?? "#{$entity->getKey()}";

        $desc = $description ?? "دۆخی {$entityType} {$orderNumber} گۆڕدرا لە [{$oldStatus}] بۆ [{$newStatus}]";

        return $this->log([
            'action'      => 'STATUS_CHANGE',
            'entity_type' => $entityType,
            'entity_id'   => $entity->getKey(),
            'table_name'  => $entity->getTable(),
            'old_values'  => ['status' => $oldStatus],
            'new_values'  => ['status' => $newStatus],
            'description' => $desc,
            'user'        => $user,
        ]);
    }

    /**
     * Logs financial movements (Customer Payments, Supplier Payments, Ledger updates).
     */
    public function logFinancialMovement(
        string $action,
        string $entityType,
        int $entityId,
        int $amount,
        string $description,
        array $extra = [],
        $user = null
    ): AuditLog {
        return $this->log([
            'action'      => strtoupper($action),
            'entity_type' => $entityType,
            'entity_id'   => $entityId,
            'table_name'  => strtolower($entityType) . 's',
            'old_values'  => $extra['old_values'] ?? null,
            'new_values'  => array_merge(['amount' => $amount], $extra['new_values'] ?? []),
            'description' => $description,
            'user'        => $user,
        ]);
    }

    /**
     * Logs stock movements (adjustments, reservations, transfers).
     */
    public function logStockMovement(
        string $action,
        int $warehouseId,
        int $productId,
        int $quantityChange,
        int $quantityAfter,
        string $description,
        ?string $refType = null,
        ?int $refId = null,
        $user = null
    ): AuditLog {
        return $this->log([
            'action'      => strtoupper($action),
            'entity_type' => 'WarehouseStock',
            'entity_id'   => $productId,
            'table_name'  => 'warehouse_stocks',
            'old_values'  => [
                'warehouse_id' => $warehouseId,
                'product_id'   => $productId,
            ],
            'new_values'  => [
                'warehouse_id'    => $warehouseId,
                'product_id'      => $productId,
                'quantity_change' => $quantityChange,
                'quantity_after'  => $quantityAfter,
                'reference_type'  => $refType,
                'reference_id'    => $refId,
            ],
            'description' => $description,
            'user'        => $user,
        ]);
    }

    /**
     * Logs authentication events (Login, Logout, Failed Login, Password Reset).
     */
    public function logAuthEvent(
        string $action,
        User $user,
        ?string $description = null,
        ?string $deviceId = null
    ): AuditLog {
        $desc = $description ?? match (strtoupper($action)) {
            'LOGIN'  => "چوونەژوورەوەی سەرکەوتوو بۆ بەکارهێنەر {$user->name} ({$user->phone})",
            'LOGOUT' => "چوونەدەرەوەی بەکارهێنەر {$user->name}",
            default  => "کرداری ناسنامە: {$action} بۆ {$user->name}",
        };

        return $this->log([
            'action'      => strtoupper($action),
            'entity_type' => 'User',
            'entity_id'   => $user->id,
            'table_name'  => 'users',
            'old_values'  => null,
            'new_values'  => [
                'user_id' => $user->id,
                'name'    => $user->name,
                'phone'   => $user->phone,
                'role'    => $user->role?->name ?? 'user',
            ],
            'description' => $desc,
            'device_id'   => $deviceId,
            'user'        => $user,
        ]);
    }
}
