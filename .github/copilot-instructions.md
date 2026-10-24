# GARDI ERP — Compact Coding Instructions

## ROLE & PROJECT
Act as the coding engineer for the EXISTING GARDI ERP.
Stack: Laravel/PHP + MySQL backend, Flutter/Dart frontend, REST API.
The repository is the implementation source of truth; the user's latest explicit requirement is the business authority. This is NOT a new project.

## 1. TASK SCOPE
- Act only on a clear user request. Never make unsolicited changes.
- Change only what is needed to complete the requested task; do not add side tasks, cleanup, refactoring, redesign, or dependency updates.
- If the user asks for design/UI only, change UI only unless another change is essential for that UI to work.
- If an ambiguity could affect money, data, security, permissions, architecture, or multiple modules, ask one focused question before making that risky choice. Otherwise choose the smallest reasonable solution.

## 2. INSPECT, THEN EDIT
- Before editing, read/search the relevant existing files and follow the real project patterns. Never guess file locations, architecture, API fields, or business logic.
- For simple changes, inspect only the relevant area. For cross-stack or high-risk work, trace the affected flow through Flutter → API → Laravel → database and back, using the architecture that actually exists.
- Make the smallest safe change that fully meets the request. Reuse existing widgets, services, state management, validation, and dependencies.
- Do not replace architecture, frameworks, state management, navigation, or API structure without explicit approval.
- Do not change package versions or add packages unless genuinely required after checking existing functionality.

## 3. CRITICAL: CODE ONLY — DO NOT RUN THE APP
The user will run and verify the project manually.
- Edit code only. Do NOT launch/run Flutter or the backend; do NOT build, compile, or run tests; do NOT install packages; and do NOT execute terminal commands or scripts to validate the project.
- Do not claim a build, test, run, or compilation succeeded. Clearly state that execution/testing was not performed because the user handles it.
- You may inspect source files and review the changed code without executing it.

## 4. PRESERVE THE EXISTING SYSTEM
- Prefer patch/extend/reuse over rewrite/replace.
- Do not modify unrelated files or change existing UX/business behavior without a requirement.
- Preserve existing routes, API contracts, field names, response formats, nullability, permissions, localization, navigation, and responsive behavior unless the task requires a deliberate change.
- For API changes, inspect and update all directly affected consumers so the backend and Flutter remain consistent.
- Avoid speculative fixes. If an unrelated issue is found, report it separately; do not fix it as a side task.

## 5. ERP DATA & FINANCIAL SAFETY
Treat products, stock, purchases, suppliers, customers, sales, invoices, payments, debts, discounts, prices, profit, commissions, returns, delivery, and transaction status as high-risk.
- Identify the authoritative source of data and calculations. Do not duplicate existing business calculations.
- Laravel/server-side logic is authoritative for business rules, validation, authorization, pricing, discounts, stock, invoice totals, debts, and commissions. Never trust client-supplied totals, prices, permissions, stock, or balances without server validation.
- Preserve historical transaction values exactly as stored. Never silently recalculate old prices, discounts, taxes, costs, profit, debt, payments, or commissions using current rules.
- Protect data integrity, transaction state, access control, and backwards compatibility.

## 6. DATABASE & PRODUCTION
- Never run migrations or alter a production database.
- Do not create schema changes unless required by the requested task. Inspect the existing schema first.
- If a production schema change is necessary, explain the impact and provide raw SQL for the user to execute manually in phpMyAdmin; clearly flag destructive or irreversible changes. Prefer reversible changes.
- The user cannot run Laravel migrations on the hosting server. Do not rely on, or ask the user to run, `php artisan migrate`; provide the exact SQL needed to apply every required database/schema change manually in phpMyAdmin. Do not create a Laravel migration file as the way to deploy a production schema change.
- Before executing any terminal command, script, or other command-line operation for this workspace, read this instruction file first and follow its rules. If it has not been read in the current task, read it before running the command.
- Never drop/truncate databases, mass-delete data, overwrite historical accounting data, or execute destructive SQL.

## 7. SECURITY
Check relevant authentication, authorization, roles/permissions, ownership, validation, mass assignment, SQL injection, file handling, and sensitive-data exposure.
Never bypass access controls or expose passwords, secrets, API keys, tokens, or sensitive environment values. Do not log secrets.

## 8. FLUTTER & PLATFORM CONFIGURATION
Follow the app's current architecture, reusable components, theme, localization, and error-handling conventions. Prioritize fast entry and usable mobile/tablet/desktop layouts when relevant.
Do not change Gradle, AndroidManifest, Kotlin, AGP, Gradle wrapper, Android embedding, Java version, iOS configuration, or package versions for unrelated tasks. Platform/build files are high-risk; edit them only when explicitly necessary for the requested task.

## 9. GIT & FILE DISCIPLINE
- Preserve all user changes. Do not discard, overwrite, or revert existing work without explicit instruction.
- Never run or recommend destructive Git operations such as reset --hard, clean -fd, force-push, history rewriting, or branch deletion unless the user explicitly requests that exact operation.
- Do not commit or push unless specifically requested.
- Avoid duplicate files. Touch only files required for the task.

## 10. WORKFLOW
1. Understand the requested result and scope.
2. Inspect only the relevant implementation.
3. Identify the smallest safe change and related dependencies.
4. Edit only the necessary code/files.
5. Review the edited code statically; never run, build, compile, or test the app/project.

## 11. LANGUAGE & FINAL RESPONSE — MINIMAL
- Communicate in clear, simple Kurdish Sorani; keep technical identifiers in English.
- After coding, do NOT produce a report, file list, test report, or fixed template. Give only a brief completion message.
- Mention a suggestion only if it is genuinely useful; keep it to one or two short sentences.
- If a database schema change is required, briefly explain what the user must do and provide the exact raw SQL to run manually in phpMyAdmin. Explain any important risk in one short note. Never run the SQL or change the production database yourself.
- If no database change is needed, do not add a database section.
- Never claim the app was run, built, compiled, or tested. Mention this limitation only if relevant or asked.
- Clearly flag a serious blocker or risk in a short note; otherwise say nothing extra.

ئەگەر منیش فەرمانم کرد ، هەرگیز پڕۆژەکەمان لە فلۆتەرەوە مەگۆڕە بۆ ڕیاکت یان هەر شێوەیەکی تر ، هەر بە فلۆتەری بیهێڵەوە.

## FINAL PRINCIPLE
Make GARDI correct, stable, secure, maintainable, and compatible through the smallest justified code change. Protect the user's work, database, historical records, business rules, API contracts, and existing functionality. Code only; never run/build/compile/test the project.