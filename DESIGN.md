# GARDI ERP — Master Design System

Version: 1.0
Status: Authoritative
Scope: Flutter application UI, Stitch design work, prototypes, and AI-generated UI implementation

## 0. Authority

This file is the master visual and interaction design contract for GARDI ERP.

Any new or modified UI must follow this file unless an explicit product/design decision changes it.

Priority order:
1. Explicit current product requirement.
2. This DESIGN.md.
3. Existing GARDI shared Flutter design tokens and components.
4. Existing screen patterns that already comply with this system.
5. Never invent a competing visual language.

Stitch must use this file as the design-system source of truth when creating or refining GARDI screens.
Google AI Studio must read this file before changing Flutter UI and must implement against it rather than inventing new styles.

If a requested design conflicts with this file, identify the conflict and resolve it by following the newest explicit product requirement; do not silently create a second design system.

---

## 1. Product and Visual Direction

GARDI is a professional wholesale distribution / ERP application. The UI must feel:
- Professional
- Fast and operational
- Clear under daily business use
- Trustworthy for financial and inventory workflows
- Dense enough for ERP work without becoming visually cramped
- RTL-first for Kurdish and Arabic
- Responsive across phone, tablet, and desktop
- Accessible and readable

Avoid:
- Decorative UI that does not improve task completion
- Excessive gradients, glassmorphism, oversized illustrations, or gaming-style effects
- Random shadows, radii, colors, typography, or spacing
- Long text hidden with unnecessary ellipsis
- Horizontal overflow
- Layouts that only work at one screen width

---

## 2. Brand Colors

Use the existing Flutter `AppColors` tokens as the implementation source of truth.

### Primary
- Primary: `#122D5A`
- Primary light: `#EBF0FA`

### Semantic
- Success: `#0A9C6E`
- Warning: `#D4820A`
- Danger: `#D93535`
- Info: `#2678D4`
- Purple: `#7B41D6`

### Price tiers
- N1: Success
- N2: Warning
- N3: `#5B6B84`

### Light mode
- Background: `#F7F9FD`
- Surface: `#EFF4FB`
- Border: `#D1DCE8`
- Primary text: `#0D1B2E`
- Secondary text: `#5B6B84`
- Disabled text: `#9AABBB`

### Dark mode
- Primary: `#4A7FD4`
- Background: `#0F1419`
- Surface: `#1A2332`
- Success: `#34D399`
- Warning: `#FBBF24`
- Danger: `#F87171`
- Primary text: `#F0F4FA`
- Secondary text: `#94A3B8`
- Border: `#2A3548`

Do not introduce another brand blue, status red, success green, or arbitrary grey. Reuse semantic tokens.

---

## 3. Typography

The primary font is **Rudaw**.

Use the existing Flutter `AppTextStyles` tokens:
- displayLarge: 32 / 700
- displayMedium: 26 / 700
- h1: 22 / 700
- h2: 18 / 700
- h3: 16 / 700
- bodyLarge: 15 / 400
- bodyMedium: 14 / 400
- bodyBold: 14 / 700
- bodySmall: 13 / 400
- caption: 12 / 400
- overline: 11 / 400
- price: 16 / 700
- priceLarge: 22 / 700
- button: 15 / 700

Do not create ad-hoc font sizes when an existing token is appropriate.

Numbers, money, quantities, dates, and status labels must remain highly legible.

---

## 4. Spacing System

Use the existing `AppSpacing` 4px-based scale:
- xxs: 2
- xs: 4
- sm: 8
- md: 12
- lg: 16
- xl: 24
- xxl: 32
- xxxl: 48

Semantic spaces:
- Screen horizontal padding: 16
- Card padding: 12
- Section gap: 24
- List item gap: 8

Do not invent random spacing values unless required by a specific platform constraint.

---

## 5. Corner Radius

Use the existing `AppRadius` tokens:
- xs: 6
- sm: 8
- md/input/button: 10
- lg/card: 12
- xl/dialog: 16
- xxl/bottom sheet: 24
- pill/badge/chip: 999

Cards use the card radius. Inputs and standard buttons use input radius. Dialogs use dialog radius.

---

## 6. Elevation, Borders, and Surfaces

Prefer clean surfaces and subtle separation over heavy shadows.

Use:
- Background token for page background
- Surface token for cards/panels/forms where appropriate
- Border token for visible structural separation
- Small elevation only when it improves hierarchy

Do not mix multiple visual treatments for identical component types.

---

## 7. RTL and Localization

GARDI is RTL-first.

Requirements:
- Layout direction must support Kurdish/Arabic correctly.
- Text alignment, icons, arrows, navigation affordances, and paddings must respect RTL.
- Use logical/start/end layout concepts rather than hard-coded left/right where possible.
- Do not mirror icons that are semantically non-directional.
- Directional icons such as back/forward must follow actual navigation direction.
- Never solve RTL by visually shifting isolated elements manually.

Arabic/Kurdish text must remain readable and must not overflow.

---

## 8. Responsive Layout Contract

Every screen must be intentionally designed for:
- Mobile: 1-column operational layout
- Tablet: 2-column or compact multi-column where useful
- Desktop: 3-column cards or data-dense layouts when appropriate

Follow existing GARDI responsive rules and avoid fixed widths that cause overflow.

Never ship a `Row` whose children can exceed available width.

For variable text in constrained rows:
- Prefer `Expanded` / `Flexible` when semantically correct.
- Use wrapping when content should naturally flow.
- Use horizontal scrolling for genuinely wide tabular/data surfaces.
- Use ellipsis only when truncation is intentional and acceptable.
- Do not use `ClipRect` as a cosmetic fix for a layout bug.

A screen is not considered design-complete until mobile, tablet, desktop, and RTL behavior are coherent.

---

## 9. Navigation and App Bars

Use the existing GARDI routing and role-aware navigation architecture.

App bars:
- Keep title hierarchy clear.
- The primary create/add action should use the existing shared icon-button pattern where appropriate.
- Do not duplicate custom app-bar button styling on individual screens.

Navigation must remain role-aware; visual redesign must never change permissions or routing behavior.

---

## 10. Core Components

Prefer existing shared components before creating new widgets.

Known shared building blocks include:
- `AppSnackbar`
- `AppDialog`
- `AppIconButton`
- `StatusBadge`
- `EmptyState`
- `LoadingSkeleton`
- `AppStepper`

When a component pattern is used more than once, it should normally become a shared component rather than a screen-local implementation.

Do not create a second snackbar, dialog, card, button, badge, or loading style that duplicates an existing shared component.

---

## 11. Messages, Feedback, and Dialogs

All transient UI feedback must use the shared feedback pattern.

Categories:
- Success
- Error
- Warning
- Info
- Confirmation / destructive action

Visual rules:
- Semantic colors come from `AppColors`.
- Typography comes from `AppTextStyles`.
- Radius comes from `AppRadius`.
- Spacing comes from `AppSpacing`.
- Icons must communicate the semantic type consistently.

Do not expose raw backend exceptions, stack traces, database errors, or implementation details to end users.

Do not use different local `AlertDialog` styles for delete/confirm/error flows when the shared dialog component can be used.

---

## 12. Forms and Inputs

Inputs must have consistent:
- Height
- Border treatment
- Radius
- Label/hint hierarchy
- Error state
- Focus state
- Disabled state
- RTL behavior

Use shared theme/components where available.

Validation messages must be concise, user-facing, and actionable. Backend implementation details stay out of the UI.

---

## 13. Cards and Lists

Cards should be information-dense but scannable.

Rules:
- Keep alignment consistent between cards of the same type.
- Use semantic badges/chips for status, not arbitrary colors.
- Preserve readable customer/product/order names.
- Card tap should follow existing GARDI interaction rules.
- Long-press destructive actions must use confirmation where applicable.
- Avoid unnecessary text truncation.

Do not use a different card shape or padding for every feature.

---

## 14. Tables and Data-Dense ERP Surfaces

For desktop/tablet ERP data:
- Prioritize scanning and numeric alignment.
- Keep column labels clear.
- Preserve status visibility.
- Avoid tiny typography.
- Provide horizontal scrolling only where the information is inherently wide.

For mobile, convert dense tables into stacked cards or responsive row layouts rather than forcing desktop tables into narrow widths.

---

## 15. States

Every data-driven screen should have coherent states for:
- Initial loading
- Loading more / refreshing where applicable
- Success with data
- Empty result
- Network/API failure
- Permission/unauthorized
- Offline / pending sync where applicable

Use shared skeleton, empty-state, and feedback components.

Do not represent an API failure as an empty list unless the product explicitly defines that behavior.

---

## 16. Accessibility and Usability

- Maintain strong text/background contrast.
- Preserve touch targets appropriate for mobile interaction.
- Do not rely on color alone to communicate status.
- Use icon + label where useful.
- Keep primary actions visually obvious.
- Maintain readable typography at common display sizes.
- Never allow text or controls to disappear because of an avoidable overflow.

---

## 17. Motion

Use motion sparingly and consistently.

Prefer the existing `AppDurations` tokens where implemented.

Motion should communicate state, navigation, or hierarchy—not decorate every interaction.

---

## 18. Financial and Operational UI

GARDI handles prices, profit, debt, payments, stock, orders, and delivery.

Visual design must make these values easy to distinguish and scan:
- Money: use price typography.
- Profit/loss: use semantic meaning consistently.
- Outstanding debt: clearly distinguish owed vs paid.
- Stock quantity and availability: visually distinguish available/reserved where shown.
- Order/payment statuses: use consistent semantic badges.

Never alter business logic, calculations, permission behavior, stock rules, or API contracts as a consequence of a visual redesign.

---

## 19. Stitch Rules

When working in Stitch:

1. Treat this file as the GARDI design-system source of truth.
2. Reuse the colors, typography, spacing, radius, RTL, responsive, and component rules above.
3. Do not introduce a new visual language for a single screen.
4. Before creating a component, check whether a shared GARDI component/pattern already exists.
5. Design the same screen at mobile, tablet, and desktop widths.
6. Validate RTL presentation for Kurdish/Arabic.
7. Prefer consistency with existing GARDI screens over generic Material defaults when this file defines a specific rule.
8. When a design decision is genuinely missing, choose the smallest consistent extension and document it rather than inventing unrelated styling.

Stitch is for visual design/prototyping; it must not redefine backend behavior or business rules.

---

## 20. Google AI Studio Rules

Before changing Flutter UI:

1. Read `DESIGN.md`.
2. Inspect existing shared theme and component files.
3. Reuse existing tokens/components instead of hard-coding replacements.
4. Do not rewrite the entire UI architecture just to change styling.
5. Preserve routes, providers, repositories, API contracts, permissions, business rules, and offline behavior.
6. When migrating a screen, search the repository for duplicate UI patterns and consolidate rather than multiplying them.
7. After UI changes, statically verify that no avoidable `RenderFlex` overflow, hard-coded competing colors, duplicate dialog/snackbar components, or desktop-only assumptions were introduced.

A UI change is not complete merely because it looks good on one viewport. It must comply with this DESIGN.md across supported breakpoints and RTL.

---

## 21. Implementation Source of Truth

Flutter implementation must continue to use the existing design-token files as the code-level source of truth:
- `lib/core/theme/app_colors.dart`
- `lib/core/theme/app_radius.dart`
- `lib/core/theme/app_spacing.dart`
- `lib/core/theme/app_text_styles.dart`
- `lib/core/theme/app_theme.dart`

Shared UI components live under:
- `lib/core/components/`

Do not duplicate token values into individual screens.

---

## 22. Change Control

If a new visual rule is needed:

1. Determine whether an existing token/component can solve it.
2. If not, propose the smallest reusable addition.
3. Update this DESIGN.md before applying the new visual language broadly.
4. Update the corresponding Flutter shared token/component.
5. Use the new rule consistently across all affected screens.

Never create one-off styling that becomes an undocumented exception.

---

## 23. Definition of Done — UI

A UI change is complete only when:
- It follows this DESIGN.md.
- It reuses shared design tokens/components.
- It works in RTL.
- It is responsive for mobile/tablet/desktop.
- It does not introduce avoidable overflow.
- It has coherent loading/empty/error states when data-driven.
- It does not expose raw technical errors to users.
- It does not change business logic or API behavior unintentionally.
- Repeated patterns remain visually and behaviorally consistent.
