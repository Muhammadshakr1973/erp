<?php

namespace App\Events;

use App\Models\AuditLog;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class AuditLogCreated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public $afterCommit = true;

    public ?int $auditLogId;
    public ?string $entityType;
    public ?int $entityId;
    public ?string $action;

    /**
     * Create a new event instance.
     */
    public function __construct(?AuditLog $auditLog)
    {
        $this->auditLogId = $auditLog && $auditLog->id ? (int) $auditLog->id : null;
        $this->entityType = $auditLog?->entity_type;
        $this->entityId = $auditLog && $auditLog->entity_id ? (int) $auditLog->entity_id : null;
        $this->action = $auditLog?->action;
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, \Illuminate\Broadcasting\Channel>
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('audit-logs'),
        ];
    }

    /**
     * The event's broadcast name.
     */
    public function broadcastAs(): string
    {
        return 'audit-log.created';
    }

    /**
     * Get the data to broadcast.
     *
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return [
            'event_type' => 'create',
            'audit_log_id' => $this->auditLogId,
            'entity_type' => $this->entityType,
            'entity_id' => $this->entityId,
            'action' => $this->action,
            'changed_at' => now()->toIso8601String(),
        ];
    }
}
