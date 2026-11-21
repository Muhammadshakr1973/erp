<?php

namespace App\Events;

use App\Models\SalesOrder;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class SalesOrderUpdated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * Broadcast after database transactions are committed.
     *
     * @var bool
     */
    public $afterCommit = true;

    public ?SalesOrder $order;
    public string $actionType;
    public int $orderId;
    public ?int $customerId;
    public ?string $sharedKey;
    public int $version;
    public ?string $status;

    /**
     * Create a new event instance.
     */
    public function __construct(SalesOrder $order, string $actionType = 'update')
    {
        $this->order = $order;
        $this->actionType = $actionType;
        $this->orderId = (int) $order->id;
        $this->customerId = $order->customer_id !== null ? (int) $order->customer_id : null;
        $this->sharedKey = $order->shared_key;
        $this->version = (int) ($order->version ?? 0);
        $this->status = $order->status;
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, \Illuminate\Broadcasting\Channel>
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('sales-order.' . $this->orderId),
            new PrivateChannel('orders'),
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
            'sales_order_id' => $this->orderId,
            'customer_id' => $this->customerId,
            'shared_key' => $this->sharedKey,
            'version' => $this->version,
            'status' => $this->status,
            'changed_at' => now()->toIso8601String(),
            'authoritative_signal' => 'refetch',
        ];
    }
}
