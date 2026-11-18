<?php

namespace App\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class RouteUpdated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public $afterCommit = true;

    public string $actionType;
    public ?int $routeId;
    public ?int $salesmanId;

    /**
     * Create a new event instance.
     */
    public function __construct(string $actionType = 'update', ?int $routeId = null, ?int $salesmanId = null)
    {
        $this->actionType = $actionType;
        $this->routeId = $routeId;
        $this->salesmanId = $salesmanId;
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, \Illuminate\Broadcasting\Channel>
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('routes'),
        ];
    }

    /**
     * The event's broadcast name.
     */
    public function broadcastAs(): string
    {
        return 'route.updated';
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
            'route_id' => $this->routeId,
            'salesman_id' => $this->salesmanId,
            'changed_at' => now()->toIso8601String(),
            'authoritative_signal' => 'refetch',
        ];
    }
}
