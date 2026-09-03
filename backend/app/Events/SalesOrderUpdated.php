<?php

namespace App\Events;

use App\Models\SalesOrder;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class SalesOrderUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * Broadcast after database transactions are committed.
     *
     * @var bool
     */
    public $afterCommit = true;

    public SalesOrder $order;
    public string $actionType;

    /**
     * Create a new event instance.
     */
    public function __construct(SalesOrder $order, string $actionType = 'update')
    {
        $this->order = $order;
        $this->actionType = $actionType;
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, \Illuminate\Broadcasting\Channel>
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('sales-order.' . $this->order->id),
        ];
    }

    /**
     * The event's broadcast name.
     */
    public function broadcastAs(): string
    {
        return 'sales-order.updated';
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
            'sales_order_id' => $this->order->id,
            'shared_key' => $this->order->shared_key,
            'version' => (int) $this->order->version,
            'status' => $this->order->status,
            'changed_at' => now()->toIso8601String(),
            'authoritative_signal' => 'refetch',
        ];
    }
}
