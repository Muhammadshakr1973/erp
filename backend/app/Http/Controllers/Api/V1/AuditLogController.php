<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class AuditLogController extends Controller
{
    /**
     * لیستی تۆمارەکانی دەفتەری چاودێری لەگەڵ فلتەرکردن و پەڕەبەندی
     */
    public function index(Request $request): JsonResponse
    {
        $query = AuditLog::with('user:id,name,phone,role_id');

        // فلتەر بەپێی بەکارهێنەر
        if ($request->filled('user_id')) {
            $query->where('user_id', $request->integer('user_id'));
        }

        // فلتەر بەپێی جۆری قەوارە (Entity Type)
        if ($request->filled('entity_type')) {
            $query->where('entity_type', $request->string('entity_type'));
        }

        // فلتەر بەپێی ئایدی قەوارە
        if ($request->filled('entity_id')) {
            $query->where('entity_id', $request->integer('entity_id'));
        }

        // فلتەر بەپێی جۆری کردار (Action)
        if ($request->filled('action')) {
            $query->where('action', strtoupper($request->string('action')));
        }

        // فلتەر بەپێی مەودای بەروار
        if ($request->filled('date_from')) {
            $query->where('created_at', '>=', $request->string('date_from') . ' 00:00:00');
        }

        if ($request->filled('date_to')) {
            $query->where('created_at', '<=', $request->string('date_to') . ' 23:59:59');
        }

        // گەڕان لەناو وەسف یان ناوی خشتە
        if ($request->filled('search')) {
            $search = $request->string('search');
            $query->where(function ($q) use ($search) {
                $q->where('description', 'like', "%{$search}%")
                  ->orWhere('table_name', 'like', "%{$search}%")
                  ->orWhere('entity_type', 'like', "%{$search}%")
                  ->orWhereHas('user', function ($uq) use ($search) {
                      $uq->where('name', 'like', "%{$search}%");
                  });
            });
        }

        $perPage = min($request->integer('per_page', 20), 100);
        $logs = $query->orderByDesc('id')->paginate($perPage);

        return response()->json([
            'message' => 'لیستی تۆمارەکانی چاودێری',
            'data'    => $logs,
        ]);
    }

    /**
     * نیشاندانی وردەکاری یەک لۆگی چاودێری
     */
    public function show($id): JsonResponse
    {
        $log = AuditLog::with('user:id,name,phone,role_id')->findOrFail($id);

        return response()->json([
            'data' => $log,
        ]);
    }

    /**
     * هێنانی مێژووی چاودێری تەواوی قەوارەیەکی دیاریکراو
     */
    public function entityHistory($entityType, $entityId): JsonResponse
    {
        $history = AuditLog::with('user:id,name,phone,role_id')
            ->where('entity_type', $entityType)
            ->where('entity_id', $entityId)
            ->orderByDesc('id')
            ->get();

        return response()->json([
            'message' => "مێژووی تەواوی چاودێری بۆ {$entityType} #{$entityId}",
            'data'    => $history,
        ]);
    }
}
