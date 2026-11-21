<?php

namespace App\Events;

use App\Models\PurchaseOrder;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class PurchaseOrderUpdated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public $afterCommit = true;

    public ?PurchaseOrder $purchaseOrder;
    public string $actionType;
    public ?int $purchaseOrderId;
    public ?int $supplierId;
    public ?int $warehouseId;

    /**
     * Create a new event instance.
     */
    public function __construct(
        ?PurchaseOrder $purchaseOrder,
        string $actionType = 'update',
        ?int $purchaseOrderId = null,
        ?int $supplierId = null,
        ?int $warehouseId = null
    ) {
        $this->purchaseOrder = $purchaseOrder;
        $this->actionType = $actionType;
        $this->purchaseOrderId = $purchaseOrderId ?? ($purchaseOrder ? (int) $purchaseOrder->id : null);
        $this->supplierId = $supplierId ?? ($purchaseOrder && $purchaseOrder->supplier_id ? (int) $purchaseOrder->supplier_id : null);
        $this->warehouseId = $warehouseId ?? ($purchaseOrder && $purchaseOrder->warehouse_id ? (int) $purchaseOrder->warehouse_id : null);
    }

    /**
     * Get the channels the event should broadcast on.
     *
     * @return array<int, \Illuminate\Broadcasting\Channel>
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('purchases'),
        ];
    }

    /**
     * The event's broadcast name.
     */
    public function broadcastAs(): string
    {
        return 'purchase-order.updated';
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
            'purchase_order_id' => $this->purchaseOrderId,
            'supplier_id' => $this->supplierId,
            'warehouse_id' => $this->warehouseId,
            'status' => $this->purchaseOrder?->status,
            'changed_at' => now()->toIso8601String(),
            'authoritative_signal' => 'refetch',
        ];
    }
}
