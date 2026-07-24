# Sizing Refactor Plan

## Phase 1: Exploration
- Spawn `teamwork_preview_explorer` to:
  - Locate files containing enums related to row/column sizing (`AxisSizingMode`, `ColumnWidthMode`, `RowHeightMode`, etc.).
  - Identify where `TableAxisConfiguration` is defined.
  - Locate `ComponentStyle` and `InvoiceDocument` files.
  - Locate Inspector views that pick sizing modes.
  - Find automated tests for sizing or table layout.

## Phase 2: Implementation (Worker)
- Define `TableSizingMode` enum:
  - Flexible, fit/autoSize, fixed.
- Update `TableAxisConfiguration` to use `TableSizingMode` natively or via computed wrappers.
- Simplify helper/utility functions in `ComponentStyle` and `InvoiceDocument`.
- Refactor Inspector Views to remove obsolete enums, bind to `TableSizingMode`, and show/hide height/width steppers correctly.

## Phase 3: Review & Verification
- Spawn `teamwork_preview_reviewer` to check correctness and code quality.
- Spawn `teamwork_preview_challenger` to run project build and test suite, ensuring no regressions.
- Spawn `teamwork_preview_auditor` for integrity check.

## Phase 4: Final Report
- Synthesize findings and write handoff report.
