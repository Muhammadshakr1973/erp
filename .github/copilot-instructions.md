# GARDI — Global Instructions for GitHub Copilot

## 1. Core Rule

You are working on the GARDI project.

Your highest priority is:

**Do exactly what the user requested, nothing more and nothing less.**

Do not expand the task, redesign unrelated parts, refactor unrelated code, add extra features, or modify files that are not necessary for the requested task.

The user's request defines the scope of the work.

---

## 2. Scope Control — VERY IMPORTANT

Before making any change, determine:

1. What exactly did the user ask for?
2. Which files are actually required?
3. Which part of the application is affected?
4. What is the smallest safe change that solves the request?

Then work only inside that scope.

### Strict rule:

**Do not touch unrelated code.**

Do not:

* refactor unrelated files
* rename unrelated variables/classes/files
* change architecture without being asked
* change database structure unless required
* change APIs unless required
* change business logic outside the requested feature
* change UI screens unrelated to the request
* update packages/dependencies unless necessary
* remove existing functionality
* "clean up" unrelated code
* improve things that the user did not ask for

A working existing feature is not a reason to modify it.

---

## 3. Design/UI Requests

When the user's request is only about:

* UI
* UX
* layout
* spacing
* colors
* typography
* icons
* buttons
* animations
* responsive behavior
* visual appearance

then:

**Work only on the design/UI layer required for that request.**

Do NOT unnecessarily modify:

* backend
* API
* database
* authentication
* business logic
* models
* services
* unrelated screens
* unrelated widgets/components

If the requested visual change can be completed without changing application logic, do not change application logic.

### Example

If the user says:

"Make the login page look better."

Do not redesign the entire application.

Do not change authentication logic.

Do not modify database code.

Do not change unrelated screens.

Only improve the login page and the minimum related UI code required.

---

## 4. Functional Requests

When the user requests a specific feature or bug fix:

Change only the files and logic necessary to implement that exact feature or fix.

Preserve all existing behavior that is unrelated to the request.

Do not use the task as an opportunity for a general refactor.

---

## 5. Read Before Edit

Before editing code:

* inspect the relevant existing files
* understand the current implementation
* identify the smallest change needed
* preserve existing patterns and architecture

Do not scan the entire repository unnecessarily.

Do not read large amounts of unrelated code when the requested task has a small scope.

Use targeted exploration.

---

## 6. Minimal Change Principle

Always prefer:

**smallest safe change > large rewrite**

If 1 file is enough, do not modify 5 files.

If 10 lines are enough, do not rewrite the whole class.

If an existing component can be reused, reuse it instead of creating a duplicate.

If existing logic already solves part of the problem, extend it instead of replacing it.

---

## 7. Do Not Break Existing Code

Before changing something, consider whether it is currently used elsewhere.

Do not casually remove, rename, or restructure existing code.

Do not break:

* existing routes
* existing APIs
* existing database relationships
* existing navigation
* existing state management
* existing authentication
* existing business rules
* existing UI behavior

Any change must preserve unrelated functionality.

---

## 8. Commands, Builds, Tests, and Tools

Do not run unnecessary commands.

Do not automatically run:

* full builds
* full test suites
* package upgrades
* dependency installation
* database migrations
* formatting across the entire project
* git commands
* deployment commands

unless they are necessary for the user's requested task or explicitly requested by the user.

When validation is needed, use the **smallest relevant validation**.

Example:

If one Flutter screen was changed, do not automatically perform a full project-wide migration or unrelated build process.

---

## 9. Dependencies and Packages

Never add, remove, upgrade, or downgrade a package unless:

1. the user explicitly requested it, or
2. it is genuinely required to complete the requested task.

Prefer existing packages already used by the project.

Do not introduce a new dependency for something that can reasonably be implemented with the existing codebase.

---

## 10. Database and Backend Protection

Do not modify:

* migrations
* database schema
* Laravel models
* controllers
* services
* API endpoints
* authentication
* permissions

when the user's request can be completed without them.

For a frontend-only request, keep the backend untouched.

For a backend-only request, keep unrelated frontend code untouched.

---

## 11. Business Logic Protection

GARDI contains important business rules.

Never invent or change business rules without the user's request.

Do not change:

* prices
* discounts
* debts
* supplier logic
* customer logic
* seller/mandub logic
* commissions
* stock behavior
* invoice behavior
* payment behavior
* permissions

unless the user explicitly asks for that specific change.

---

## 12. User Intent Has Priority

Interpret the user's request literally and within its stated scope.

Do not "improve" the request into something larger.

If the user asks for one thing, solve that one thing.

If the user asks to change one screen, do not change other screens.

If the user asks to fix one bug, do not start refactoring the project.

---

## 13. Avoid Token and Context Waste

Use context efficiently.

Do not repeatedly inspect the same files unless necessary.

Do not dump large files into the response.

Do not explain large amounts of unrelated code.

Do not generate unnecessary code.

Do not investigate unrelated errors unless they block the requested task.

Focus context on:

**request → relevant files → smallest solution → validation**

---

## 14. Existing Architecture

Respect the architecture and technologies already used by GARDI.

Do not replace technologies, patterns, frameworks, libraries, or architecture unless explicitly requested.

Prefer consistency with existing project conventions.

Before introducing a new pattern, check whether the project already has an established pattern for the same purpose.

---

## 15. No Autonomous Refactoring

Do NOT perform autonomous:

* refactoring
* optimization
* cleanup
* modernization
* architecture changes
* code style migrations
* dependency updates
* security rewrites
* performance rewrites

unless they are specifically part of the user's request.

A potential improvement is not permission to implement it.

---

## 16. No Unrequested Fixes

While working, you may notice other bugs or improvements.

Do not fix them automatically.

Only fix the requested issue.

If another issue is important and directly blocks the task, mention it briefly.

Otherwise leave it unchanged.

---

## 17. Before Every Action

Before editing a file or running a command, internally check:

* Is this directly required by the user's request?
* Is this file relevant to the request?
* Is there a smaller way to accomplish the same result?
* Could this affect unrelated functionality?
* Am I doing extra work that the user did not request?

If the answer shows that the action is unnecessary, do not perform it.

---

## 18. Completion Rule

A task is complete when the requested result has been implemented correctly.

Do not continue making additional improvements after the requested task is complete.

Stop.

---

## 19. Response Style

Keep responses concise and practical.

After completing the task, briefly report:

* what was changed
* which relevant files were changed
* whether validation was performed
* any important issue that directly affects the requested task

Do not provide unnecessary explanations.

---

## 20. Absolute Rule

### USER REQUEST = SCOPE

**Do not do more than requested.**

**Do not touch unrelated code.**

**Do not waste tokens.**

**Do not waste commands.**

**Do not waste context.**

**Do not refactor unless asked.**

**Do not modify backend for a UI-only task.**

**Do not modify UI for a backend-only task.**

**Do not modify database unless required.**

**Do not add dependencies unless required.**

**Do not fix unrelated issues.**

**Make the smallest safe change that fully solves the user's request.**
