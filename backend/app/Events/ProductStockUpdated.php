<?php

namespace App\Events;

use App\Models\Product;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class ProductStockUpdated implements ShouldBroadcastNow
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
        $payload = [
            'event_type' => $this->actionType,
            'product_id' => $this->productId,
            'changed_at' => now()->toIso8601String(),
            'authoritative_signal' => 'patch',
        ];

        $product = $this->product;
        if ($this->actionType !== 'delete' && $this->productId) {
            if (!$product) {
                $product = Product::with([
                    'category:id,name',
                    'supplier:id,name',
                    'stocks:id,warehouse_id,product_id,quantity,reserved_quantity,min_stock_level',
                ])->find($this->productId);
            } else {
                $product->loadMissing([
                    'category:id,name',
                    'supplier:id,name',
                    'stocks:id,warehouse_id,product_id,quantity,reserved_quantity,min_stock_level',
                ]);
            }
        }

        if ($product) {
            $payload['product'] = [
                'id' => $product->id,
                'parent_id' => $product->parent_id,
                'is_parent' => (bool) $product->is_parent,
                'name' => $product->name,
                'variant_name' => $product->variant_name,
                'sku' => $product->sku,
                'barcode' => $product->barcode,
                'category_id' => $product->category_id,
                'supplier_id' => $product->supplier_id,
                'category' => $product->relationLoaded('category') && $product->category
                    ? ['id' => $product->category->id, 'name' => $product->category->name]
                    : null,
                'supplier' => $product->relationLoaded('supplier') && $product->supplier
                    ? ['id' => $product->supplier->id, 'name' => $product->supplier->name]
                    : null,
                'unit' => $product->unit,
                'units_per_carton' => (int) ($product->units_per_carton ?? 12),
                'cost_price' => $product->cost_price,
                'price_n1' => $product->price_n1,
                'price_n2' => $product->price_n2,
                'price_n3' => $product->price_n3,
                'use_parent_price' => (bool) $product->use_parent_price,
                'is_active' => (bool) $product->is_active,
                'image_path' => $product->image_path,
                'stocks' => $product->relationLoaded('stocks')
                    ? $product->stocks->map(fn($s) => [
                        'warehouse_id' => $s->warehouse_id,
                        'product_id' => $s->product_id,
                        'quantity' => (float) $s->quantity,
                        'reserved_quantity' => (float) $s->reserved_quantity,
                        'min_stock_level' => (float) $s->min_stock_level,
                    ])->values()->all()
                    : null,
            ];
        }

        return $payload;
    }
}
