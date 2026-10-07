---

name: GARDI Laravel Instructions
description: Rules for Laravel backend development in the GARDI project.
applyTo: "app/**/*.php,routes/**/*.php,database/**/*.php,config/**/*.php,bootstrap/**/*.php"
--------------------------------------------------------------------------------------------

# GARDI — Laravel Instructions

## 1. Scope

These instructions apply to the Laravel backend of GARDI.

Work strictly within the user's requested scope.

Do not modify Flutter, Vue, database, deployment, or unrelated files unless the requested backend task genuinely requires it.

---

## 2. Backend Tasks

When the user requests a backend feature or bug fix:

Modify only the backend code required for that exact request.

Preserve existing:

* APIs
* routes
* authentication
* authorization
* business rules
* database relationships
* validation
* responses
* existing functionality

Do not perform unrelated refactoring.

---

## 3. Database Protection

Treat the database structure as protected.

Do NOT modify:

* migrations
* schema
* table structure
* columns
* indexes
* foreign keys
* seeders

unless the user's request specifically requires a database change.

Never create a migration merely because a different database structure might be "better."

---

## 4. Business Logic Protection

GARDI contains important business rules.

Never invent, simplify, or change business behavior without explicit user instruction.

Do not alter rules for:

* customers
* suppliers
* products
* prices
* discounts
* debts
* payments
* invoices
* warehouse stock
* purchasing
* seller/mandub commissions
* permissions

unless that exact rule is part of the user's request.

---

## 5. API Protection

Do not change an existing API contract unnecessarily.

Avoid changing:

* endpoint URLs
* HTTP methods
* request fields
* response structure
* JSON field names
* authentication behavior
* status codes

unless required by the requested task.

When an API change is necessary, keep it as small and backward-compatible as reasonably possible.

---

## 6. Existing Architecture

Follow the existing Laravel architecture and conventions already present in GARDI.

Before creating new code:

1. Find similar existing implementations.
2. Reuse existing services, helpers, models, validation patterns, and response patterns when appropriate.
3. Avoid duplicate logic.

Do not introduce a new architectural pattern without explicit instruction.

---

## 7. Validation and Safety

Do not weaken existing validation.

Do not remove authorization or permission checks.

Do not bypass business rules merely to make a request easier to implement.

Preserve security-sensitive behavior.

---

## 8. Dependencies

Do not modify Composer dependencies unless explicitly requested or genuinely required for the requested task.

Do not upgrade Laravel, PHP packages, or other dependencies as an unrelated improvement.

---

## 9. Commands

Do not automatically run:

* database migrations
* database seeders
* `composer update`
* package installation
* cache clearing
* full test suites
* deployment commands
* Git commands

unless required by the task or explicitly requested.

Never run destructive database commands without explicit authorization.

---

## 10. Unrelated Problems

If another bug, architectural issue, or improvement is discovered:

Do NOT fix it automatically.

Only address it when:

* it directly blocks the requested task, or
* the user explicitly asks for it.

Otherwise leave it unchanged and mention it briefly when necessary.

---

## 11. Minimal Change Principle

Prefer:

small change > large change

existing pattern > new pattern

reuse > duplicate

targeted fix > refactor

Do not rewrite controllers, services, models, or routes unnecessarily.

Do not change multiple layers when one layer is sufficient.

---

## 12. Context and Token Efficiency

Read only the files necessary to understand the requested backend task.

Do not scan the entire Laravel project unnecessarily.

Do not repeatedly inspect unchanged files.

Do not generate large amounts of irrelevant code.

Focus on:

request → relevant backend code → smallest safe change → targeted validation

---

## 13. Completion

When the requested backend change is correctly implemented:

STOP.

Do not continue with cleanup, optimization, refactoring, dependency updates, or unrelated fixes.

The task is complete when the user's requested result is achieved.
