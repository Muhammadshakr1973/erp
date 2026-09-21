<?php

namespace App\Events;

use App\Models\Product;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class ProductStockUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public $afterCommit = true;

    public ?Product $product;
    public string $actionType;
    public ?int $productId;

    /**
     * Create a new event instance.
     */
    public function __construct(?Product $product, string $actionType = 'update', ?int $productId = null)
    {
        $this->product = $product;
        $this->actionType = $actionType;
        $this->productId = $productId ?? ($product ? $product->id : null);
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, \Illuminate\Broadcasting\Channel>
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('products'),
        ];
    }

    /**
     * The event's broadcast name.
     */
    public function broadcastAs(): string
    {
        return 'product.updated';
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
            'product_id' => $this->productId,
            'changed_at' => now()->toIso8601String(),
            'authoritative_signal' => 'refetch',
        ];
    }
}
