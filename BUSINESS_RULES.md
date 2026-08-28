# GARDI ERP --- Business Rules

## 1. Purpose

These rules describe intended GARDI business behavior. Do not casually
change them.

When documentation and current implementation differ, verify the code
before claiming that a rule is already enforced.

## 2. Customers

Customers may have: - name/shop information - contact information -
location/address - price tier - debt/ledger history - route assignment -
permanent discount - order history - payment history - restock/request
history

Customer financial history must remain traceable.

## 3. Price tiers

Three target tiers: - n1 = cheap / large customers - n2 = medium - n3 =
expensive / normal

Sales should use the customer's applicable price tier unless an
authorized override is explicitly supported.

Do not hard-code tier prices in Flutter.

## 4. Discounts

Two distinct concepts: 1. Permanent customer discount 2. Temporary
invoice/order discount

Invoice discount supports PERCENT or FIXED in the target documentation.

Do not merge these concepts into one field.

## 5. Sales orders

Target flow: Select customer → load price tier → load products/prices →
add items → subtotal → permanent discount → invoice discount → final
total → order

Preserve the historical values needed to reproduce the financial result.

## 6. Profit and cost

Target formula: `profit = (selling_price - cost_price) × quantity`

Historical cost should be preserved at the appropriate transaction/order
time. Do not recalculate old profit using today's cost if the historical
cost was already established.

## 7. Commission

Commission is based on profit. Historical commission information must
remain stable and explainable.

A later commission-rate change must not silently rewrite old commission
results.

## 8. Customer payments/debt

Target flow: Customer payment → payment record → customer ledger →
balance impact

Do not overwrite debt without preserving the reason/history of the
change.

## 9. Supplier payments/debt

Target flow: Supplier purchase/debt → supplier ledger → supplier payment
→ updated balance

Supplier financial history must remain traceable.

## 10. Inventory

Every important stock movement must be traceable through a stock
transaction.

Target movement types: - PURCHASE - SALE - ADJUSTMENT - RETURN -
RESERVE - RELEASE

A stock adjustment requires a reason.

## 11. Purchase requirements

When an order requires more product than available warehouse stock:
required quantity → compare with stock → missing quantity → purchase
requirement → supplier grouping → purchase order

Avoid duplicate requirements for the same demand.

## 12. Warehouse

Target fulfillment flow: CONFIRMED → PACKING → READY → delivery

Packing should remain associated with the correct customer/order.

## 13. Delivery

Target trip statuses: - PREPARING - ON_THE_WAY - COMPLETED

Delivery can include address/map, amount to collect, receiver name,
signature and attachments.

Collected payment must connect to customer payment/ledger behavior.

## 14. Routes and salesmen

Current GARDI README rule: - One salesman can have multiple routes. - A
route cannot have more than one salesman under the stated rule.

The broader documentation also describes customer visit order and
salesman assignment date ranges.

Do not silently change this relationship rule.

## 15. Roles and permissions

Permissions must be consistent across UI and server.

Examples in the target documentation include: - `view_profit` -
`edit_price` - order permissions - module permissions

Sensitive information must not be protected only by hiding it in
Flutter.

## 16. Historical integrity

Core master rules: - Never hard-delete financial or inventory history. -
Every stock movement creates an inventory transaction. - Every money
movement creates a ledger transaction.

## 17. Audit

The target documentation includes audit logs for important actions.
Where implemented, preserve user, entity/table, record, action,
timestamp and relevant request/device information.

Do not claim complete audit coverage without checking implementation.

## 18. Offline

Target behavior: - Save required orders locally when offline. - Mark
pending/unsynced state. - Sync when online. - Show sync status. -
Prevent duplicate submissions. - Handle conflicts safely.

Do not blindly overwrite server data during synchronization.

## 19. Dual-entry

The target design allows iPad/customer-side entry and salesman mobile
entry for the same order/invoice.

This requires a shared order identity and safe synchronization/realtime
behavior.

Do not create two independent orders when the business requirement is
one shared order.

## 20. UI business rules

Current GARDI README rules: - Mobile: one column - Tablet/iPad: two
columns - Desktop/Web: three columns - System text should not be
unnecessarily hidden with `...`; allow smaller text or multiple lines. -
Add action uses a `+` icon in AppBar actions.

## 21. Rule-change policy

If a user request requires changing one of these business rules: 1.
Identify the affected rule. 2. Explain the impact briefly. 3. Implement
only when the user's request clearly authorizes the change.

## 22. Important distinction

Some rules in this document are target requirements from the project
documentation; others are already visible in the current repository.

Always inspect the current code before assuming that a target rule is
implemented.
