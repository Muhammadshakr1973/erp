<?php

namespace Tests\Feature;

use App\Models\Customer;
use App\Models\Product;
use App\Models\Role;
use App\Models\SalesOrder;
use App\Models\SalesOrderItem;
use App\Models\SalesReturn;
use App\Models\SalesReturnItem;
use App\Models\User;
use App\Models\Warehouse;
use App\Models\WarehouseStock;
use App\Models\CustomerLedger;
use App\Models\StockTransaction;
use App\Models\AuditLog;
use App\Services\SalesReturnService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

class SalesReturnTest extends TestCase
{
    use RefreshDatabase;

    protected User $salesman;
    protected Customer $customer;
    protected Warehouse $warehouse;
    protected Product $product;
    protected Product $product2;

    protected function setUp(): void
    {
        parent::setUp();

        // Create salesman role with appropriate permissions
        $salesmanRole = Role::firstOrCreate(
            ['name' => Role::SALESMAN],
            [
                'display_name' => 'Salesman',
                'permissions' => ['orders.create', 'orders.view']
            ]
        );

        // Ensure permissions are updated in case the role was already created
        $salesmanRole->update(['permissions' => ['orders.create', 'orders.view']]);

        // Create salesman user
        $this->salesman = User::factory()->create([
            'role_id' => $salesmanRole->id,
            'is_active' => true,
        ]);

        // Create route
        $route = \App\Models\Route::create([
            'name' => 'Route A',
            'is_active' => true,
        ]);

        // Assign salesman to route for today
        \DB::table('route_salesmen')->insert([
            'route_id' => $route->id,
            'salesman_id' => $this->salesman->id,
            'work_date' => now()->toDateString(),
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Create customer on the route with initial balance
        $this->customer = Customer::create([
            'route_id' => $route->id,
            'name' => 'Test Customer',
            'price_type' => 'N2',
            'current_balance' => 15000,
            'is_active' => true,
        ]);

        // Create warehouse
        $this->warehouse = Warehouse::create([
            'name' => 'Main Warehouse',
            'is_main' => true,
            'is_active' => true,
        ]);

        // Create products
        $this->product = Product::create([
            'name' => 'Test Product 1',
            'sku' => 'TEST-SKU-1',
            'unit' => 'PCS',
            'cost_price' => 5000,
            'price_n1' => 8000,
            'price_n2' => 7500,
            'price_n3' => 7000,
            'is_active' => true,
        ]);

        $this->product2 = Product::create([
            'name' => 'Test Product 2',
            'sku' => 'TEST-SKU-2',
            'unit' => 'PCS',
            'cost_price' => 3000,
            'price_n1' => 5000,
            'price_n2' => 4500,
            'price_n3' => 4000,
            'is_active' => true,
        ]);

        // Seed stock
        WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 10,
            'reserved_quantity' => 0,
        ]);

        WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product2->id,
            'quantity' => 20,
            'reserved_quantity' => 0,
        ]);
    }

    protected function createDeliveredOrder(array $itemsData = []): SalesOrder
    {
        $order = SalesOrder::create([
            'order_number' => 'SO-' . strtoupper(\Illuminate\Support\Str::random(6)),
            'customer_id' => $this->customer->id,
            'salesman_id' => $this->salesman->id,
            'warehouse_id' => $this->warehouse->id,
            'status' => SalesOrder::STATUS_DELIVERED,
            'subtotal' => 15000,
            'total_amount' => 15000,
            'total_profit' => 5000,
            'created_by' => $this->salesman->id,
            'order_date' => now()->toDateString(),
        ]);

        if (empty($itemsData)) {
            $itemsData = [
                [
                    'product_id' => $this->product->id,
                    'quantity' => 2,
                    'unit_price' => 7500,
                    'cost_price' => 5000,
                    'line_total' => 15000,
                ]
            ];
        }

        foreach ($itemsData as $item) {
            SalesOrderItem::create([
                'sales_order_id' => $order->id,
                'product_id' => $item['product_id'],
                'quantity' => $item['quantity'],
                'unit_price' => $item['unit_price'],
                'cost_price' => $item['cost_price'] ?? 5000,
                'line_total' => $item['line_total'],
                'price_type' => 'N2',
            ]);
        }

        return $order;
    }

    /** @test */
    public function it_can_create_a_happy_path_single_return()
    {
        $order = $this->createDeliveredOrder();
        $orderItem = $order->items()->first();

        $payload = [
            'sales_order_id' => $order->id,
            'reason' => 'Defective',
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 1,
                    'reason' => 'Broken packaging',
                ]
            ]
        ];

        $response = $this->actingAs($this->salesman)
            ->postJson('/api/v1/sales-returns', $payload);

        $response->assertStatus(201);
        $response->assertJsonPath('data.total_return_amount', 7500);

        // Verify SalesReturn persists
        $this->assertDatabaseHas('sales_returns', [
            'sales_order_id' => $order->id,
            'customer_id' => $this->customer->id,
            'total_return_amount' => 7500,
            'status' => SalesReturn::STATUS_COMPLETED,
        ]);

        // Verify SalesReturnItem persists
        $this->assertDatabaseHas('sales_return_items', [
            'sales_order_item_id' => $orderItem->id,
            'product_id' => $this->product->id,
            'quantity' => 1,
            'unit_price' => 7500,
            'total' => 7500,
        ]);

        // Verify Customer balance decremented (15000 - 7500 = 7500)
        $this->customer->refresh();
        $this->assertEquals(7500, $this->customer->current_balance);

        // Verify Warehouse Stock quantity incremented (10 + 1 = 11)
        $stock = WarehouseStock::where([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
        ])->first();
        $this->assertEquals(11, $stock->quantity);
    }

    /** @test */
    public function it_can_create_a_happy_path_partial_return()
    {
        $order = $this->createDeliveredOrder([
            [
                'product_id' => $this->product->id,
                'quantity' => 5,
                'unit_price' => 7500,
                'cost_price' => 5000,
                'line_total' => 37500,
            ]
        ]);
        $orderItem = $order->items()->first();

        // First partial return of 2
        $payload1 = [
            'sales_order_id' => $order->id,
            'reason' => 'Partially Damaged 1',
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 2,
                ]
            ]
        ];

        $response1 = $this->actingAs($this->salesman)
            ->postJson('/api/v1/sales-returns', $payload1);

        $response1->assertStatus(201);
        $response1->assertJsonPath('data.total_return_amount', 15000);

        $this->customer->refresh();
        $this->assertEquals(0, $this->customer->current_balance); // 15000 - 15000 = 0

        $stock = WarehouseStock::where([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
        ])->first();
        $this->assertEquals(12, $stock->quantity); // 10 + 2 = 12

        // Second partial return of 2 (Total returned 4, still less than original 5)
        $payload2 = [
            'sales_order_id' => $order->id,
            'reason' => 'Partially Damaged 2',
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 2,
                ]
            ]
        ];

        $response2 = $this->actingAs($this->salesman)
            ->postJson('/api/v1/sales-returns', $payload2);

        $response2->assertStatus(201);
        $response2->assertJsonPath('data.total_return_amount', 15000);

        $this->customer->refresh();
        $this->assertEquals(-15000, $this->customer->current_balance); // 0 - 15000 = -15000

        $stock->refresh();
        $this->assertEquals(14, $stock->quantity); // 12 + 2 = 14
    }

    /** @test */
    public function it_rejects_return_of_undelivered_order()
    {
        $order = $this->createDeliveredOrder();
        $order->update(['status' => SalesOrder::STATUS_CONFIRMED]); // Set to Confirmed instead of Delivered
        $orderItem = $order->items()->first();

        $payload = [
            'sales_order_id' => $order->id,
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 1,
                ]
            ]
        ];

        $response = $this->actingAs($this->salesman)
            ->postJson('/api/v1/sales-returns', $payload);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors('sales_order_id');
    }

    /** @test */
    public function it_rejects_return_with_quantity_greater_than_original()
    {
        $order = $this->createDeliveredOrder();
        $orderItem = $order->items()->first();

        $payload = [
            'sales_order_id' => $order->id,
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 3, // Original quantity is 2
                ]
            ]
        ];

        $response = $this->actingAs($this->salesman)
            ->postJson('/api/v1/sales-returns', $payload);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors('items');
    }

    /** @test */
    public function it_rejects_return_with_quantity_greater_than_currently_returnable()
    {
        $order = $this->createDeliveredOrder();
        $orderItem = $order->items()->first();

        // Return 1 first (success)
        $payload1 = [
            'sales_order_id' => $order->id,
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 1,
                ]
            ]
        ];
        $this->actingAs($this->salesman)->postJson('/api/v1/sales-returns', $payload1)->assertStatus(201);

        // Attempt second return of 2 (Total returned 3, which exceeds original 2)
        $payload2 = [
            'sales_order_id' => $order->id,
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 2,
                ]
            ]
        ];

        $response = $this->actingAs($this->salesman)
            ->postJson('/api/v1/sales-returns', $payload2);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors('items');
    }

    /** @test */
    public function it_rejects_negative_return_quantity()
    {
        $order = $this->createDeliveredOrder();
        $orderItem = $order->items()->first();

        $payload = [
            'sales_order_id' => $order->id,
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => -1,
                ]
            ]
        ];

        $response = $this->actingAs($this->salesman)
            ->postJson('/api/v1/sales-returns', $payload);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors('items.0.quantity');
    }

    /** @test */
    public function it_rejects_zero_return_quantity()
    {
        $order = $this->createDeliveredOrder();
        $orderItem = $order->items()->first();

        $payload = [
            'sales_order_id' => $order->id,
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 0,
                ]
            ]
        ];

        $response = $this->actingAs($this->salesman)
            ->postJson('/api/v1/sales-returns', $payload);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors('items.0.quantity');
    }

    /** @test */
    public function it_rejects_return_of_non_existent_order()
    {
        $order = $this->createDeliveredOrder();
        $orderItem = $order->items()->first();

        $payload = [
            'sales_order_id' => 99999, // Non-existent order
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 1,
                ]
            ]
        ];

        $response = $this->actingAs($this->salesman)
            ->postJson('/api/v1/sales-returns', $payload);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors('sales_order_id');
    }

    /** @test */
    public function it_rejects_return_of_non_existent_item()
    {
        $order = $this->createDeliveredOrder();

        $payload = [
            'sales_order_id' => $order->id,
            'items' => [
                [
                    'sales_order_item_id' => 99999, // Non-existent item
                    'quantity' => 1,
                ]
            ]
        ];

        $response = $this->actingAs($this->salesman)
            ->postJson('/api/v1/sales-returns', $payload);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors('items.0.sales_order_item_id');
    }

    /** @test */
    public function it_ensures_concurrency_safe_returns_by_sorting_items()
    {
        // Setup order with two items in a delivered order
        $order = $this->createDeliveredOrder([
            [
                'product_id' => $this->product2->id, // larger product_id
                'quantity' => 2,
                'unit_price' => 4500,
                'cost_price' => 3000,
                'line_total' => 9000,
            ],
            [
                'product_id' => $this->product->id, // smaller product_id
                'quantity' => 2,
                'unit_price' => 7500,
                'cost_price' => 5000,
                'line_total' => 15000,
            ],
        ]);

        $orderItem2 = $order->items()->where('product_id', $this->product2->id)->first();
        $orderItem1 = $order->items()->where('product_id', $this->product->id)->first();

        // Pass items unsorted (item 2 first, then item 1)
        $payload = [
            'sales_order_id' => $order->id,
            'reason' => 'Defective',
            'items' => [
                [
                    'sales_order_item_id' => $orderItem2->id,
                    'quantity' => 1,
                ],
                [
                    'sales_order_item_id' => $orderItem1->id,
                    'quantity' => 1,
                ],
            ]
        ];

        // Ensure this processes successfully without deadlocking
        $response = $this->actingAs($this->salesman)
            ->postJson('/api/v1/sales-returns', $payload);

        $response->assertStatus(201);
        $this->assertDatabaseHas('sales_returns', [
            'sales_order_id' => $order->id,
            'total_return_amount' => 12000, // 4500 + 7500
        ]);
    }

    /** @test */
    public function it_verifies_audit_log_entry_is_recorded()
    {
        $order = $this->createDeliveredOrder();
        $orderItem = $order->items()->first();

        $payload = [
            'sales_order_id' => $order->id,
            'reason' => 'Defective audit check',
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 1,
                ]
            ]
        ];

        $this->actingAs($this->salesman)
            ->postJson('/api/v1/sales-returns', $payload)
            ->assertStatus(201);

        // Verify audit log entry exists
        $this->assertDatabaseHas('audit_logs', [
            'action' => 'SALES_RETURN',
            'entity_type' => 'SalesReturn',
        ]);
    }

    /** @test */
    public function it_verifies_customer_ledger_entry_and_balance_recalculate()
    {
        $order = $this->createDeliveredOrder();
        $orderItem = $order->items()->first();

        $payload = [
            'sales_order_id' => $order->id,
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 1,
                ]
            ]
        ];

        $this->actingAs($this->salesman)
            ->postJson('/api/v1/sales-returns', $payload)
            ->assertStatus(201);

        // Verify customer ledger entry exists
        $this->assertDatabaseHas('customer_ledger', [
            'customer_id' => $this->customer->id,
            'entry_type' => 'RETURN',
            'type' => 'credit',
            'credit' => 7500,
            'balance_before' => 15000,
            'balance_after' => 7500,
        ]);
    }

    /** @test */
    public function it_verifies_stock_transaction_is_recorded_correctly()
    {
        $order = $this->createDeliveredOrder();
        $orderItem = $order->items()->first();

        $payload = [
            'sales_order_id' => $order->id,
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 1,
                ]
            ]
        ];

        $this->actingAs($this->salesman)
            ->postJson('/api/v1/sales-returns', $payload)
            ->assertStatus(201);

        // Verify stock transaction exists
        $this->assertDatabaseHas('stock_transactions', [
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
            'type' => 'RETURN',
            'quantity_change' => 1,
            'quantity_after' => 11,
        ]);
    }

    /** @test */
    public function it_ensures_transactional_rollback_on_failure()
    {
        $order = $this->createDeliveredOrder();
        $orderItem = $order->items()->first();

        // Cause a failure inside transaction by sending bad items payload directly to SalesReturnService
        $service = app(SalesReturnService::class);

        // Customer balance and stock before
        $this->assertEquals(15000, $this->customer->current_balance);
        $stock = WarehouseStock::where(['warehouse_id' => $this->warehouse->id, 'product_id' => $this->product->id])->first();
        $this->assertEquals(10, $stock->quantity);

        // Passing non-existent sales_order_item_id triggers ModelNotFoundException
        try {
            $service->createReturn([
                'sales_order_id' => $order->id,
                'reason' => 'Rollback check',
                'items' => [
                    [
                        'sales_order_item_id' => 99999, // Should trigger fail
                        'quantity' => 1,
                    ]
                ]
            ], $this->salesman);
            $this->fail('Expected ModelNotFoundException was not thrown.');
        } catch (\Illuminate\Database\Eloquent\ModelNotFoundException $e) {
            // Success: Exception is caught, verify rollback happened
        }

        // Verify customer balance did not change
        $this->customer->refresh();
        $this->assertEquals(15000, $this->customer->current_balance);

        // Verify stock did not change
        $stock->refresh();
        $this->assertEquals(10, $stock->quantity);

        // Verify no SalesReturn was committed
        $this->assertEquals(0, SalesReturn::count());
    }

    /** @test */
    public function it_enforces_idempotency_using_idempotency_key_middleware()
    {
        $order = $this->createDeliveredOrder();
        $orderItem = $order->items()->first();

        $payload = [
            'sales_order_id' => $order->id,
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 1,
                ]
            ]
        ];

        $idempotencyKey = 'test-idempotency-key-return-123';

        // Post return first time with idempotency key
        $response1 = $this->actingAs($this->salesman)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/sales-returns', $payload);

        $response1->assertStatus(201);
        $firstReturnId = $response1->json('data.id');

        // Post return second time with identical idempotency key
        $response2 = $this->actingAs($this->salesman)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/sales-returns', $payload);

        // Should return successful replay of original response
        $response2->assertStatus(201);
        $response2->assertHeader('X-Cache-Lookup', 'HIT');
        $this->assertEquals($firstReturnId, $response2->json('data.id'));

        // Verify only ONE return is actually registered
        $this->assertEquals(1, SalesReturn::count());

        // Verify balance and stock only updated once (15000 - 7500 = 7500, 10 + 1 = 11)
        $this->customer->refresh();
        $this->assertEquals(7500, $this->customer->current_balance);

        $stock = WarehouseStock::where(['warehouse_id' => $this->warehouse->id, 'product_id' => $this->product->id])->first();
        $this->assertEquals(11, $stock->quantity);
    }

    /** @test */
    public function it_rejects_duplicate_items_in_one_request_if_combined_quantity_exceeds_original_quantity()
    {
        $order = $this->createDeliveredOrder([
            [
                'product_id' => $this->product->id,
                'quantity' => 5,
                'unit_price' => 7500,
                'cost_price' => 5000,
                'line_total' => 37500,
            ]
        ]);
        $orderItem = $order->items()->first();

        $payload = [
            'sales_order_id' => $order->id,
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 4,
                ],
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 2,
                ]
            ]
        ];

        // Stock and balance before
        $this->assertEquals(15000, $this->customer->current_balance);
        $stock = WarehouseStock::where(['warehouse_id' => $this->warehouse->id, 'product_id' => $this->product->id])->first();
        $this->assertEquals(10, $stock->quantity);

        $response = $this->actingAs($this->salesman)
            ->postJson('/api/v1/sales-returns', $payload);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors('items');

        // Verify NO sales return created
        $this->assertEquals(0, SalesReturn::count());

        // Verify NO stock mutation
        $stock->refresh();
        $this->assertEquals(10, $stock->quantity);

        // Verify NO ledger mutation
        $this->customer->refresh();
        $this->assertEquals(15000, $this->customer->current_balance);
    }

    /** @test */
    public function it_allows_duplicate_items_in_one_request_if_combined_quantity_equals_remaining_quantity()
    {
        $order = $this->createDeliveredOrder([
            [
                'product_id' => $this->product->id,
                'quantity' => 5,
                'unit_price' => 7500,
                'cost_price' => 5000,
                'line_total' => 37500,
            ]
        ]);
        $orderItem = $order->items()->first();

        $payload = [
            'sales_order_id' => $order->id,
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 3,
                ],
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 2,
                ]
            ]
        ];

        // Stock and balance before
        $this->assertEquals(15000, $this->customer->current_balance);
        $stock = WarehouseStock::where(['warehouse_id' => $this->warehouse->id, 'product_id' => $this->product->id])->first();
        $this->assertEquals(10, $stock->quantity);

        $response = $this->actingAs($this->salesman)
            ->postJson('/api/v1/sales-returns', $payload);

        $response->assertStatus(201);
        $response->assertJsonPath('data.total_return_amount', 37500); // 5 * 7500

        // Verify SalesReturn and items are created
        $this->assertEquals(1, SalesReturn::count());
        $this->assertEquals(2, SalesReturnItem::count());

        // Verify stock increased exactly by 5
        $stock->refresh();
        $this->assertEquals(15, $stock->quantity);

        // Verify customer balance decreased by total return amount (15000 - 37500 = -22500)
        $this->customer->refresh();
        $this->assertEquals(-22500, $this->customer->current_balance);

        // Verify ledger updated exactly once for the total amount
        $this->assertDatabaseHas('customer_ledger', [
            'customer_id' => $this->customer->id,
            'entry_type' => 'RETURN',
            'amount' => 37500,
        ]);
        $this->assertEquals(1, CustomerLedger::where('entry_type', 'RETURN')->count());
    }

    /** @test */
    public function it_rejects_duplicate_items_if_combined_with_previous_partial_return_exceeds_original_quantity()
    {
        $order = $this->createDeliveredOrder([
            [
                'product_id' => $this->product->id,
                'quantity' => 5,
                'unit_price' => 7500,
                'cost_price' => 5000,
                'line_total' => 37500,
            ]
        ]);
        $orderItem = $order->items()->first();

        // Previous partial return of 2
        $payload1 = [
            'sales_order_id' => $order->id,
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 2,
                ]
            ]
        ];
        $this->actingAs($this->salesman)->postJson('/api/v1/sales-returns', $payload1)->assertStatus(201);

        // Current request with duplicate items: 2 + 2 = 4 (exceeds remaining 3)
        $payload2 = [
            'sales_order_id' => $order->id,
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 2,
                ],
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 2,
                ]
            ]
        ];

        $response = $this->actingAs($this->salesman)
            ->postJson('/api/v1/sales-returns', $payload2);

        $response->assertStatus(422);
        $response->assertJsonValidationErrors('items');

        // Only the first SalesReturn should exist
        $this->assertEquals(1, SalesReturn::count());
    }

    /** @test */
    public function it_allows_duplicate_items_if_combined_with_previous_partial_return_is_within_remaining_quantity()
    {
        $order = $this->createDeliveredOrder([
            [
                'product_id' => $this->product->id,
                'quantity' => 5,
                'unit_price' => 7500,
                'cost_price' => 5000,
                'line_total' => 37500,
            ]
        ]);
        $orderItem = $order->items()->first();

        // Previous partial return of 2
        $payload1 = [
            'sales_order_id' => $order->id,
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 2,
                ]
            ]
        ];
        $this->actingAs($this->salesman)->postJson('/api/v1/sales-returns', $payload1)->assertStatus(201);

        // Current request with duplicate items: 1 + 2 = 3 (exactly equals remaining 3)
        $payload2 = [
            'sales_order_id' => $order->id,
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 1,
                ],
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 2,
                ]
            ]
        ];

        $response = $this->actingAs($this->salesman)
            ->postJson('/api/v1/sales-returns', $payload2);

        $response->assertStatus(201);
        $response->assertJsonPath('data.total_return_amount', 22500); // 3 * 7500

        // Both SalesReturns should exist
        $this->assertEquals(2, SalesReturn::count());

        // Total cumulative returned stock should be 5 (original 10 + 2 + 3 = 15)
        $stock = WarehouseStock::where(['warehouse_id' => $this->warehouse->id, 'product_id' => $this->product->id])->first();
        $this->assertEquals(15, $stock->quantity);
    }

    /** @test */
    public function it_enforces_idempotency_on_sales_return_creation_preventing_duplicate_effects()
    {
        $order = $this->createDeliveredOrder([
            [
                'product_id' => $this->product->id,
                'quantity' => 5,
                'unit_price' => 7500,
                'cost_price' => 5000,
                'line_total' => 37500,
            ]
        ]);
        $orderItem = $order->items()->first();

        // Initial conditions
        $initialStock = WarehouseStock::where(['warehouse_id' => $this->warehouse->id, 'product_id' => $this->product->id])->first()->quantity;
        $initialCustomerBalance = $this->customer->fresh()->current_balance;
        $initialLedgerCount = CustomerLedger::where('customer_id', $this->customer->id)->count();
        $initialStockTxCount = StockTransaction::where('product_id', $this->product->id)->count();

        $idempotencyKey = 'sr-idempotency-test-' . uniqid();
        $payload = [
            'sales_order_id' => $order->id,
            'reason' => 'Defective batch',
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 2,
                    'reason' => 'Broken seal',
                ]
            ]
        ];

        // 1. First POST /api/v1/sales-returns with unique X-Idempotency-Key succeeds
        $response1 = $this->actingAs($this->salesman)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/sales-returns', $payload);

        $response1->assertStatus(201);
        $returnId = $response1->json('data.id');
        $this->assertNotNull($returnId);
        $response1->assertJsonPath('data.total_return_amount', 15000); // 2 * 7500

        // Assert single return created
        $this->assertEquals(1, SalesReturn::count());
        $this->assertEquals(1, SalesReturnItem::count());

        // Assert stock incremented by 2 exactly once
        $newStock = WarehouseStock::where(['warehouse_id' => $this->warehouse->id, 'product_id' => $this->product->id])->first()->quantity;
        $this->assertEquals($initialStock + 2, $newStock);

        // Assert stock transaction recorded exactly once
        $this->assertEquals($initialStockTxCount + 1, StockTransaction::where('product_id', $this->product->id)->count());

        // Assert customer ledger entry created exactly once
        $this->assertEquals($initialLedgerCount + 1, CustomerLedger::where('customer_id', $this->customer->id)->count());

        // Assert customer balance credited (reduced) by 15000 exactly once
        $newCustomerBalance = $this->customer->fresh()->current_balance;
        $this->assertEquals($initialCustomerBalance - 15000, $newCustomerBalance);

        // 2. Repeating the exact same request with the same X-Idempotency-Key returns cached result
        $response2 = $this->actingAs($this->salesman)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/sales-returns', $payload);

        $response2->assertStatus(201);
        $response2->assertHeader('X-Cache-Lookup', 'HIT');
        $response2->assertHeader('X-Idempotency-Key', $idempotencyKey);
        $this->assertEquals($response1->getContent(), $response2->getContent());
        $this->assertEquals($returnId, $response2->json('data.id'));

        // Assert NO duplicate SalesReturn row is created
        $this->assertEquals(1, SalesReturn::count());
        $this->assertEquals(1, SalesReturnItem::count());

        // Assert NO duplicate stock movement occurs
        $stockAfterRepeat = WarehouseStock::where(['warehouse_id' => $this->warehouse->id, 'product_id' => $this->product->id])->first()->quantity;
        $this->assertEquals($initialStock + 2, $stockAfterRepeat);
        $this->assertEquals($initialStockTxCount + 1, StockTransaction::where('product_id', $this->product->id)->count());

        // Assert NO duplicate customer ledger entry occurs
        $this->assertEquals($initialLedgerCount + 1, CustomerLedger::where('customer_id', $this->customer->id)->count());

        // Assert NO duplicate customer balance adjustment occurs
        $balanceAfterRepeat = $this->customer->fresh()->current_balance;
        $this->assertEquals($initialCustomerBalance - 15000, $balanceAfterRepeat);

        // 3. A different idempotency key creates a distinct return when otherwise valid
        $differentKey = 'sr-idempotency-different-' . uniqid();
        $payloadSecondReturn = [
            'sales_order_id' => $order->id,
            'reason' => 'Customer changed mind',
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 1,
                    'reason' => 'Unopened extra item',
                ]
            ]
        ];

        $response3 = $this->actingAs($this->salesman)
            ->withHeader('X-Idempotency-Key', $differentKey)
            ->postJson('/api/v1/sales-returns', $payloadSecondReturn);

        $response3->assertStatus(201);
        $this->assertEquals(2, SalesReturn::count());
        $this->assertEquals(2, SalesReturnItem::count());

        $finalStock = WarehouseStock::where(['warehouse_id' => $this->warehouse->id, 'product_id' => $this->product->id])->first()->quantity;
        $this->assertEquals($initialStock + 3, $finalStock);
        $this->assertEquals($initialCustomerBalance - 15000 - 7500, $this->customer->fresh()->current_balance);
    }

    /** @test */
    public function it_rejects_sales_return_with_same_idempotency_key_and_different_payload()
    {
        $order = $this->createDeliveredOrder([
            [
                'product_id' => $this->product->id,
                'quantity' => 5,
                'unit_price' => 7500,
                'cost_price' => 5000,
                'line_total' => 37500,
            ]
        ]);
        $orderItem = $order->items()->first();

        $idempotencyKey = 'sr-payload-mismatch-' . uniqid();
        $payload1 = [
            'sales_order_id' => $order->id,
            'reason' => 'Defective item',
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 1,
                ]
            ]
        ];

        // First submission
        $response1 = $this->actingAs($this->salesman)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/sales-returns', $payload1);
        $response1->assertStatus(201);
        $this->assertEquals(1, SalesReturn::count());

        // Second submission with same key but DIFFERENT quantity in payload
        $payload2 = [
            'sales_order_id' => $order->id,
            'reason' => 'Defective item',
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 2,
                ]
            ]
        ];

        $response2 = $this->actingAs($this->salesman)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/sales-returns', $payload2);

        $response2->assertStatus(422);
        $response2->assertJsonPath('message', 'Idempotency key payload mismatch');

        // Verify still only 1 return exists
        $this->assertEquals(1, SalesReturn::count());
    }

    /** @test */
    public function it_rejects_sales_return_replay_across_different_users_with_403()
    {
        $order = $this->createDeliveredOrder([
            [
                'product_id' => $this->product->id,
                'quantity' => 5,
                'unit_price' => 7500,
                'cost_price' => 5000,
                'line_total' => 37500,
            ]
        ]);
        $orderItem = $order->items()->first();

        $role = Role::where('name', Role::SALESMAN)->first();
        $salesmanB = User::factory()->create([
            'role_id' => $role->id,
            'is_active' => true,
        ]);

        $idempotencyKey = 'sr-cross-user-' . uniqid();
        $payload = [
            'sales_order_id' => $order->id,
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 1,
                ]
            ]
        ];

        // Salesman A submits first
        $responseA = $this->actingAs($this->salesman)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/sales-returns', $payload);
        $responseA->assertStatus(201);

        // Salesman B submits with the SAME key
        $responseB = $this->actingAs($salesmanB)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/sales-returns', $payload);

        $responseB->assertStatus(403);
        $responseB->assertJsonPath('error', 'Forbidden. This idempotency key belongs to another user.');
    }
}
