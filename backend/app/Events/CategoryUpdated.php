<?php

namespace App\Events;

use App\Models\Category;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class CategoryUpdated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public $afterCommit = true;

    public ?Category $category;
    public string $actionType;
    public ?int $categoryId;

    /**
     * Create a new event instance.
     */
    public function __construct(?Category $category, string $actionType = 'update', ?int $categoryId = null)
    {
        $this->category = $category;
        $this->actionType = $actionType;
        $this->categoryId = $categoryId ?? ($category ? (int) $category->id : null);
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, \Illuminate\Broadcasting\Channel>
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('categories'),
        ];
    }

    /**
     * The event's broadcast name.
     */
    public function broadcastAs(): string
    {
        return 'category.updated';
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
            'category_id' => $this->categoryId,
            'changed_at' => now()->toIso8601String(),
            'authoritative_signal' => 'patch',
        ];

        if ($this->category !== null) {
            $payload['category'] = [
                'id' => (int) $this->category->id,
                'name' => $this->category->name,
                'parent_id' => $this->category->parent_id,
                'is_active' => (bool) $this->category->is_active,
                'products_count' => (int) ($this->category->products_count ?? $this->category->products()->count()),
            ];
        }

        return $payload;
    }
}
