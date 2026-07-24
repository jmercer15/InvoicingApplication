# Original User Request

## Follow-up — 2026-06-09T15:24:02Z

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

## Follow-up — 2026-06-09T15:24:41Z

Unify spacing, typography, corner radii, and color choices in the SwiftUI InvoicingApplication codebase using the token systems, following the prioritised sequence:
1. Feature.NDIS
2. Feature.Clients
3. Feature.Invoices
4. Feature.BillingHub & Feature.Calendar
5. Feature.Settings & Feature.InvoiceTemplateEditor
6. AppShell (Integration and final assembly)

After completing all tasks, verify everything works, and notify the sentinel (your parent agent) that you have claimed victory.
