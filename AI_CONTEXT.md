# GARDI ERP --- AI Context

## Purpose

GARDI is a wholesale distribution and sales-management ERP for
customers, suppliers, products, sales, purchasing, warehouse, delivery,
payments/debts, commissions and reports. The target system is Offline
First, scalable, secure, and based on Flutter + Laravel + MySQL.

## Technology

-   Flutter / Dart
-   Riverpod
-   Dio
-   go_router
-   Hive / hive_flutter
-   SharedPreferences
-   responsive_builder
-   mobile_scanner
-   flutter_map
-   geolocator
-   qr_flutter
-   Laravel / PHP
-   REST API
-   Laravel Sanctum
-   MySQL / MariaDB
-   Git / GitHub

## Current repository

The current repository contains `backend/`, `lib/`, `test/`, Flutter
configuration, assets/fonts and Laravel API code.

The currently observed `/api/v1` surface includes authentication,
products, categories, routes/salesmen, suppliers, customers, users,
orders, payments, stock transfers, delivery trips, commissions, purchase
orders and reports.

This is the current implementation, not the complete target
specification.

## Target modules

-   Authentication
-   Users / roles / permissions
-   Customers and customer assignments
-   Routes
-   Suppliers
-   Products, categories, brands, units and price tiers
-   Sales orders and order items
-   Discounts
-   Purchase requirements
-   Purchase orders and market purchasing
-   Warehouse stock and stock transactions
-   Stock transfers
-   Packing / ready orders
-   Delivery trips and delivery orders
-   Customer and supplier payments/ledgers
-   Commissions
-   Inventory counts
-   Reports
-   Settings
-   Attachments
-   Notifications
-   Audit logs
-   Offline synchronization

## Important business context

-   Three customer price tiers: n1 cheap, n2 medium, n3 expensive.
-   Sales demand can create purchase requirements when warehouse stock
    is insufficient.
-   Requirements can be grouped by supplier.
-   Permanent customer discounts and invoice-level discounts are
    separate concepts.
-   Historical cost/profit/commission information must remain
    explainable.
-   Routes have customer visit ordering and salesman assignment rules.
-   Financial and inventory history must not be silently destroyed.

## User workflow

The project owner is a beginner in Flutter/Laravel/PHP and uses AI to
implement changes.

Normal workflow:

User request → AI inspects → AI implements → safe static verification →
GitHub → user pulls in VS Code → user runs manually → user tests → user
reports runtime issues

The AI must not replace this workflow with autonomous build/run/fix
loops.

## Source-of-truth order

1.  Explicit user request
2.  Existing GARDI code
3.  `ARCHITECTURE.md`
4.  `BUSINESS_RULES.md`
5.  Project documentation

When documentation and code differ, do not silently invent a resolution.

## Current-vs-target warning

Do not claim a feature is implemented merely because it is documented.
In particular, do not claim Offline Sync, realtime dual-entry, audit
coverage, or every documented screen/API is complete without checking
the repository.

## UI direction

GARDI is Kurdish/RTL. Current project rules include: - Mobile: 1
column - Tablet/iPad: 2 columns - Desktop/Web: 3 columns - RTL-friendly
cards - Do not unnecessarily truncate system text with `...` - Add
action uses a `+` icon in AppBar actions

## AI principle

The AI is an implementation engineer, not an autonomous project manager.

Understand → Inspect → Implement → Safely Verify → Report.
