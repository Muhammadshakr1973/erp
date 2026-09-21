<?php

namespace App\Events;

use App\Models\DeliveryTrip;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class DeliveryTripUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public $afterCommit = true;

    public ?DeliveryTrip $trip;
    public string $actionType;
    public ?int $tripId;

    /**
     * Create a new event instance.
     */
    public function __construct(?DeliveryTrip $trip, string $actionType = 'update', ?int $tripId = null)
    {
        $this->trip = $trip;
        $this->actionType = $actionType;
        $this->tripId = $tripId ?? ($trip ? $trip->id : null);
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, \Illuminate\Broadcasting\Channel>
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('delivery-trips'),
        ];
    }

    /**
     * The event's broadcast name.
     */
    public function broadcastAs(): string
    {
        return 'delivery-trip.updated';
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
            'delivery_trip_id' => $this->tripId,
            'changed_at' => now()->toIso8601String(),
            'authoritative_signal' => 'refetch',
        ];
    }
}
