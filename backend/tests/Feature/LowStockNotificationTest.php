<?php

namespace Tests\Feature;

use App\Models\Notification;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use App\Models\Warehouse;
use App\Models\WarehouseStock;
use App\Services\NotificationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class LowStockNotificationTest extends TestCase
{
    use RefreshDatabase;

    protected User $admin;
    protected Warehouse $warehouse1;
    protected Warehouse $warehouse2;
    protected Product $product;

    protected function setUp(): void
    {
        parent::setUp();

        $adminRole = Role::create([
            'name' => Role::ADMIN,
            'display_name' => 'Admin',
            'permissions' => ['*'],
        ]);

        // Needed for notifyRole in the service
        Role::create(['name' => Role::WAREHOUSE, 'display_name' => 'Warehouse']);
        Role::create(['name' => Role::OWNER, 'display_name' => 'Owner']);

        $this->admin = User::factory()->create([
            'role_id' => $adminRole->id,
            'is_active' => true,
        ]);

        $this->warehouse1 = Warehouse::create(['name' => 'Warehouse 1', 'is_active' => true]);
        $this->warehouse2 = Warehouse::create(['name' => 'Warehouse 2', 'is_active' => true]);

        $this->product = Product::create([
            'name' => 'Test Product',
            'sku' => 'SKU-123',
            'cost_price' => 1000,
            'price_n1' => 1500,
        ]);
    }

    /** @test */
    public function test_low_stock_notification_uses_warehouse_specific_threshold()
    {
        $service = app(NotificationService::class);

        // Warehouse 1 stock with threshold 10
        $stock1 = WarehouseStock::create([
            'warehouse_id' => $this->warehouse1->id,
            'product_id' => $this->product->id,
            'quantity' => 5,
            'min_stock_level' => 10,
        ]);

        // Warehouse 2 stock with threshold 20
        $stock2 = WarehouseStock::create([
            'warehouse_id' => $this->warehouse2->id,
            'product_id' => $this->product->id,
            'quantity' => 15,
            'min_stock_level' => 20,
        ]);

        // Trigger notification for warehouse 1
        $service->notifyLowStock($stock1, $this->product);

        $notification1 = Notification::where('data->warehouse_id', $this->warehouse1->id)->first();
        $this->assertNotNull($notification1);
        $this->assertStringContainsString('کەمترین ئاست: 10', $notification1->body);
        $this->assertEquals(10, $notification1->data['min_stock_level']);
        $this->assertEquals(5, $notification1->data['quantity']);

        // Trigger notification for warehouse 2
        $service->notifyLowStock($stock2, $this->product);

        $notification2 = Notification::where('data->warehouse_id', $this->warehouse2->id)->first();
        $this->assertNotNull($notification2);
        $this->assertStringContainsString('کەمترین ئاست: 20', $notification2->body);
        $this->assertEquals(20, $notification2->data['min_stock_level']);
        $this->assertEquals(15, $notification2->data['quantity']);
    }

    /** @test */
    public function test_product_does_not_need_min_stock_level_attribute()
    {
        $service = app(NotificationService::class);

        $stock = WarehouseStock::create([
            'warehouse_id' => $this->warehouse1->id,
            'product_id' => $this->product->id,
            'quantity' => 2,
            'min_stock_level' => 5,
        ]);

        // Verify product doesn't have the attribute in the model (it's not in fillable/casts/table)
        $this->assertArrayNotHasKey('min_stock_level', $this->product->getAttributes());

        // This should not throw any exception now and correctly use stock threshold
        $service->notifyLowStock($stock, $this->product);

        $notification = Notification::latest('id')->first();
        $this->assertStringContainsString('کەمترین ئاست: 5', $notification->body);
        $this->assertEquals(5, $notification->data['min_stock_level']);
    }

    /** @test */
    public function test_quantity_and_threshold_correspond_to_same_warehouse_stock_row()
    {
        $service = app(NotificationService::class);

        $stock = WarehouseStock::create([
            'warehouse_id' => $this->warehouse1->id,
            'product_id' => $this->product->id,
            'quantity' => 7,
            'min_stock_level' => 12,
        ]);

        $service->notifyLowStock($stock, $this->product);

        $notification = Notification::latest('id')->first();
        
        $this->assertEquals($stock->quantity, $notification->data['quantity']);
        $this->assertEquals($stock->min_stock_level, $notification->data['min_stock_level']);
        $this->assertStringContainsString("تەنها {$stock->quantity} دانەیە", $notification->body);
        $this->assertStringContainsString("کەمترین ئاست: {$stock->min_stock_level}", $notification->body);
    }
}
