# GARDI ERP --- Architecture

## 1. Goal

Keep GARDI as one coherent Flutter + Laravel + MySQL ERP. Preserve the
existing architecture unless the user explicitly requests an
architectural change.

## 2. System flow

Flutter UI → Riverpod State → Repository / Service → Dio → Laravel REST
API → Route → Controller → Validation / Business Service → Model /
Relationship → MySQL → JSON Response → Flutter Model → Riverpod → UI

Offline persistence/synchronization is an additional controlled layer,
not a second business-logic system.

## 3. Flutter

The current repository uses a feature-oriented Flutter structure.
Inspect existing folders before adding or moving files.

Conceptually:

``` text
lib/
├── core/
├── features/
│   ├── auth/
│   ├── admin/
│   ├── salesman/
│   ├── customers/
│   ├── products/
│   ├── orders/
│   ├── warehouse/
│   ├── driver/
│   └── shared/
└── main.dart
```

Do not create a competing architecture without an explicit request.

## 4. Flutter responsibilities

Flutter handles presentation, interaction, responsive UI, navigation,
Riverpod state, API communication and local/offline UI state.

Critical business integrity must also be enforced server-side.

## 5. State management

Riverpod is the current state-management approach.

Before creating a provider: 1. Search for an existing provider. 2. Reuse
the established pattern. 3. Avoid duplicate state sources.

## 6. Networking

Dio is the current HTTP client. API changes must keep endpoint, HTTP
method, authentication, request fields, JSON names, types, nullability,
errors and response structure consistent.

API prefix: `/api/v1`.

## 7. Laravel

Conceptual backend:

``` text
backend/
├── app/
│   ├── Http/
│   ├── Models/
│   └── Services/
├── database/
│   ├── migrations/
│   ├── factories/
│   └── seeders/
└── routes/
```

The actual repository structure is authoritative. Inspect it before
adding files.

Controllers coordinate requests/responses. Validation must be explicit.
Complex business rules belong in appropriate backend/service layers.

## 8. Database safety

Before database changes inspect migrations, models, relationships,
foreign keys and indexes.

Never silently: - drop tables - delete business history - drop important
columns - remove relationships - destroy financial/inventory history

## 9. Inventory

The project documentation requires every important stock movement to
create an inventory transaction.

Target movement types include: - PURCHASE - SALE - ADJUSTMENT - RETURN -
RESERVE - RELEASE

Do not overwrite stock in a way that destroys movement history.

## 10. Finance

Customer and supplier money movements must remain traceable through
payment/ledger records.

Do not rely on a mutable balance alone when historical explanation is
required.

## 11. Sales

Target flow: Customer → price tier → products → cart → permanent
discount → invoice discount → total → order → status/history →
fulfillment → delivery/payment

Target statuses documented by the project include DRAFT, CONFIRMED,
PACKING, READY, DELIVERED and CANCELLED. Verify current implementation
before using them.

## 12. Purchase

Target flow: Sales demand → purchase requirement → supplier grouping →
purchase order → receiving → stock transaction → warehouse stock

## 13. Delivery

Target flow: Ready orders → delivery trip → delivery sequence → customer
delivery → receiver/signature/attachment when applicable → payment
collection → customer ledger

Do not duplicate payment business logic in unrelated places.

## 14. Offline

Target documentation specifies Hive-based local order storage, an
unsynced/pending state and a synchronization queue.

Do not declare Offline First complete without implementation evidence.

## 15. Dual-entry

The target workflow describes iPad + salesman mobile use of the same
order. Shared editing requires safe shared identity and
synchronization/realtime behavior.

Do not invent WebSocket/realtime architecture unless requested or
already present.

## 16. Routing

go_router is the current routing approach. Inspect the existing router
before adding routes. Preserve authentication, role and permission
behavior.

## 17. Responsive UI

Use the existing responsive utilities/patterns. Target layout
guidance: - Mobile: 1 column - Tablet/iPad: 2 columns - Desktop/Web: 3
columns

## 18. Reuse

Before creating a widget, provider, repository, service, model,
controller or API method, search for an existing implementation and
reuse the established pattern.

## 19. API feature changes

When a feature affects the API, verify the complete affected chain: UI →
State → Repository/Service → API → Laravel → Database → Response → Model
→ UI.

Only modify layers actually required.

## 20. Git and verification

Never use destructive Git operations automatically. Do not reset hard,
clean user work, force push, rewrite history or delete branches.

Do not automatically build or run the application. Safe verification is
static inspection unless the user explicitly asks for runtime execution.
