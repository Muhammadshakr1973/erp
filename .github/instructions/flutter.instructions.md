---

name: GARDI Flutter Instructions
description: Rules for Flutter application development in the GARDI project.
applyTo: "pos_app/**"
---------------------

# GARDI — Flutter Instructions

## 1. Scope

These instructions apply only to the Flutter application under `pos_app/`.

Work strictly within the user's requested scope.

Do not modify Laravel, database, API, hosting, or unrelated project files unless the requested Flutter task genuinely requires it.

---

## 2. UI / Design Tasks

When the user asks for a UI or design change:

ONLY modify the UI/design code necessary for that request.

This includes:

* layout
* spacing
* padding and margins
* colors
* typography
* icons
* buttons
* cards
* dialogs
* navigation appearance
* responsive layout
* animations
* visual polish

Do NOT change:

* API logic
* authentication
* database logic
* business rules
* models
* repositories
* services
* providers/state management
* backend code

unless the visual task cannot reasonably be completed without such a change.

### Example

If the user asks:

"Change the customer screen design."

Do not change:

* customer API
* customer database
* customer business logic
* invoice logic
* authentication

Only change the customer screen's relevant Flutter UI.

---

## 3. Functional Tasks

For a functional request:

Modify only the minimum Flutter code necessary to implement the requested behavior.

Preserve all unrelated existing behavior.

Do not refactor the surrounding code unless explicitly requested.

---

## 4. Existing Architecture

Follow the existing architecture and coding patterns already used in `pos_app`.

Before creating something new:

1. Search for an existing reusable widget, service, provider, utility, or pattern.
2. Reuse it when appropriate.
3. Do not create duplicate implementations unnecessarily.

Do not introduce a new architecture or state-management approach unless explicitly requested.

---

## 5. Android Protection

Treat `pos_app/android/**` as protected.

Do NOT modify:

* Gradle files
* AndroidManifest.xml
* Kotlin files
* Java files
* Android embedding configuration
* SDK configuration
* build configuration

unless the user's request specifically requires an Android/build change.

Never change Android configuration merely because you noticed something that "could be improved."

---

## 6. Dependencies

Do not add, remove, upgrade, or downgrade Flutter packages unless:

* the user explicitly requests it, or
* the requested feature genuinely cannot be implemented using the existing dependencies.

Prefer the packages already used by GARDI.

---

## 7. Minimal Changes

Always prefer the smallest safe change.

If one widget can solve the problem, do not redesign the screen.

If one screen can solve the problem, do not modify the whole application.

If one file is enough, do not change multiple files.

Do not rewrite working code unnecessarily.

---

## 8. Commands

Do not run unnecessary commands.

Do not automatically run:

* `flutter clean`
* `flutter pub upgrade`
* package installation
* full builds
* full test suites
* code generation
* Git commands

unless required by the requested task or explicitly requested by the user.

When validation is useful, use the smallest relevant validation.

---

## 9. Unrelated Issues

If you discover another bug or possible improvement while working:

Do NOT fix it automatically.

Leave it unchanged unless:

* it directly blocks the requested task, or
* the user explicitly asks for it.

Mention important blockers briefly.

---

## 10. Context and Token Efficiency

Do not read the entire Flutter project when the task is local.

Inspect only the relevant files and their necessary dependencies.

Avoid repeatedly reading the same files.

Avoid generating unnecessary code or explanations.

Use:

request → relevant files → smallest solution → targeted validation

---

## 11. Completion

When the requested change is complete:

STOP.

Do not continue with additional refactoring, optimization, cleanup, redesign, or "nice-to-have" improvements.

The task is complete when the user's requested result is achieved.
