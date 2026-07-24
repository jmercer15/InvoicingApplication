# Scope: Milestone 4 (Feature.Invoices UI Refinement)

## Architecture
- Target Package: `Packages/Feature.Invoices`
- Core Views to refine:
  - `InvoicesView`: Navigation lists, group titles, filter sections, multi-select bottom toolbar.
  - `InvoicesColumns`: Column layout structure for multi-column split views.
  - `InvoicesDetailColumn`: Selected invoice detail visualization, payment/billing statistics summary.
  - `InvoiceEditor`: Creation and edit flow with interactive cards, line item list, templates, and unsaved changes indicators.
  - `InvoiceInspectorFormView`: Right-side inspector drawer for modifying metadata.
  - `InvoiceLineItemsSection`: Table or list of individual billing line items.
  - `InvoiceFilterPopoverContent`: Popover panel for complex multi-criteria filtering.
  - `InvoiceTemplateRendererView`: Canvas rendering of templates.
- Design tokens derived from `SharedUI` package.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Exploration & Analysis | Run concurrent Explorers to identify UI refinement opportunities and compile recommendations. | None | DONE |
| 2 | Implementation | Refine component elevation, empty/loading/error states, interactive highlights/affordances, and accessibility hints in `Feature.Invoices`. | M1 | DONE |
| 3 | Verification & Review | Run Reviewers, Challengers, and Forensic Auditor to ensure visual appeal, lack of regressions, correctness, and compilation. | M2 | IN_PROGRESS |

## Interface Contracts
### `Feature.Invoices` ↔ `SharedUI`
- Standard view styling, colors, and components (e.g. `EmptyStateView`, `LoadingView`, `LoadingOverlayModifier`, `StyleGuide.Dimensions`, `ColorSystem`).
- Proper adoption of hover and active pointer states (`.pointerStyle(.link)`, button styles).
