<?php

namespace Tests\Feature;

use App\Models\Customer;
use App\Models\CustomerLedger;
use App\Models\CustomerPayment;
use App\Models\Role;
use App\Models\User;
use App\Models\Supplier;
use App\Models\SupplierLedger;
use App\Models\SupplierPayment;
use App\Models\SalesOrder;
use App\Models\PurchaseOrder;
use App\Models\Warehouse;
use App\Services\PaymentService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class LedgerAndPaymentTest extends TestCase
{
    use RefreshDatabase;

    protected User $admin;
    protected Customer $customer;
    protected Supplier $supplier;

    protected function setUp(): void
    {
        parent::setUp();

        // Create admin role
        $adminRole = Role::create([
            'name' => Role::OWNER,
            'display_name' => 'Owner',
            'permissions' => ['*']
        ]);

        // Create admin user
        $this->admin = User::factory()->create([
            'role_id' => $adminRole->id,
            'is_active' => true,
        ]);

        // Create route
        $route = \App\Models\Route::create([
            'name' => 'Route A',
            'is_active' => true,
        ]);

        // Create customer with initial debt 100,000
        $this->customer = Customer::create([
            'route_id' => $route->id,
            'name' => 'Test Customer',
            'price_type' => 'N1',
            'current_balance' => 100000,
            'is_active' => true,
        ]);

        CustomerLedger::create([
            'customer_id' => $this->customer->id,
            'entry_type' => 'ADJUSTMENT',
            'type' => 'debit',
            'debit' => 100000,
            'credit' => 0,
            'amount' => 100000,
            'balance_before' => 0,
            'balance_after' => 100000,
            'description' => 'Initial Debt',
            'created_by' => $this->admin->id,
        ]);

        // Create supplier with initial debt 100,000
        $this->supplier = Supplier::create([
            'name' => 'Test Supplier',
            'phone' => '123456789',
            'current_balance' => 100000,
            'created_by' => $this->admin->id,
        ]);

        SupplierLedger::create([
            'supplier_id' => $this->supplier->id,
            'entry_type' => 'ADJUSTMENT',
            'type' => 'credit',
            'debit' => 0,
            'credit' => 100000,
            'amount' => 100000,
            'balance_before' => 0,
            'balance_after' => 100000,
            'description' => 'Initial Debt',
            'created_by' => $this->admin->id,
        ]);
    }

    /** @test */
    public function test_first_transaction_and_historical_consistency()
    {
        $paymentService = app(PaymentService::class);

        // 1. First transaction
        $payment = $paymentService->collectPayment([
            'customer_id' => $this->customer->id,
            'amount' => 5000,
            'payment_method' => 'CASH',
            'notes' => 'First Payment',
        ], $this->admin);

        $this->assertEquals(5000, $payment->amount);

        // Assert ledger entries (second entry after initial adjustment)
        $ledger = CustomerLedger::where('entry_type', 'PAYMENT')->first();
        $this->assertNotNull($ledger);
        $this->assertEquals('PAYMENT', $ledger->entry_type);
        $this->assertEquals('credit', $ledger->type);
        $this->assertEquals(100000, $ledger->balance_before);
        $this->assertEquals(95000, $ledger->balance_after);

        // Historical Consistency - Immutability of ledger entries
        $this->assertFalse($ledger->update(['amount' => 9999]));
        $this->assertFalse($ledger->delete());

        $this->assertEquals(5000, CustomerLedger::where('entry_type', 'PAYMENT')->first()->amount); // Remains original
        $this->assertEquals(95000, $this->customer->fresh()->current_balance);
    }

    /** @test */
    public function test_multiple_transactions_sequence()
    {
        $paymentService = app(PaymentService::class);

        // First payment (10,000)
        $paymentService->collectPayment([
            'customer_id' => $this->customer->id,
            'amount' => 10000,
            'payment_method' => 'CASH',
        ], $this->admin);

        // Second payment (4,000)
        $paymentService->collectPayment([
            'customer_id' => $this->customer->id,
            'amount' => 4000,
            'payment_method' => 'CASH',
        ], $this->admin);

        $ledgers = CustomerLedger::orderBy('id', 'asc')->get();
        $this->assertCount(3, $ledgers); // 1 initial + 2 payments

        // Initial entry
        $this->assertEquals(0, $ledgers[0]->balance_before);
        $this->assertEquals(100000, $ledgers[0]->balance_after);

        // First payment entry
        $this->assertEquals(100000, $ledgers[1]->balance_before);
        $this->assertEquals(90000, $ledgers[1]->balance_after);

        // Second payment entry
        $this->assertEquals(90000, $ledgers[2]->balance_before);
        $this->assertEquals(86000, $ledgers[2]->balance_after);

        $this->assertEquals(86000, $this->customer->fresh()->current_balance);

        // Test reconciliation matches perfectly
        $reconciliation = $this->customer->fresh()->reconcileBalance();
        $this->assertTrue($reconciliation['is_consistent']);
        $this->assertEquals(86000, $reconciliation['stored_balance']);
        $this->assertEquals(86000, $reconciliation['recalculated_balance']);
        $this->assertEmpty($reconciliation['discrepancies']);
    }

    /** @test */
    public function test_duplicate_requests_prevention_idempotency()
    {
        $idempotencyKey = 'customer-payment-idemp-key-123';
        $payload = [
            'customer_id' => $this->customer->id,
            'amount' => 15000,
            'payment_method' => 'CASH',
            'notes' => 'Idempotent Payment Check',
        ];

        // 1. Submit payment first time
        $response1 = $this->actingAs($this->admin)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/payments', $payload);
        $response1->assertStatus(201);

        // 2. Resubmit with identical X-Idempotency-Key
        $response2 = $this->actingAs($this->admin)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/payments', $payload);
        $response2->assertStatus(201);
        $response2->assertHeader('X-Cache-Lookup', 'HIT');

        // Assert exactly one payment and one payment ledger entry created
        $this->assertEquals(1, CustomerPayment::count());
        $this->assertEquals(1, CustomerLedger::where('entry_type', 'PAYMENT')->count());
        $this->assertEquals(85000, $this->customer->fresh()->current_balance);
    }

    /** @test */
    public function test_customer_payment_same_key_different_payload_fails_with_422_mismatch()
    {
        $idempotencyKey = 'customer-payment-mismatch-key-999';
        $payload1 = [
            'customer_id' => $this->customer->id,
            'amount' => 20000,
            'payment_method' => 'CASH',
            'notes' => 'Original Payment',
        ];

        // 1. Initial successful payment
        $response1 = $this->actingAs($this->admin)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/payments', $payload1);
        $response1->assertStatus(201);
        $this->assertEquals(80000, $this->customer->fresh()->current_balance);

        // 2. Resubmit with same key but altered amount
        $payload2 = [
            'customer_id' => $this->customer->id,
            'amount' => 50000,
            'payment_method' => 'CASH',
            'notes' => 'Altered Payment',
        ];

        $response2 = $this->actingAs($this->admin)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson('/api/v1/payments', $payload2);

        $response2->assertStatus(422);
        $response2->assertJsonPath('message', 'Idempotency key payload mismatch');

        // Confirm no secondary payment or ledger entry created, balance remains 80,000
        $this->assertEquals(1, CustomerPayment::count());
        $this->assertEquals(1, CustomerLedger::where('entry_type', 'PAYMENT')->count());
        $this->assertEquals(80000, $this->customer->fresh()->current_balance);
    }

    /** @test */
    public function test_supplier_payment_same_key_different_payload_fails_with_422_mismatch()
    {
        $idempotencyKey = 'supplier-payment-mismatch-key-888';
        $payload1 = [
            'amount' => 10000,
            'payment_method' => 'cash',
        ];

        // 1. Initial supplier payment
        $response1 = $this->actingAs($this->admin)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson("/api/v1/suppliers/{$this->supplier->id}/pay", $payload1);
        $response1->assertStatus(200);
        $this->assertEquals(90000, $this->supplier->fresh()->current_balance);

        // 2. Resubmit with same key but altered amount
        $payload2 = [
            'amount' => 30000,
            'payment_method' => 'cash',
        ];

        $response2 = $this->actingAs($this->admin)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson("/api/v1/suppliers/{$this->supplier->id}/pay", $payload2);

        $response2->assertStatus(422);
        $response2->assertJsonPath('message', 'Idempotency key payload mismatch');

        $this->assertEquals(1, SupplierPayment::count());
        $this->assertEquals(1, SupplierLedger::where('entry_type', 'PAYMENT')->count());
        $this->assertEquals(90000, $this->supplier->fresh()->current_balance);
    }

    /** @test */
    public function test_customer_overpayment_protection()
    {
        // 1. Attempt payment exceeding customer debt (balance is 100,000, try paying 100,001)
        $payloadOver = [
            'customer_id' => $this->customer->id,
            'amount' => 100001,
            'payment_method' => 'CASH',
        ];

        $responseOver = $this->actingAs($this->admin)->postJson('/api/v1/payments', $payloadOver);
        $responseOver->assertStatus(422);
        $responseOver->assertJsonValidationErrors('amount');

        // Customer balance remains untouched
        $this->assertEquals(100000, $this->customer->fresh()->current_balance);
        $this->assertEquals(0, CustomerPayment::count());

        // 2. Attempt payment when customer has 0 balance
        $this->customer->update(['current_balance' => 0]);
        $responseZeroBalance = $this->actingAs($this->admin)->postJson('/api/v1/payments', [
            'customer_id' => $this->customer->id,
            'amount' => 5000,
            'payment_method' => 'CASH',
        ]);
        $responseZeroBalance->assertStatus(422);
        $responseZeroBalance->assertJsonValidationErrors('amount');

        // 3. Linked Sales Order Overpayment Protection
        $this->customer->update(['current_balance' => 100000]);
        $warehouse = Warehouse::create(['name' => 'W1', 'is_main' => true]);
        $salesOrder = SalesOrder::create([
            'order_number' => 'SO-OVERPAY-1',
            'customer_id' => $this->customer->id,
            'salesman_id' => $this->admin->id,
            'warehouse_id' => $warehouse->id,
            'order_date' => now()->toDateString(),
            'status' => 'DELIVERED',
            'subtotal' => 20000,
            'total_amount' => 20000,
            'created_by' => $this->admin->id,
        ]);

        // Partial payment of 15,000 on this order (succeeds)
        $responsePartial = $this->actingAs($this->admin)->postJson('/api/v1/payments', [
            'customer_id' => $this->customer->id,
            'sales_order_id' => $salesOrder->id,
            'amount' => 15000,
            'payment_method' => 'CASH',
        ]);
        $responsePartial->assertStatus(201);

        // Attempting to pay 5,001 on this order (remaining is 5,000) must be rejected!
        $responseOrderOver = $this->actingAs($this->admin)->postJson('/api/v1/payments', [
            'customer_id' => $this->customer->id,
            'sales_order_id' => $salesOrder->id,
            'amount' => 5001,
            'payment_method' => 'CASH',
        ]);
        $responseOrderOver->assertStatus(422);
        $responseOrderOver->assertJsonValidationErrors('amount');
    }

    /** @test */
    public function test_supplier_overpayment_protection()
    {
        // 1. Attempt payment exceeding supplier debt (balance is 100,000, try paying 100,001)
        $payloadOver = [
            'amount' => 100001,
            'payment_method' => 'cash',
        ];

        $responseOver = $this->actingAs($this->admin)->postJson("/api/v1/suppliers/{$this->supplier->id}/pay", $payloadOver);
        $responseOver->assertStatus(422);
        $responseOver->assertJsonValidationErrors('amount');

        // Supplier balance remains untouched
        $this->assertEquals(100000, $this->supplier->fresh()->current_balance);
        $this->assertEquals(0, SupplierPayment::count());

        // 2. Attempt payment when supplier has 0 balance
        $this->supplier->update(['current_balance' => 0]);
        $responseZeroBalance = $this->actingAs($this->admin)->postJson("/api/v1/suppliers/{$this->supplier->id}/pay", [
            'amount' => 5000,
            'payment_method' => 'cash',
        ]);
        $responseZeroBalance->assertStatus(422);
        $responseZeroBalance->assertJsonValidationErrors('amount');

        // 3. Linked Purchase Order Overpayment Protection
        $this->supplier->update(['current_balance' => 100000]);
        $warehouse = Warehouse::create(['name' => 'W1', 'is_main' => true]);
        $po = PurchaseOrder::create([
            'order_number' => 'PO-OVERPAY-1',
            'supplier_id' => $this->supplier->id,
            'warehouse_id' => $warehouse->id,
            'status' => 'CONFIRMED',
            'total_amount' => 30000,
            'created_by' => $this->admin->id,
        ]);

        // Partial payment of 20,000 on this PO (succeeds)
        $responsePartial = $this->actingAs($this->admin)->postJson("/api/v1/suppliers/{$this->supplier->id}/pay", [
            'purchase_order_id' => $po->id,
            'amount' => 20000,
            'payment_method' => 'cash',
        ]);
        $responsePartial->assertStatus(200);

        // Attempting to pay 10,001 on this PO (remaining is 10,000) must be rejected!
        $responsePoOver = $this->actingAs($this->admin)->postJson("/api/v1/suppliers/{$this->supplier->id}/pay", [
            'purchase_order_id' => $po->id,
            'amount' => 10001,
            'payment_method' => 'cash',
        ]);
        $responsePoOver->assertStatus(422);
        $responsePoOver->assertJsonValidationErrors('amount');
    }

    /** @test */
    public function test_invalid_zero_and_negative_payment_amounts()
    {
        // Customer payment with 0
        $payloadZero = [
            'customer_id' => $this->customer->id,
            'amount' => 0,
            'payment_method' => 'CASH',
        ];

        $responseZero = $this->actingAs($this->admin)->postJson('/api/v1/payments', $payloadZero);
        $responseZero->assertStatus(422);

        // Supplier payment with negative amount
        $payloadNegative = [
            'amount' => -100,
            'payment_method' => 'cash',
        ];

        $responseNegative = $this->actingAs($this->admin)->postJson("/api/v1/suppliers/{$this->supplier->id}/pay", $payloadNegative);
        $responseNegative->assertStatus(422);
    }

    /** @test */
    public function test_transaction_rollback_on_failure()
    {
        $this->customer->update(['current_balance' => 50000]);

        try {
            DB::transaction(function () {
                $customer = Customer::lockForUpdate()->find($this->customer->id);
                $customer->update(['current_balance' => 40000]);

                // Throw an exception to simulate failure
                throw new \Exception("Simulated Database Crash");
            });
        } catch (\Exception $e) {
            $this->assertEquals("Simulated Database Crash", $e->getMessage());
        }

        // Verify balance has rolled back and remains untouched
        $this->assertEquals(50000, $this->customer->fresh()->current_balance);
    }

    /** @test */
    public function test_supplier_balance_and_idempotent_payment_updates()
    {
        $idempotencyKey = 'supplier-pay-idemp-key-555';
        $payload = [
            'amount' => 3000,
            'payment_method' => 'cash',
            'notes' => 'Supplier Payment Test'
        ];

        // 1. First submission
        $response1 = $this->actingAs($this->admin)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson("/api/v1/suppliers/{$this->supplier->id}/pay", $payload);
        $response1->assertStatus(200);

        // Balance should decrease from 100,000 to 97,000
        $this->assertEquals(97000, $this->supplier->fresh()->current_balance);
        $this->assertEquals(1, SupplierPayment::count());
        $this->assertEquals(1, SupplierLedger::where('entry_type', 'PAYMENT')->count());

        // 2. Duplicate payment with same X-Idempotency-Key
        $response2 = $this->actingAs($this->admin)
            ->withHeader('X-Idempotency-Key', $idempotencyKey)
            ->postJson("/api/v1/suppliers/{$this->supplier->id}/pay", $payload);
        $response2->assertStatus(200);
        $response2->assertHeader('X-Cache-Lookup', 'HIT');

        // Assert exactly 1 payment and 1 payment ledger entry exist, balance remains 97,000
        $this->assertEquals(97000, $this->supplier->fresh()->current_balance);
        $this->assertEquals(1, SupplierPayment::count());
        $this->assertEquals(1, SupplierLedger::where('entry_type', 'PAYMENT')->count());
    }

    /** @test */
    public function test_reconciliation_fixing_discrepancies()
    {
        // 1. Customer reconciliation fix
        // Customer ledger has 1 entry with balance_after = 100,000
        $this->customer->update(['current_balance' => 99999]); // Discrepancy introduced
        
        $response = $this->actingAs($this->admin)->postJson("/api/v1/customers/{$this->customer->id}/reconcile?fix=true");
        $response->assertStatus(200);
        $response->assertJsonPath('data.is_consistent', true);
        $response->assertJsonPath('data.stored_balance', 100000); // Corrected to 100,000
        $this->assertEquals(100000, $this->customer->fresh()->current_balance);

        // 2. Supplier reconciliation fix
        // Supplier ledger has 1 entry with balance_after = 100,000
        $this->supplier->update(['current_balance' => 88888]); // Discrepancy introduced

        $responseSupplier = $this->actingAs($this->admin)->postJson("/api/v1/suppliers/{$this->supplier->id}/reconcile?fix=true");
        $responseSupplier->assertStatus(200);
        $responseSupplier->assertJsonPath('data.is_consistent', true);
        $responseSupplier->assertJsonPath('data.stored_balance', 100000); // Corrected to 100,000
        $this->assertEquals(100000, $this->supplier->fresh()->current_balance);
    }

    /** @test */
    public function test_mismatched_order_associations_fail_validation()
    {
        // 1. Create a second customer
        $route = \App\Models\Route::first();
        $otherCustomer = Customer::create([
            'route_id' => $route->id,
            'name' => 'Other Customer',
            'price_type' => 'N1',
            'current_balance' => 50000,
            'is_active' => true,
        ]);

        // Create warehouse and sales order for other customer
        $warehouse = Warehouse::create(['name' => 'W1', 'is_main' => true]);
        $order = SalesOrder::create([
            'order_number' => 'SO-OTHER-101',
            'customer_id' => $otherCustomer->id,
            'salesman_id' => $this->admin->id,
            'warehouse_id' => $warehouse->id,
            'order_date' => now()->toDateString(),
            'status' => 'DELIVERED',
            'subtotal' => 10000,
            'total_amount' => 10000,
            'created_by' => $this->admin->id,
        ]);

        // Try paying for $this->customer using $otherCustomer's sales_order_id
        $responseCustomer = $this->actingAs($this->admin)->postJson('/api/v1/payments', [
            'customer_id' => $this->customer->id,
            'sales_order_id' => $order->id,
            'amount' => 5000,
            'payment_method' => 'CASH',
        ]);
        $responseCustomer->assertStatus(422);

        // 2. Create a second supplier and purchase order
        $otherSupplier = Supplier::create([
            'name' => 'Other Supplier',
            'created_by' => $this->admin->id,
        ]);
        $po = PurchaseOrder::create([
            'order_number' => 'PO-OTHER-101',
            'supplier_id' => $otherSupplier->id,
            'warehouse_id' => $warehouse->id,
            'status' => 'CONFIRMED',
            'total_amount' => 20000,
            'created_by' => $this->admin->id,
        ]);

        // Try paying $this->supplier using $otherSupplier's purchase_order_id
        $responseSupplier = $this->actingAs($this->admin)->postJson("/api/v1/suppliers/{$this->supplier->id}/pay", [
            'amount' => 5000,
            'purchase_order_id' => $po->id,
        ]);
        $responseSupplier->assertStatus(422);
    }
}
