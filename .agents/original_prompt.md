# Original User Request

## 2026-06-05T05:24:25Z

Track down and fix all remaining UI performance issues in the SwiftUI InvoicingApplication codebase, addressing both structural layout bottlenecks and data-fetching inefficiencies.

Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication
Integrity mode: development

## Requirements

### R1. Resolve Structural Layout Anti-patterns
Scan the SwiftUI codebase and fix layout anti-patterns that cause main-thread stutter. Specifically, target and eliminate unconstrained `GeometryReader` measurement loops, nested `ScrollView`s, and standard `VStack`/`HStack` structures used inside `ScrollView`s that should instead be `LazyVStack`/`LazyHStack`.

### R2. Resolve Data-Fetching Anti-patterns
Identify and fix synchronous SwiftData fetches (e.g., massive `@Query` executions or blocking `modelContext.model(for:)` calls) that occur on the Main Thread during view initialization. Offload these queries to background contexts (e.g., utilizing `ReferenceDataWorkflowActor` or asynchronous batch fetch descriptors).

## Acceptance Criteria

### Compilation & Correctness
- [ ] The project successfully compiles with `xcodebuild -scheme InvoicingApplication -destination 'platform=macOS'` exiting with code 0 after all changes.
- [ ] The core architecture and behavior of the modified views remain intact and functional.

### Structural UI Quality
- [ ] Codebase contains zero instances of standard `VStack` or `HStack` inside `ScrollView` wrapping a `ForEach` loop that renders unbounded data.
- [ ] Codebase contains zero instances of nested `ScrollView`s within the same axis.
- [ ] `GeometryReader` usage is strictly limited to necessary cases and does not trigger recursive view updates.

### Data Flow Quality
- [ ] Views do not trigger unbounded database queries on the Main Thread during `init` or layout passes.

## 2026-06-09T15:24:02Z

Standardise the UI design throughout all of the application's features (NDIS, Clients, Invoices, Calendar, Billing Hub, Settings, Invoice Template Editor, AppShell). Unify spacing, typography, corner radii, and color choices by replacing ad-hoc inline styling with the design-token systems (`StyleGuide`, `ColorSystem`, `PanelShellTokens`). Ensure structural layouts adopt standard panel shells (`PanelShellStyle`), spacing/insets, and component patterns (e.g. cards, status badges, section headers).

Working directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication
Integrity mode: development

---

## Requirements

### R1. Design-Token Migration
Replace all raw, inline styling values with appropriate tokens:
- **Dimensions & Spacing**: Replace raw margins, padding, and spacers with `StyleGuide.Dimensions` tokens (e.g., `paddingMedium`, `paddingLarge`, `cornerRadiusMedium`, etc.).
- **Color System**: Replace all hardcoded colors, inline hex-string color mappings, and NSColor calls with approved colors from `ColorSystem` or `StyleGuide.Colors`.

### R2. Visual Refresh & Unified Components
Ensure a standard visual layout across all screens:
- **Cards & Badges**: Standardise components (cards, lists, badges, and section headers) to use `SharedUI` types (e.g., `StatusBadge`, `FormField`, `EnhancedGroupBoxStyle`) instead of custom local layouts.
- **Visual Uniformity**: Align similar layouts in different features to follow consistent visual hierarchies, margins, contrast ratios, and animations (e.g., transition styles).

### R3. Panel Shell and Column-Width Standardisation
Standardise layout containers and pane sizing:
- **PanelShell Adoption**: Apply `.standardPanelShell(role:)`, `.standardPanelContentPadding()`, and custom padding modifiers from `PanelShellTokens` / `PanelShellModifiers.swift` to all main content panes, sidebars, and detail panels.
- **Column Standardisation**: Unify sidebar, content list, and inspector column sizes using design-defined bounds (e.g. `inspectorWidthMin`, `inspectorWidthIdeal`, `inspectorWidthMax` in `StyleGuide`).
- **Jitter Reduction**: Implement `DetailCardsLayout` with deterministic adaptive spacing to prevent layout shifting/jitter on resize.

### R4. Prioritised Execution Sequence
The work must be executed and verified package-by-package in the following order:
1. **Feature.NDIS**
2. **Feature.Clients**
3. **Feature.Invoices**
4. **Feature.BillingHub** & **Feature.Calendar**
5. **Feature.Settings** & **Feature.InvoiceTemplateEditor**
6. **AppShell** (Integration and final assembly)

### R5. Build & Test Verification Gate
At each step of the sequence:
- The app and modified package targets must build cleanly with no new compiler warnings or errors.
- The corresponding package and app tests must pass.
- Verify using `xcodebuild` or existing shell scripts (e.g., `scripts/refactor-verify.sh`).

---

## Acceptance Criteria

### Build & Correctness
- [ ] Modified targets build cleanly via `xcodebuild build` with zero new warnings/errors.
- [ ] All package and application tests pass via `xcodebuild test`.

### Token & Style Adoption
- [ ] No raw numeric literals are used for padding, corner-radius, or spacing within the `Views/` directories of modified features.
- [ ] No local custom `Color(red:...)` or system-specific hex code conversion functions exist in modified feature views; all utilize `ColorSystem`.

### Layout & Component Consistency
- [ ] Features use standard views like `StatusBadge` and `FormField` from `SharedUI` rather than declaring localized clones.
- [ ] Split views, panels, and detail columns correctly apply `standardPanelShell` modifiers with appropriate `PanelShellRole` mapping.
- [ ] Content margins match `PanelShellTokens` definitions across all active panes.
- [ ] Detail panels use `DetailCardsLayout` to handle card layout grids consistently.

## 2026-06-11T14:35:33Z

Resume UI standardisation.
- Feature.NDIS: Done
- Feature.Clients: Done
- Feature.Invoices: In progress (orchestrator_gen10 worker_invoices_gen10). Start here.
- Remaining: BillingHub, Calendar, Settings, InvoiceTemplateEditor, AppShell.
Unify spacing, typography, colors, panel shells. Follow execution sequence. Build/test verify at each step.
