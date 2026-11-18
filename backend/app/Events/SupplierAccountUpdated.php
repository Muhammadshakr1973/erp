<?php

namespace App\Events;

use App\Models\Supplier;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class SupplierAccountUpdated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public $afterCommit = true;

    public ?Supplier $supplier;
    public string $actionType;
    public ?int $supplierId;

    /**
     * Create a new event instance.
     */
    public function __construct(?Supplier $supplier, string $actionType = 'update', ?int $supplierId = null)
    {
        $this->supplier = $supplier;
        $this->actionType = $actionType;
        $this->supplierId = $supplierId ?? ($supplier ? $supplier->id : null);
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, \Illuminate\Broadcasting\Channel>
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('suppliers'),
        ];
    }

    /**
     * The event's broadcast name.
     */
    public function broadcastAs(): string
    {
        return 'supplier.updated';
    }

    /**
     * Get the data to broadcast.
     *
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        $payload = [
            'event_type' => $this->actionType,
            'supplier_id' => $this->supplierId,
            'changed_at' => now()->toIso8601String(),
            'authoritative_signal' => 'refetch',
        ];

        if ($this->supplier !== null) {
            $payload['current_balance'] = (float) $this->supplier->current_balance;
        }

        return $payload;
    }
}
