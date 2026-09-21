<?php

namespace App\Events;

use App\Models\Customer;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class CustomerAccountUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public $afterCommit = true;

    public ?Customer $customer;
    public string $actionType;
    public ?int $customerId;

    /**
     * Create a new event instance.
     */
    public function __construct(?Customer $customer, string $actionType = 'update', ?int $customerId = null)
    {
        $this->customer = $customer;
        $this->actionType = $actionType;
        $this->customerId = $customerId ?? ($customer ? $customer->id : null);
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, \Illuminate\Broadcasting\Channel>
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('customers'),
        ];
    }

    /**
     * The event's broadcast name.
     */
    public function broadcastAs(): string
    {
        return 'customer.updated';
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
            'customer_id' => $this->customerId,
            'changed_at' => now()->toIso8601String(),
            'authoritative_signal' => 'refetch',
        ];
    }
}
