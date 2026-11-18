<?php

namespace App\Events;

use App\Models\StockTransfer;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class StockTransferUpdated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public $afterCommit = true;

    public ?StockTransfer $transfer;
    public string $actionType;
    public ?int $transferId;

    /**
     * Create a new event instance.
     */
    public function __construct(?StockTransfer $transfer, string $actionType = 'update', ?int $transferId = null)
    {
        $this->transfer = $transfer;
        $this->actionType = $actionType;
        $this->transferId = $transferId ?? ($transfer ? (int) $transfer->id : null);
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, \Illuminate\Broadcasting\Channel>
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('stock-transfers'),
        ];
    }

    /**
     * The event's broadcast name.
     */
    public function broadcastAs(): string
    {
        return 'stock-transfer.updated';
    }

    /**
     * Get the data to broadcast.
     *
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return [
            'event_type' => $this->actionType,
            'stock_transfer_id' => $this->transferId,
            'status' => $this->transfer?->status,
            'from_warehouse_id' => $this->transfer?->from_warehouse_id,
            'to_warehouse_id' => $this->transfer?->to_warehouse_id,
            'changed_at' => now()->toIso8601String(),
            'authoritative_signal' => 'refetch',
        ];
    }
}
