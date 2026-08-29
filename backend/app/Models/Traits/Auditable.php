<?php

namespace App\Models\Traits;

use App\Services\AuditService;

trait Auditable
{
    /**
     * Boot the Auditable trait for Eloquent models.
     */
    public static function bootAuditable(): void
    {
        static::created(function ($model) {
            if ($model->shouldAudit('CREATE')) {
                app(AuditService::class)->logModelEvent('CREATE', $model);
            }
        });

        static::updated(function ($model) {
            if ($model->shouldAudit('UPDATE')) {
                app(AuditService::class)->logModelEvent('UPDATE', $model);
            }
        });

        static::deleted(function ($model) {
            if ($model->shouldAudit('DELETE')) {
                app(AuditService::class)->logModelEvent('DELETE', $model);
            }
        });

        if (method_exists(static::class, 'restored')) {
            static::restored(function ($model) {
                if ($model->shouldAudit('RESTORE')) {
                    app(AuditService::class)->logModelEvent('RESTORE', $model);
                }
            });
        }
    }

    /**
     * Determine if the model should be audited for a given action.
     */
    public function shouldAudit(string $action): bool
    {
        return true;
    }
}
