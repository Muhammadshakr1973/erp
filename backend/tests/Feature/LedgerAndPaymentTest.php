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

        // Create customer
        $this->customer = Customer::create([
            'route_id' => $route->id,
            'name' => 'Test Customer',
            'price_type' => 'N1',
            'current_balance' => 0,
            'is_active' => true,
        ]);

        // Create supplier
        $this->supplier = Supplier::create([
            'name' => 'Test Supplier',
            'phone' => '123456789',
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

        // Assert ledger entries
        $ledger = CustomerLedger::first();
        $this->assertNotNull($ledger);
        $this->assertEquals('PAYMENT', $ledger->entry_type);
        $this->assertEquals('credit', $ledger->type);
        $this->assertEquals(0, $ledger->balance_before);
        $this->assertEquals(-5000, $ledger->balance_after);

        // Historical Consistency - Immutability of ledger entries
        $this->assertFalse($ledger->update(['amount' => 9999]));
        $this->assertFalse($ledger->delete());
        
        $this->assertEquals(5000, CustomerLedger::first()->amount); // Remains original
    }

    /** @test */
    public function test_multiple_transactions_sequence()
    {
        $paymentService = app(PaymentService::class);

        // First payment
        $paymentService->collectPayment([
            'customer_id' => $this->customer->id,
            'amount' => 10000,
            'payment_method' => 'CASH',
        ], $this->admin);

        // Second payment
        $paymentService->collectPayment([
            'customer_id' => $this->customer->id,
            'amount' => 4000,
            'payment_method' => 'CASH',
        ], $this->admin);

        $ledgers = CustomerLedger::orderBy('id', 'asc')->get();
        $this->assertCount(2, $ledgers);

        // First entry asserts
        $this->assertEquals(0, $ledgers[0]->balance_before);
        $this->assertEquals(-10000, $ledgers[0]->balance_after);

        // Second entry asserts
        $this->assertEquals(-10000, $ledgers[1]->balance_before);
        $this->assertEquals(-14000, $ledgers[1]->balance_after);

        $this->assertEquals(-14000, $this->customer->fresh()->current_balance);

        // Test reconciliation matches perfectly
        $reconciliation = $this->customer->fresh()->reconcileBalance();
        $this->assertTrue($reconciliation['is_consistent']);
        $this->assertEquals(-14000, $reconciliation['stored_balance']);
        $this->assertEquals(-14000, $reconciliation['recalculated_balance']);
        $this->assertEmpty($reconciliation['discrepancies']);
    }

    /** @test */
    public function test_duplicate_requests_prevention_idempotency()
    {
        // Simulate two identical payments in very quick succession
        $payload = [
            'customer_id' => $this->customer->id,
            'amount' => 15000,
            'payment_method' => 'CASH',
            'notes' => 'Idempotent Payment Check',
        ];

        $response1 = $this->actingAs($this->admin)->postJson('/api/v1/payments', $payload);
        $response1->assertStatus(201);

        $response2 = $this->actingAs($this->admin)->postJson('/api/v1/payments', $payload);
        $response2->assertStatus(201); // Standard flow returns 201 for idempotent payment hit

        // Assert only one ledger entry was created
        $this->assertEquals(1, CustomerLedger::count());
        $this->assertEquals(1, CustomerPayment::count());
    }

    /** @test */
    public function test_invalid_zero_and_negative_payment_amounts()
    {
        // Customer payment
        $payloadZero = [
            'customer_id' => $this->customer->id,
            'amount' => 0,
            'payment_method' => 'CASH',
        ];

        $responseZero = $this->actingAs($this->admin)->postJson('/api/v1/payments', $payloadZero);
        $responseZero->assertStatus(422);

        // Supplier payment
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
    public function test_supplier_balance_and_payment_updates()
    {
        // 1. Initially balance is 0
        $this->assertEquals(0, $this->supplier->fresh()->current_balance);

        // 2. Perform a payment
        $payload = [
            'amount' => 3000,
            'payment_method' => 'cash',
            'notes' => 'Supplier Payment Test'
        ];

        $response = $this->actingAs($this->admin)->postJson("/api/v1/suppliers/{$this->supplier->id}/pay", $payload);
        $response->assertStatus(200);

        // Balance should decrease by 3000 (meaning -3000)
        $this->assertEquals(-3000, $this->supplier->fresh()->current_balance);

        // 3. Duplicate payment check (Idempotency)
        $responseDuplicate = $this->actingAs($this->admin)->postJson("/api/v1/suppliers/{$this->supplier->id}/pay", $payload);
        $responseDuplicate->assertStatus(200);

        // Because of idempotency within 90 seconds, only 1 ledger and 1 payment entry should exist, and balance remains -3000
        $this->assertEquals(-3000, $this->supplier->fresh()->current_balance);
        $this->assertEquals(1, SupplierLedger::where('supplier_id', $this->supplier->id)->count());
    }

    /** @test */
    public function test_reconciliation_fixing_discrepancies()
    {
        // 1. Customer reconciliation fix
        // Manually introduce discrepancy
        $this->customer->update(['current_balance' => 99999]); // Doesn't match ledger (which has 0)
        
        $response = $this->actingAs($this->admin)->postJson("/api/v1/customers/{$this->customer->id}/reconcile?fix=true");
        $response->assertStatus(200);
        $response->assertJsonPath('data.is_consistent', true);
        $response->assertJsonPath('data.stored_balance', 0); // Corrected to 0
        $this->assertEquals(0, $this->customer->fresh()->current_balance);

        // 2. Supplier reconciliation fix
        // Manually introduce discrepancy
        $this->supplier->update(['current_balance' => 88888]); // Doesn't match ledger (which has 0)

        $responseSupplier = $this->actingAs($this->admin)->postJson("/api/v1/suppliers/{$this->supplier->id}/reconcile?fix=true");
        $responseSupplier->assertStatus(200);
        $responseSupplier->assertJsonPath('data.is_consistent', true);
        $responseSupplier->assertJsonPath('data.stored_balance', 0); // Corrected to 0
        $this->assertEquals(0, $this->supplier->fresh()->current_balance);
    }
}
