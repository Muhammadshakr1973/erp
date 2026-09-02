<?php

namespace Tests\Feature;

use App\Models\AuditLog;
use App\Models\Customer;
use App\Models\Product;
use App\Models\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class AuditTrailTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
    }

    /**
     * Test that creating an auditable model creates an audit log entry.
     */
    public function test_creating_customer_generates_audit_log(): void
    {
        $adminRole = Role::create([
            'name' => Role::ADMIN,
            'display_name' => 'Admin',
            'permissions' => ['*'],
            'is_system' => true,
        ]);

        $admin = User::create([
            'name' => 'Admin User',
            'phone' => '07501234567',
            'password' => bcrypt('password123'),
            'role_id' => $adminRole->id,
            'is_active' => true,
        ]);

        $this->actingAs($admin);

        $customer = Customer::create([
            'name' => 'Test Customer',
            'phone' => '07509876543',
            'address' => 'Erbil Center',
            'price_tier' => 'RETAIL',
            'credit_limit' => 1000000,
            'current_balance' => 0,
            'is_active' => true,
        ]);

        $this->assertDatabaseHas('audit_logs', [
            'entity_type' => 'Customer',
            'entity_id' => $customer->id,
            'action' => 'CREATE',
            'user_id' => $admin->id,
        ]);
    }

    /**
     * Test that updating an auditable model creates an audit log with old and new values.
     */
    public function test_updating_product_price_records_old_and_new_values(): void
    {
        $adminRole = Role::create([
            'name' => Role::ADMIN,
            'display_name' => 'Admin',
            'permissions' => ['*'],
            'is_system' => true,
        ]);

        $admin = User::create([
            'name' => 'Admin User',
            'phone' => '07501234567',
            'password' => bcrypt('password123'),
            'role_id' => $adminRole->id,
            'is_active' => true,
        ]);

        $this->actingAs($admin);

        $product = Product::create([
            'name' => 'Rice 5KG',
            'sku' => 'RICE-5KG',
            'barcode' => '123456789',
            'cost_price' => 5000,
            'price_n1' => 7000,
            'price_n2' => 6000,
            'price_n3' => 5500,
            'is_active' => true,
        ]);

        $product->update([
            'price_n1' => 8000,
            'price_n2' => 6500,
        ]);

        $log = AuditLog::where('entity_type', 'Product')
            ->where('entity_id', $product->id)
            ->where('action', 'UPDATE')
            ->first();

        $this->assertNotNull($log);
        $this->assertEquals(7000, $log->old_values['price_n1']);
        $this->assertEquals(8000, $log->new_values['price_n1']);
        $this->assertEquals(6000, $log->old_values['price_n2']);
        $this->assertEquals(6500, $log->new_values['price_n2']);
    }

    /**
     * Test that sensitive passwords/tokens are redacted and never stored in audit logs.
     */
    public function test_sensitive_fields_are_redacted_in_audit_logs(): void
    {
        $adminRole = Role::create([
            'name' => Role::ADMIN,
            'display_name' => 'Admin',
            'permissions' => ['*'],
            'is_system' => true,
        ]);

        $admin = User::create([
            'name' => 'Admin User',
            'phone' => '07501234567',
            'password' => bcrypt('password123'),
            'role_id' => $adminRole->id,
            'is_active' => true,
        ]);

        $this->actingAs($admin);

        $newUser = User::create([
            'name' => 'New Driver',
            'phone' => '07501112233',
            'password' => bcrypt('SuperSecretPassword99'),
            'role_id' => $adminRole->id,
            'is_active' => true,
        ]);

        $log = AuditLog::where('entity_type', 'User')
            ->where('entity_id', $newUser->id)
            ->where('action', 'CREATE')
            ->first();

        $this->assertNotNull($log);
        $this->assertEquals('[REDACTED]', $log->new_values['password']);
        $this->assertStringNotContainsString('SuperSecretPassword99', json_encode($log->new_values));
    }

    /**
     * Test that AuditLog records are strictly immutable.
     */
    public function test_audit_logs_are_immutable(): void
    {
        $adminRole = Role::create([
            'name' => Role::ADMIN,
            'display_name' => 'Admin',
            'permissions' => ['*'],
            'is_system' => true,
        ]);

        $admin = User::create([
            'name' => 'Admin User',
            'phone' => '07501234567',
            'password' => bcrypt('password123'),
            'role_id' => $adminRole->id,
            'is_active' => true,
        ]);

        $log = AuditLog::create([
            'action' => 'TEST_ACTION',
            'entity_type' => 'Test',
            'entity_id' => 1,
            'user_id' => $admin->id,
            'description' => 'Original log entry',
        ]);

        $this->expectException(\RuntimeException::class);
        $log->update(['description' => 'Tampered description']);
    }

    /**
     * Test that AuditLog records cannot be deleted.
     */
    public function test_audit_logs_cannot_be_deleted(): void
    {
        $adminRole = Role::create([
            'name' => Role::ADMIN,
            'display_name' => 'Admin',
            'permissions' => ['*'],
            'is_system' => true,
        ]);

        $admin = User::create([
            'name' => 'Admin User',
            'phone' => '07501234567',
            'password' => bcrypt('password123'),
            'role_id' => $adminRole->id,
            'is_active' => true,
        ]);

        $log = AuditLog::create([
            'action' => 'TEST_ACTION',
            'entity_type' => 'Test',
            'entity_id' => 1,
            'user_id' => $admin->id,
            'description' => 'Original log entry',
        ]);

        $this->expectException(\RuntimeException::class);
        $log->delete();
    }

    /**
     * Test query API authorization: non-admin users without permission cannot view audit logs.
     */
    public function test_audit_logs_api_requires_proper_authorization(): void
    {
        $salesmanRole = Role::create([
            'name' => Role::SALESMAN,
            'display_name' => 'Salesman',
            'permissions' => ['orders.create', 'customers.view'],
            'is_system' => true,
        ]);

        $salesman = User::create([
            'name' => 'Sales Representative',
            'phone' => '07504443322',
            'password' => bcrypt('password123'),
            'role_id' => $salesmanRole->id,
            'is_active' => true,
        ]);

        $this->actingAs($salesman);

        $response = $this->getJson('/api/v1/audit-logs');
        $response->assertStatus(403);
    }

    /**
     * Test query API: Admin can filter audit logs by entity and date.
     */
    public function test_admin_can_filter_audit_logs(): void
    {
        $adminRole = Role::create([
            'name' => Role::ADMIN,
            'display_name' => 'Admin',
            'permissions' => ['*'],
            'is_system' => true,
        ]);

        $admin = User::create([
            'name' => 'Admin User',
            'phone' => '07501234567',
            'password' => bcrypt('password123'),
            'role_id' => $adminRole->id,
            'is_active' => true,
        ]);

        AuditLog::create([
            'action' => 'CREATE',
            'entity_type' => 'Customer',
            'entity_id' => 10,
            'user_id' => $admin->id,
            'description' => 'Created customer',
        ]);

        AuditLog::create([
            'action' => 'CREATE',
            'entity_type' => 'Product',
            'entity_id' => 20,
            'user_id' => $admin->id,
            'description' => 'Created product',
        ]);

        $this->actingAs($admin);

        $response = $this->getJson('/api/v1/audit-logs?entity_type=Customer');
        $response->assertStatus(200);
        $response->assertJsonFragment(['entity_type' => 'Customer']);
        $response->assertJsonMissing(['entity_type' => 'Product']);
    }

    /**
     * Test that failed/rolled back transactions do not persist any audit logs.
     */
    public function test_failed_transactions_do_not_persist_audit_logs(): void
    {
        $adminRole = Role::create([
            'name' => Role::ADMIN,
            'display_name' => 'Admin',
            'permissions' => ['*'],
            'is_system' => true,
        ]);

        $admin = User::create([
            'name' => 'Admin User',
            'phone' => '07501234567',
            'password' => bcrypt('password123'),
            'role_id' => $adminRole->id,
            'is_active' => true,
        ]);

        $this->actingAs($admin);

        try {
            \Illuminate\Support\Facades\DB::transaction(function () use ($admin) {
                // This triggers an automatic CREATE audit log
                Customer::create([
                    'name' => 'Should Not Exist',
                    'phone' => '07505555555',
                    'address' => 'Erbil Center',
                    'price_tier' => 'RETAIL',
                    'credit_limit' => 1000000,
                    'current_balance' => 0,
                    'is_active' => true,
                ]);

                throw new \Exception('Simulated database/transaction failure');
            });
        } catch (\Exception $e) {
            $this->assertEquals('Simulated database/transaction failure', $e->getMessage());
        }

        // Verify the customer is not in the database
        $this->assertDatabaseMissing('customers', [
            'name' => 'Should Not Exist',
        ]);

        // Verify that no CREATE audit log for Customer has been persisted
        $this->assertDatabaseMissing('audit_logs', [
            'entity_type' => 'Customer',
            'action' => 'CREATE',
        ]);
    }
}
