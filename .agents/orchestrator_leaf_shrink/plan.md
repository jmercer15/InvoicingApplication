# Implementation Plan

## Milestone 1: Baseline Verification
- Run tests on the existing codebase to ensure the baseline is completely green and functional.
- Identify the exact commands/scripts to build and test the project.

## Milestone 2: Codebase Exploration
- Spawn `teamwork_preview_explorer` to find where the layout math and size calculations happen.
- Locate the files:
  - `LeafComponentFrameSizing.swift`
  - `DocumentGridLayoutMath.swift` / `DocumentGridComponent.swift` / `InvoiceComponent.swift`
  - `SectionSplit.swift` / `FlexibleSizeCalculator.swift`
- Trace how `LeafComponentFrameSizing.intrinsicVerticalSize` queries size and how it falls back to `contentVerticalSize`.
- Find how border width is calculated in `DocumentGridComponent+AnalyticHeight.swift` vs `InvoiceComponent.swift`.

## Milestone 3: Fix Vertical Undercount (Bug 1)
- Identify how `LeafComponentFrameSizing.intrinsicVerticalSize` can dynamically/synchronously query the actual table height (or use `analyticGridHeight` / `effectiveGridHeight` calculations or similar mechanism).
- Ensure no layout jitter on the first pass.

## Milestone 4: Fix Horizontal Undercount (Bug 2)
- Fix the missing border width in `InvoiceComponent.minIntrinsicWidth`.

## Milestone 5: Verification and Testing
- Add a new unit test in `DocumentGridLayoutMathTests` or `DocumentGridHeightReliabilityTests` or a new test file validating that a `DocumentGrid` with all `.shrink` axes produces an intrinsic layout equal to the sum of cell dimensions, and that leaf sizes respect actual table size.
- Run all automated tests to verify zero regressions.
