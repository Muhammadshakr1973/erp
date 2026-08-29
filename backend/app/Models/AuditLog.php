<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class AuditLog extends Model
{
    use HasFactory;

    public $timestamps = false;

    protected $table = 'audit_logs';

    protected $fillable = [
        'user_id',
        'user_name',
        'user_role',
        'entity_type',
        'entity_id',
        'table_name',
        'action',
        'old_values',
        'new_values',
        'description',
        'ip_address',
        'user_agent',
        'device_id',
        'request_url',
        'request_method',
        'created_at',
    ];

    protected $casts = [
        'old_values' => 'array',
        'new_values' => 'array',
        'created_at' => 'datetime',
        'entity_id' => 'integer',
        'user_id' => 'integer',
    ];

    /**
     * Prevent updates or deletes on audit logs (Immutability guarantee).
     */
    protected static function booted()
    {
        static::updating(function () {
            throw new \RuntimeException('Audit logs are immutable and cannot be modified.');
        });

        static::deleting(function () {
            throw new \RuntimeException('Audit logs are immutable and cannot be deleted.');
        });
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class, 'user_id');
    }

    public function scopeByUser($query, $userId)
    {
        if (!empty($userId)) {
            return $query->where('user_id', $userId);
        }
        return $query;
    }

    public function scopeByEntity($query, $entityType, $entityId = null)
    {
        if (!empty($entityType)) {
            $query->where('entity_type', $entityType);
        }
        if (!empty($entityId)) {
            $query->where('entity_id', $entityId);
        }
        return $query;
    }

    public function scopeByAction($query, $action)
    {
        if (!empty($action)) {
            return $query->where('action', $action);
        }
        return $query;
    }

    public function scopeDateRange($query, $dateFrom, $dateTo)
    {
        if (!empty($dateFrom)) {
            $query->where('created_at', '>=', $dateFrom . ' 00:00:00');
        }
        if (!empty($dateTo)) {
            $query->where('created_at', '<=', $dateTo . ' 23:59:59');
        }
        return $query;
    }

    public function scopeSearch($query, $term)
    {
        if (!empty($term)) {
            return $query->where(function ($q) use ($term) {
                $q->where('description', 'like', "%{$term}%")
                  ->orWhere('user_name', 'like', "%{$term}%")
                  ->orWhere('entity_type', 'like', "%{$term}%")
                  ->orWhere('action', 'like', "%{$term}%")
                  ->orWhere('device_id', 'like', "%{$term}%");
            });
        }
        return $query;
    }
}
