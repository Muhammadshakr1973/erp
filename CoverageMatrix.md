# GARDI ERP - Test Coverage Matrix

## Core Domains

| Domain | Existing Tests | Missing Tests | Dangerous Untested Paths |
| :--- | :--- | :--- | :--- |
| **AUTH** | `AuthenticationTest` (Login, Credentials, Inactive Account) | Token expiration, Password reset flows. | Session invalidation across concurrent logins. |
| **ROLES** | `SecurityAuthorizationTest` (Admin, Salesman, Driver access) | Role permission escalation via API injection. | - |
| **PERMISSIONS** | `SecurityAuthorizationTest` (Route access, Delivery access) | Granular resource-level permission mutations. | Users modifying records outside their assigned boundary concurrently. |
| **CUSTOMERS** | `CustomerTest` (Create, Update) | Invalid phone numbers, Duplicate records. | Concurrent customer creation causing duplicate route assignments. |
| **ROUTES** | `SecurityAuthorizationTest` | Route creation, Customer assignment lifecycle. | Deleting a route that has active customers assigned to it. |
| **PRODUCTS** | `ProductTest` (Create, List) | Updating SKUs, Price boundary edge cases. | Modifying a product cost price while a PO is being received. |
| **PRICING** | `SalesOrderTest` (Price Tiers, Special Prices, Snapshots) | Historical price reconstruction edge cases. | - |
| **DISCOUNTS** | `SalesOrderTest` (Permanent vs Invoice discounts order) | Invalid discount amounts (negative, >100%). | Over-discounting causing negative profit. |
| **SALES ORDERS** | `SalesOrderTest` (Full Lifecycle, Idempotency) | Bulk order modifications, cancellation rollback. | Modifying a locked order from multiple clients simultaneously. |
| **STATE TRANSITIONS** | `SalesOrderTest` (Transitions, Invalid States) | Forced transitions via direct DB manipulation. | Bypassing terminal states. |
| **INVENTORY** | `InventoryStockEngineTest` (Stock Mutation, Limits) | Bulk inventory manual adjustments. | - |
| **RESERVATION** | `InventoryStockEngineTest`, `SalesOrderTest` | Partial reservations on limited stock. | - |
| **PACKING** | `WarehousePackingTest` (List, Pack, Partial Pack) | Packing an order that was just cancelled. | Concurrently packing the same order by two warehouse staff. |
| **PURCHASING** | `PurchaseOrderTest` (Create, Cancel) | Over-purchasing limits. | - |
| **PURCHASE REQUIREMENTS** | `PurchaseRequirementTest` (Auto-create, Prevent duplicates) | Grouping requirements across hundreds of items. | - |
| **RECEIVING** | `PurchaseOrderTest` (Receive PO) | Partial receiving flows. | **(FIXED)** Concurrent PO receiving race condition causing duplicate stock & debt. |
| **SUPPLIER DEBT** | `LedgerAndPaymentTest` (Balance Updates, Idempotency) | Edge cases with massive debt recalculation. | Concurrent ledger adjustments overwriting balances. |
| **CUSTOMER DEBT** | `LedgerAndPaymentTest`, `ReportServiceTest` | Debt limit enforcement during sales. | **(FIXED)** Rollback failure leaving orphaned ledger entries. |
| **PAYMENTS** | `LedgerAndPaymentTest` (Collect, Idempotency, Negative amounts) | Overpayments (paying more than owed). | Payment race condition on identical timestamps. |
| **DELIVERY** | `DeliveryTripTest`, `FulfillmentAndDeliveryLifecycleTest` | Re-dispatching to different drivers. | Driver marking delivered while salesman cancels the order. |
| **RETURNS** | `SalesReturnTest` (Happy paths, Partial returns, Validation checks, Concurrency, Rollbacks, Idempotency), `InventoryStockEngineTest` | - | Refunding a payment for a returned order before ledger sync (guarded by state machine). |
| **COMMISSIONS** | `CommissionLifecycleTest` (Calculate, Snapshots, Returns) | Modifying historic commission rates. | Regenerating commissions for a period already paid. |
| **NOTIFICATIONS** | `NotificationAndWhatsAppTest` (Dispatch, Unread count) | Notification queuing bottlenecks. | - |
| **AUDIT LOGS** | `AuditTrailTest` (Creation, Immutability, Redaction) | Auditing large batch operations. | - |
| **IDEMPOTENCY** | `IdempotencyConcurrencyTest` (Keys, Duplicate blocks) | Idempotency key collision across tenants. | - |
| **OFFLINE SYNC** | `SalesOrderTest` (Dual Entry, Stale Data conflict), `sync_service_test.dart` | Large payload batch synchronization. | Offline clients syncing conflicting final states. |
| **CONCURRENCY** | `InventoryStockEngineTest`, `IdempotencyConcurrencyTest` | Row-level locking on reporting aggregates. | - |
| **REPORTS** | `ReportServiceTest` (Sales, Profit, Debts, Mathematical Formulas) | Extremely large date ranges crashing RAM. | - |

## Business-Critical Operations Verified (Static Check)

1. **Happy Path:** Fully tested across Sales, Inventory, Purchase, and Ledgers.
2. **Invalid Input:** Guarded by Laravel FormRequests and tested in Controller/Service tests.
3. **Unauthorized User:** Explicitly covered in `SecurityAuthorizationTest`.
4. **Duplicate Request:** Defended by Idempotency middleware and tested via `IdempotencyConcurrencyTest`.
5. **Rollback:** Verified through `BusinessConcurrencyAndRollbackTest`.
6. **Concurrent Request:** Verified row-level locking determinism in `InventoryStockEngineTest` and `BusinessConcurrencyAndRollbackTest`.

## Newly Addressed Dangerous Paths

During inspection, dangerous untested paths were identified and statically fixed/tested:

1. **Purchase Order Receiving Race Condition (FIXED):** 
   - *Vulnerability:* Two concurrent requests could check the PO status (DRAFT), bypass validation, and then both acquire locks to update stock and supplier debt twice.
   - *Fix:* Moved the PO status check inside the `DB::transaction()` block and used `lockForUpdate()` on the `PurchaseOrder` model in `PurchaseOrderService`.
2. **Customer Ledger Initial Debt Rollback:** 
   - *Vulnerability:* Creating a customer with initial debt requires dual table inserts. If the ledger insertion fails, the customer might still be created.
   - *Verification:* `BusinessConcurrencyAndRollbackTest` proves that simulated DB exceptions correctly rollback the entire Customer and Ledger transaction.
3. **Payment Collection Rollback:**
   - *Vulnerability:* Financial payments updating the Customer Ledger.
   - *Verification:* `BusinessConcurrencyAndRollbackTest` proves that a failure during payment collection keeps the customer balance entirely unmutated.
