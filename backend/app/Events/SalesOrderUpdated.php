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
        $order = null;
        if ($this->actionType !== 'delete' && $this->orderId > 0) {
            $order = SalesOrder::with([
                'customer:id,name,phone,address,current_balance,price_type,permanent_discount,latitude,longitude,route_id',
                'customer.route:id,name',
                'salesman:id,name',
                'warehouse:id,name,type',
                'items.product:id,name,unit,units_per_carton,image_path',
                'salesReturns.items.product:id,name,unit,units_per_carton,image_path',
            ])->find($this->orderId) ?? $this->order;
        }

        $version = $order ? (int) ($order->version ?? $this->version) : $this->version;
        $status = $order ? $order->status : $this->status;
        $customerId = $order && $order->customer_id !== null
            ? (int) $order->customer_id
            : $this->customerId;
        $sharedKey = $order ? $order->shared_key : $this->sharedKey;

        $payload = [
            'event_type' => $this->actionType,
            'sales_order_id' => $this->orderId,
            'customer_id' => $customerId,
            'shared_key' => $sharedKey,
            'version' => $version,
            'status' => $status,
            'changed_at' => now()->toIso8601String(),
            'authoritative_signal' => 'refetch',
        ];

        if ($order && $this->actionType !== 'delete') {
            $customerData = null;
            if ($order->relationLoaded('customer') && $order->customer) {
                $cust = $order->customer;
                $customerData = [
                    'id' => (int) $cust->id,
                    'name' => $cust->name,
                    'phone' => $cust->phone,
                    'address' => $cust->address,
                    'current_balance' => (int) $cust->current_balance,
                    'price_type' => $cust->price_type,
                    'permanent_discount' => (float) ($cust->permanent_discount ?? 0),
                    'latitude' => $cust->latitude,
                    'longitude' => $cust->longitude,
                    'route' => $cust->relationLoaded('route') && $cust->route
                        ? [
                            'id' => (int) $cust->route->id,
                            'name' => $cust->route->name,
                        ]
                        : null,
                ];
            } elseif ($customerId === 0) {
                $customerData = [
                    'id' => 0,
                    'name' => 'کڕیاری کاتی (بێ ناو)',
                    'price_type' => 'N3',
                    'current_balance' => 0,
                ];
            }

            $itemsData = [];
            if ($order->relationLoaded('items')) {
                foreach ($order->items as $item) {
                    $prod = $item->relationLoaded('product') ? $item->product : null;
                    $itemsData[] = [
                        'id' => (int) $item->id,
                        'sales_order_id' => (int) $item->sales_order_id,
                        'product_id' => (int) $item->product_id,
                        'quantity' => (float) $item->quantity,
                        'unit_price' => (float) $item->unit_price,
                        'line_total' => (float) ($item->line_total ?? $item->total_price ?? 0),
                        'total_price' => (float) ($item->total_price ?? $item->line_total ?? 0),
                        'subtotal' => (float) ($item->line_total ?? $item->total_price ?? 0),
                        'is_packed' => (bool) $item->is_packed,
                        'notes' => $item->notes,
                        'price_type' => $item->price_type,
                        'product_name' => $prod?->name ?? 'کاڵا',
                        'product_unit' => $prod?->unit ?? 'دانە',
                        'units_per_carton' => (int) ($prod?->units_per_carton ?? 1),
                        'product_image_path' => $prod?->image_path,
                        'product' => $prod
                            ? [
                                'id' => (int) $prod->id,
                                'name' => $prod->name,
                                'unit' => $prod->unit ?? 'دانە',
                                'units_per_carton' => (int) ($prod->units_per_carton ?? 1),
                                'image_path' => $prod->image_path,
                            ]
                            : null,
                    ];
                }
            }

            $returnedItemsData = [];
            if ($order->relationLoaded('salesReturns')) {
                foreach ($order->salesReturns as $ret) {
                    if (!$ret->relationLoaded('items')) {
                        continue;
                    }
                    foreach ($ret->items as $retItem) {
                        $prod = $retItem->relationLoaded('product') ? $retItem->product : null;
                        $returnedItemsData[] = [
                            'id' => (int) $retItem->id,
                            'sales_return_id' => (int) $ret->id,
                            'sales_order_id' => (int) $ret->sales_order_id,
                            'product_id' => (int) $retItem->product_id,
                            'product_name' => $prod?->name ?? 'کاڵا',
                            'quantity' => (float) $retItem->quantity,
                            'unit_price' => (float) $retItem->unit_price,
                            'subtotal' => (float) $retItem->total,
                            'reason' => $retItem->reason ?? $ret->reason,
                            'product_unit' => $prod?->unit ?? 'دانە',
                            'units_per_carton' => (int) ($prod?->units_per_carton ?? 1),
                            'product_image_path' => $prod?->image_path,
                        ];
                    }
                }
            }

            $firstItemPriceType = !empty($itemsData) ? ($itemsData[0]['price_type'] ?? 'N3') : 'N3';

            $payload['order'] = [
                'id' => (int) $order->id,
                'order_number' => $order->order_number,
                'shared_key' => $sharedKey,
                'version' => $version,
                'customer_id' => $customerId ?? 0,
                'salesman_id' => (int) $order->salesman_id,
                'warehouse_id' => $order->warehouse_id !== null ? (int) $order->warehouse_id : null,
                'subtotal' => (float) $order->subtotal,
                'permanent_discount_percent' => (float) ($order->permanent_discount_percent ?? 0),
                'permanent_discount_amount' => (float) ($order->permanent_discount_amount ?? 0),
                'discount_amount' => (float) ($order->discount_amount ?? 0),
                'discount_percent' => (float) ($order->discount_percent ?? 0),
                'discount_type' => $order->discount_type ?? 'FIXED',
                'total_amount' => (float) $order->total_amount,
                'total_profit' => (float) ($order->total_profit ?? 0),
                'status' => $status,
                'notes' => $order->notes,
                'created_at' => $order->created_at ? $order->created_at->toIso8601String() : '',
                'price_type' => $firstItemPriceType,
                'customer' => $customerData,
                'salesman' => $order->relationLoaded('salesman') && $order->salesman
                    ? [
                        'id' => (int) $order->salesman->id,
                        'name' => $order->salesman->name,
                    ]
                    : null,
                'warehouse' => $order->relationLoaded('warehouse') && $order->warehouse
                    ? [
                        'id' => (int) $order->warehouse->id,
                        'name' => $order->warehouse->name,
                        'type' => $order->warehouse->type,
                    ]
                    : null,
                'items' => $itemsData,
                'returned_items' => $returnedItemsData,
            ];

            $encoded = json_encode($payload, JSON_UNESCAPED_UNICODE);
            if ($encoded !== false && strlen($encoded) <= 8500) {
                $payload['authoritative_signal'] = 'patch';
            } else {
                unset($payload['order']);
                $payload['authoritative_signal'] = 'refetch';
            }
        }

        return $payload;
    }
}
