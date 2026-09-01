<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Role;
use App\Models\Warehouse;
use App\Models\Product;
use App\Models\WarehouseStock;
use App\Models\Supplier;
use App\Models\Customer;
use App\Models\SalesOrder;
use App\Models\PurchaseOrder;
use App\Models\PurchaseRequirement;
use App\Models\StockTransfer;
use App\Models\SalesmanCommission;
use App\Models\DeliveryTrip;
use App\Models\DeliveryTripOrder;
use App\Services\SalesOrderService;
use App\Services\PurchaseOrderService;
use App\Services\DeliveryTripService;
use App\Services\StockTransferService;
use App\Services\CommissionService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Validation\ValidationException;
use Tests\TestCase;

class StateMachineConsistencyTest extends TestCase
{
    use RefreshDatabase;

    protected $admin;
    protected $warehouse;
    protected $product;

    protected function setUp(): void
    {
        parent::setUp();

        $adminRole = Role::firstOrCreate(['name' => 'admin']);
        $this->admin = User::factory()->create(['role_id' => $adminRole->id, 'is_active' => true]);

        $this->warehouse = Warehouse::create(['name' => 'Main WH', 'code' => 'WH01']);
        $this->product = Product::create([
            'name' => 'Product 1',
            'sku' => 'P1',
            'price' => 1000,
            'cost_price' => 500,
            'min_stock_level' => 5,
        ]);

        WarehouseStock::create([
            'warehouse_id' => $this->warehouse->id,
            'product_id' => $this->product->id,
            'quantity' => 50,
            'reserved_quantity' => 0,
        ]);
    }

    /** @test */
    public function delivery_trip_lifecycle_starts_at_planned_and_auto_completes()
    {
        $driverRole = Role::firstOrCreate(['name' => 'driver']);
        $driver = User::factory()->create(['role_id' => $driverRole->id, 'is_active' => true]);

        $customer = Customer::create(['name' => 'Cust 1', 'current_balance' => 0]);
        $order = SalesOrder::create([
            'order_number' => 'SO-100',
            'customer_id' => $customer->id,
            'warehouse_id' => $this->warehouse->id,
            'created_by' => $this->admin->id,
            'status' => SalesOrder::STATUS_READY,
            'total_amount' => 1000,
            'total_cost' => 500,
            'total_profit' => 500,
        ]);

        $service = app(DeliveryTripService::class);
        $trip = $service->createTrip([
            'driver_id' => $driver->id,
            'trip_date' => now()->toDateString(),
            'order_ids' => [$order->id],
        ], $this->admin);

        $this->assertEquals(DeliveryTrip::STATUS_PLANNED, $trip->status);

        $tripOrder = $trip->orders->first();
        $service->deliverOrder($tripOrder->id, ['received_amount' => 1000], $driver);

        $trip->refresh();
        $this->assertEquals(DeliveryTrip::STATUS_COMPLETED, $trip->status);
    }

    /** @test */
    public function purchase_order_receive_and_cancel_are_idempotent_and_reject_illegal_transitions()
    {
        $supplier = Supplier::create(['name' => 'Supp 1', 'current_balance' => 0]);
        $poService = app(PurchaseOrderService::class);

        $po = $poService->createOrder([
            'supplier_id' => $supplier->id,
            'warehouse_id' => $this->warehouse->id,
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 10, 'unit_cost' => 500]
            ]
        ], $this->admin);

        $this->assertEquals(PurchaseOrder::STATUS_DRAFT, $po->status);

        // Receive PO
        $receivedPo = $poService->receiveOrder($po, $this->admin);
        $this->assertEquals(PurchaseOrder::STATUS_RECEIVED, $receivedPo->status);

        // Re-receive PO should be idempotent replay
        $reReceivedPo = $poService->receiveOrder($po, $this->admin);
        $this->assertEquals(PurchaseOrder::STATUS_RECEIVED, $reReceivedPo->status);

        // Cancelling a RECEIVED PO must throw ValidationException
        $this->expectException(ValidationException::class);
        $poService->cancelOrder($po, $this->admin);
    }

    /** @test */
    public function stock_transfer_completion_and_cancellation_are_safe_and_idempotent()
    {
        $wh2 = Warehouse::create(['name' => 'WH 2', 'code' => 'WH02']);
        $transferService = app(StockTransferService::class);

        $transfer = $transferService->createTransfer([
            'from_warehouse_id' => $this->warehouse->id,
            'to_warehouse_id' => $wh2->id,
            'items' => [
                ['product_id' => $this->product->id, 'quantity' => 5]
            ]
        ], $this->admin);

        $this->assertEquals(StockTransfer::STATUS_DRAFT, $transfer->status);

        // Complete Transfer
        $completed = $transferService->completeTransfer($transfer, $this->admin);
        $this->assertEquals(StockTransfer::STATUS_COMPLETED, $completed->status);

        // Re-completing must be idempotent
        $reCompleted = $transferService->completeTransfer($transfer, $this->admin);
        $this->assertEquals(StockTransfer::STATUS_COMPLETED, $reCompleted->status);

        // Cancelling completed transfer must fail
        $this->expectException(ValidationException::class);
        $transferService->cancelTransfer($transfer, $this->admin);
    }

    /** @test */
    public function commission_approval_payment_and_cancellation_guards()
    {
        $salesmanRole = Role::firstOrCreate(['name' => 'salesman']);
        $salesman = User::factory()->create(['role_id' => $salesmanRole->id, 'is_active' => true]);

        $commission = SalesmanCommission::create([
            'salesman_id' => $salesman->id,
            'year' => 2026,
            'month' => 8,
            'total_sales' => 10000,
            'total_profit' => 5000,
            'commission_rate' => 10.00,
            'commission_amount' => 500,
            'status' => SalesmanCommission::STATUS_CALCULATED,
            'calculated_at' => now(),
        ]);

        $commissionService = app(CommissionService::class);

        // Approve
        $approved = $commissionService->approveCommission($commission->id, $this->admin);
        $this->assertEquals(SalesmanCommission::STATUS_APPROVED, $approved->status);

        // Pay
        $paid = $commissionService->payCommission($commission->id, $this->admin, ['payment_method' => 'CASH']);
        $this->assertEquals(SalesmanCommission::STATUS_PAID, $paid->status);

        // Re-pay idempotent
        $rePaid = $commissionService->payCommission($commission->id, $this->admin, ['payment_method' => 'CASH']);
        $this->assertEquals(SalesmanCommission::STATUS_PAID, $rePaid->status);

        // Cancelling paid commission must fail
        $this->expectException(ValidationException::class);
        $commissionService->cancelCommission($commission->id, $this->admin);
    }

    /** @test */
    public function sales_return_creates_completed_status_and_atomic_side_effects()
    {
        $customer = Customer::create(['name' => 'Cust Return Test', 'current_balance' => 1000]);
        $order = SalesOrder::create([
            'order_number' => 'SO-RET-1',
            'customer_id' => $customer->id,
            'warehouse_id' => $this->warehouse->id,
            'created_by' => $this->admin->id,
            'status' => SalesOrder::STATUS_DELIVERED,
            'total_amount' => 1000,
            'total_cost' => 500,
            'total_profit' => 500,
        ]);

        $orderItem = \App\Models\SalesOrderItem::create([
            'sales_order_id' => $order->id,
            'product_id' => $this->product->id,
            'quantity' => 2,
            'unit_price' => 500,
            'cost_price' => 250,
            'total' => 1000,
        ]);

        $returnService = app(\App\Services\SalesReturnService::class);
        $return = $returnService->createReturn([
            'sales_order_id' => $order->id,
            'reason' => 'Defective',
            'items' => [
                [
                    'sales_order_item_id' => $orderItem->id,
                    'quantity' => 1,
                ]
            ]
        ], $this->admin);

        $this->assertEquals(\App\Models\SalesReturn::STATUS_COMPLETED, $return->status);
        $this->assertEquals(500, $return->total_return_amount);

        $customer->refresh();
        $this->assertEquals(500, $customer->current_balance);
    }
}
