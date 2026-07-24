# Scope: Document Grid Sizing Refactor

## Architecture
- Refactor the document grid components (row/column sizing mode logic) to use a unified `TableSizingMode` enum.
- Replaces duplicate enums (`AxisSizingMode`, `ColumnWidthMode`, `RowHeightMode`).
- Ensures layout logic (CoreText, preview, PDF rendering) remains functional.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Exploration | Search duplicate enums and get/set methods across components. | none | DONE |
| 2 | Model Refactoring | Define `TableSizingMode`, refactor `TableAxisConfiguration`, simplify model APIs. | 1 | DONE |
| 3 | View Refactoring | Refactor Inspector views to use `TableSizingMode` and remove old pickers/enms. | 2 | DONE |
| 4 | Verification & Audit | Verify build, run tests, and run Forensic Auditor. | 3 | DONE |

## Interface Contracts
- `TableSizingMode` has cases: `flexible`, `fit` (or `autoSize`), `fixed`.
- Component styles and document APIs use `TableSizingMode`.
