<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Product;
use App\Models\Role;
use App\Models\Supplier;
use App\Models\User;
use App\Models\Warehouse;
use App\Models\WarehouseStock;
use App\Services\ReportService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class LowStockReportBusinessRuleTest extends TestCase
{
    use RefreshDatabase;

    protected User $admin;
    protected Warehouse $warehouse;
    protected Product $product;
    protected ReportService $reportService;

    protected function setUp(): void
    {
        parent::setUp();

        $adminRole = Role::create([
            'name' => Role::OWNER,
            'display_name' => 'Owner',
            'permissions' => ['*'],
        ]);

        $this->admin = User::factory()->create([
            'role_id' => $adminRole->id,
            'is_active' => true,
        ]);

        $this->warehouse = Warehouse::create([
            'name' => 'Main Warehouse',
            'is_main' => true,
            'is_active' => true,
        ]);

        $supplier = Supplier::create([
            'name' => 'Supplier A',
            'is_active' => true,
        ]);

        $category = Category::create([
            'name' => 'Category A',
        ]);

        $this->product = Product::create([
            'name' => 'Product A',
            'sku' => 'PROD-A',
            'category_id' => $category->id,
            'supplier_id' => $supplier->id,
            'cost_price' => 100,
            'is_active' => true,
        ]);

        $this->reportService = app(ReportService::class);
    }

    /**
     * Requirement A: quantity < min_stock_level => low stock
     */
    public function test_quantity_below_min_stock_is_low_stock(): void
    {
        WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 5,
            'min_stock_level' => 10,
        ]);

        $report = $this->reportService->getLowStockReport([]);
        
        $this->assertCount(1, $report['items']);
        $this->assertEquals(1, $report['summary']['total_low_stock_items']);
    }

    /**
     * Requirement B: quantity == min_stock_level => low stock
     */
    public function test_quantity_equal_to_min_stock_is_low_stock(): void
    {
        WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 10,
            'min_stock_level' => 10,
        ]);

        $report = $this->reportService->getLowStockReport([]);
        
        $this->assertCount(1, $report['items']);
        $this->assertEquals(1, $report['summary']['total_low_stock_items']);
    }

    /**
     * Requirement C: quantity > min_stock_level => NOT low stock
     */
    public function test_quantity_above_min_stock_is_not_low_stock(): void
    {
        WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 11,
            'min_stock_level' => 10,
        ]);

        $report = $this->reportService->getLowStockReport([]);
        
        $this->assertCount(0, $report['items']);
        $this->assertEquals(0, $report['summary']['total_low_stock_items']);
    }

    /**
     * Requirement D: quantity <= 10 but quantity > min_stock_level => NOT low stock
     * Example: quantity = 8, min_stock_level = 5
     */
    public function test_quantity_below_old_hardcoded_threshold_but_above_min_stock_is_not_low_stock(): void
    {
        WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 8,
            'min_stock_level' => 5,
        ]);

        // With the old rule (orWhere quantity <= 10), this would have been LOW STOCK.
        // With the new rule (quantity <= min_stock_level), this is NOT LOW STOCK.
        
        $report = $this->reportService->getLowStockReport([]);
        
        $this->assertCount(0, $report['items']);
        $this->assertEquals(0, $report['summary']['total_low_stock_items']);
    }

    /**
     * Requirement E: different warehouse_stock rows can have different min_stock_level values
     */
    public function test_different_stock_rows_have_independent_thresholds(): void
    {
        $product2 = Product::create([
            'name' => 'Product B',
            'sku' => 'PROD-B',
            'category_id' => $this->product->category_id,
            'supplier_id' => $this->product->supplier_id,
            'cost_price' => 200,
            'is_active' => true,
        ]);

        // Stock 1: quantity 15, min 10 -> NOT LOW
        WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 15,
            'min_stock_level' => 10,
        ]);

        // Stock 2: quantity 15, min 20 -> LOW
        WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $product2->id,
            'quantity' => 15,
            'min_stock_level' => 20,
        ]);

        $report = $this->reportService->getLowStockReport([]);
        
        $this->assertCount(1, $report['items']);
        $this->assertEquals($product2->id, $report['items'][0]['product_id']);
    }

    /**
     * Requirement F: Low Stock Report and WarehouseStock::scopeLowStock() produce the same business classification
     */
    public function test_report_consistency_with_model_scope(): void
    {
        WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 8,
            'min_stock_level' => 5,
        ]);

        $scopedCount = WarehouseStock::lowStock()->count();
        $report = $this->reportService->getLowStockReport([]);
        
        $this->assertEquals($scopedCount, $report['summary']['total_low_stock_items']);
        $this->assertEquals(0, $scopedCount);

        // Add one that IS low
        WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => Product::create(['name'=>'P3','sku'=>'P3','cost_price'=>1])->id,
            'quantity' => 2,
            'min_stock_level' => 5,
        ]);

        $scopedCount = WarehouseStock::lowStock()->count();
        $report = $this->reportService->getLowStockReport([]);
        
        $this->assertEquals($scopedCount, $report['summary']['total_low_stock_items']);
        $this->assertEquals(1, $scopedCount);
    }
}
