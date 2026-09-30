<?php

namespace App\Events;

use App\Models\SalesmanCommission;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcast;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class CommissionUpdated implements ShouldBroadcast
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    /**
     * Broadcast after database transactions are committed.
     *
     * @var bool
     */
    public $afterCommit = true;

    public SalesmanCommission $commission;
    public string $actionType;

    /**
     * Create a new event instance.
     */
    public function __construct(SalesmanCommission $commission, string $actionType = 'update')
    {
        $this->commission = $commission;
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
            new PrivateChannel('commissions'),
            new PrivateChannel('user-notifications.' . $this->commission->salesman_id),
        ];
    }

    /**
     * The event's broadcast name.
     */
    public function broadcastAs(): string
    {
        return 'commission.updated';
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
            'commission_id' => $this->commission->id,
            'salesman_id' => $this->commission->salesman_id,
            'status' => $this->commission->status,
            'commission_amount' => (int) $this->commission->commission_amount,
            'fixed_amount' => (int) ($this->commission->fixed_amount ?? 0),
            'total_sales' => (int) $this->commission->total_sales,
            'total_profit' => (int) $this->commission->total_profit,
            'commission_rate' => (float) $this->commission->commission_rate,
            'period_from' => $this->commission->period_from?->toDateString(),
            'period_to' => $this->commission->period_to?->toDateString(),
            'paid_at' => $this->commission->paid_at?->toIso8601String(),
            'payment_method' => $this->commission->payment_method,
            'changed_at' => now()->toIso8601String(),
            'authoritative_signal' => 'refetch',
        ];
    }
}
