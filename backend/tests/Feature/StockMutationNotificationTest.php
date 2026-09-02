<?php

namespace Tests\Feature;

use App\Models\Notification;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Models\Warehouse;
use App\Models\WarehouseStock;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class StockMutationNotificationTest extends TestCase
{
    use RefreshDatabase;

    protected User $admin;
    protected Warehouse $warehouse;
    protected Product $product;
    protected WarehouseStock $stock;

    protected function setUp(): void
    {
        parent::setUp();

        // Create roles needed for notifyRole
        Role::create(['name' => Role::ADMIN, 'display_name' => 'Admin', 'permissions' => ['*']]);
        Role::create(['name' => Role::WAREHOUSE, 'display_name' => 'Warehouse']);
        Role::create(['name' => Role::OWNER, 'display_name' => 'Owner']);

        $this->admin = User::factory()->create([
            'role_id' => Role::where('name', Role::ADMIN)->first()->id,
            'is_active' => true,
        ]);

        $this->warehouse = Warehouse::create(['name' => 'Test Warehouse', 'is_active' => true]);

        $this->product = Product::create([
            'name' => 'Test Product',
            'sku' => 'SKU-TEST',
            'cost_price' => 1000,
            'price_n1' => 1500,
        ]);

        // Start with healthy stock
        $this->stock = WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 20,
            'min_stock_level' => 10,
        ]);
    }

    /** @test */
    public function test_no_notification_when_above_threshold()
    {
        $this->stock->adjustStock(-5, 'ADJUSTMENT', $this->admin->id); // 20 -> 15

        $this->assertEquals(0, Notification::where('type', Notification::TYPE_STOCK)->count());
    }

    /** @test */
    public function test_low_stock_notification_when_crossing_exactly_to_threshold()
    {
        $this->stock->adjustStock(-10, 'ADJUSTMENT', $this->admin->id); // 20 -> 10

        $this->assertEquals(1, Notification::where('type', Notification::TYPE_STOCK)->count());
        $notification = Notification::first();
        $this->assertStringContainsString('ئاگاداری کەمبوونەوەی کاڵا', $notification->title);
    }

    /** @test */
    public function test_low_stock_notification_when_crossing_below_threshold()
    {
        $this->stock->adjustStock(-12, 'ADJUSTMENT', $this->admin->id); // 20 -> 8

        $this->assertEquals(1, Notification::where('type', Notification::TYPE_STOCK)->count());
    }

    /** @test */
    public function test_no_duplicate_low_stock_notification_when_already_low()
    {
        $this->stock->adjustStock(-12, 'ADJUSTMENT', $this->admin->id); // 20 -> 8 (Trigger 1)
        $this->assertEquals(1, Notification::where('type', Notification::TYPE_STOCK)->count());

        $this->stock->adjustStock(-2, 'ADJUSTMENT', $this->admin->id); // 8 -> 6 (Should not trigger)
        $this->assertEquals(1, Notification::where('type', Notification::TYPE_STOCK)->count());
    }

    /** @test */
    public function test_out_of_stock_notification_when_reaching_zero()
    {
        $this->stock->adjustStock(-20, 'ADJUSTMENT', $this->admin->id); // 20 -> 0

        // Should trigger BOTH Low Stock and Out of Stock if threshold > 0
        // 20 -> 0 is crossing 10 AND crossing 0.
        $this->assertEquals(2, Notification::where('type', Notification::TYPE_STOCK)->count());
        
        $this->assertTrue(Notification::where('title', 'like', '%تەواوبوونی ستۆکی کاڵا%')->exists());
        $this->assertTrue(Notification::where('title', 'like', '%ئاگاداری کەمبوونەوەی کاڵا%')->exists());
    }

    /** @test */
    public function test_no_duplicate_out_of_stock_notification_when_already_zero()
    {
        $this->stock->adjustStock(-20, 'ADJUSTMENT', $this->admin->id); // 20 -> 0 (Trigger Low + Out)
        $count = Notification::where('type', Notification::TYPE_STOCK)->count();
        $this->assertEquals(2, $count);

        $this->stock->adjustStock(5, 'ADJUSTMENT', $this->admin->id); // 0 -> 5 (No trigger, still low)
        $this->stock->adjustStock(-5, 'ADJUSTMENT', $this->admin->id); // 5 -> 0 (Trigger Out again, but not Low)
        
        // Total should be 2 (initial) + 1 (new out of stock) = 3
        $this->assertEquals($count + 1, Notification::where('type', Notification::TYPE_STOCK)->count());
    }

    /** @test */
    public function test_notification_triggers_again_after_returning_above_threshold()
    {
        $this->stock->adjustStock(-15, 'ADJUSTMENT', $this->admin->id); // 20 -> 5 (Trigger Low)
        $this->assertEquals(1, Notification::where('type', Notification::TYPE_STOCK)->count());

        $this->stock->adjustStock(10, 'ADJUSTMENT', $this->admin->id); // 5 -> 15 (Back above)
        
        $this->stock->adjustStock(-7, 'ADJUSTMENT', $this->admin->id); // 15 -> 8 (Trigger Low Again)
        $this->assertEquals(2, Notification::where('type', Notification::TYPE_STOCK)->count());
    }

    /** @test */
    public function test_no_notification_on_transaction_rollback()
    {
        try {
            DB::transaction(function () {
                $this->stock->adjustStock(-15, 'ADJUSTMENT', $this->admin->id); // 20 -> 5 (Would trigger)
                throw new \Exception('Rollback');
            });
        } catch (\Exception $e) {
            // Silence exception
        }

        $this->assertEquals(0, Notification::where('type', Notification::TYPE_STOCK)->count());
    }
}
