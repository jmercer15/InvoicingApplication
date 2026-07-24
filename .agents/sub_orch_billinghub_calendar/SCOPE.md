# Scope: Feature.BillingHub & Feature.Calendar UI Refinement

## Architecture
- `Feature.BillingHub` contains the Billing Hub dashboard, Kanban board views, billable drafts list and details, and workflow/editing panels.
- `Feature.Calendar` contains the main calendar view, day/week column views, month grid views, session editors, and travel charge forms.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Exploration & Planning | Run Explorer to inspect views, analyze current UI code, and draft `plan.md`. | None | PLANNED |
| 2 | Implementation: BillingHub | Apply visual hierarchy, empty/loading/error states, interaction, accessibility to BillingHub. | M1 | PLANNED |
| 3 | Implementation: Calendar | Apply visual hierarchy, empty/loading/error states, interaction, accessibility to Calendar views. | M2 | PLANNED |
| 4 | Verification & Quality Gate | Review changes, run tests, adversarial tests, forensic audits. | M3 | PLANNED |

## Interface Contracts
- Views remain binary and API compatible with the host application.
- Retain existing views' initializers, state bindings, and data models to avoid breaking feature logic.

## Target Areas and Files

### 1. Component Depth & Visual Hierarchy
- **BillingHub**:
  - `BillingHubCardColumnChrome.swift`, `KanbanBoardView.swift` (spacing, column cards, shadows, borders)
  - `BillingHubGroupedSessionRows.swift` (row depth, visual hierarchy)
- **Calendar**:
  - `MonthDayCellView.swift`, `MonthHeaderComponents.swift` (cell grid borders, background depth)
  - `CalendarItemBlockView.swift` (rounded corners, standard card shadow, elevation)
  - `NativeSessionFormView.swift` (sections, headers, form controls depth)

### 2. Empty, Loading, and Error States
- **BillingHub**:
  - `BillableDraftsHomeView.swift` (empty state when list is empty; loading state while fetching; error displays)
  - `BillingHubView.swift` (loading/error indicators for board data)
- **Calendar**:
  - `CalendarView.swift` (loading/error state when events are loading/failed)
  - `SessionEditorSheetContainer.swift` (loading/error handling inside editors)

### 3. Interactive Feedback
- **BillingHub**:
  - `BillingHubView.swift`, `KanbanBoardView.swift` (hover, press highlights, focus rings, pointer styles)
- **Calendar**:
  - `MonthDayCellView.swift`, `CalendarItemBlockView.swift` (hover styles, pressed state, focus/keyboard accessibility)

### 4. Contrast & Accessibility (WCAG AA)
- All target views to use appropriate contrast colors, semantic SwiftUI colors (e.g. `Color(NSColor.controlAccentColor)` or local themes).
- Ensure `.accessibilityElement(children: .combine)`, `.accessibilityLabel`, `.accessibilityHint`, `.accessibilityValue` are set appropriately on interactable components.
