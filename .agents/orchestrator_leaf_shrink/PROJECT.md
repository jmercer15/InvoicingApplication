# Project: Table Sizing and Split Layout Constraints

## Architecture
- `InvoiceComponent` & `DocumentGridComponent`: Sizing metrics (analyticGridHeight, minIntrinsicWidth).
- `SectionSplit` & `FlexibleSizeCalculator`: Layout execution using child intrinsic sizes.
- `LeafComponentFrameSizing`: Bridge querying components for width/height.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Baseline verification | Build, run tests | None | DONE |
| 2 | Codebase exploration | Discover files, analyze calculation pathways | M1 | DONE |
| 3 | Vertical size fix (Bug 1) | Fix fallback vertical undercount in LeafComponentFrameSizing | M2 | DONE |
| 4 | Horizontal size fix (Bug 2) | Fix missing border width in minIntrinsicWidth | M3 | DONE |
| 5 | Validation & tests | Verify fixes, write new tests, ensure zero warning/error builds | M4 | DONE |

## Code Layout
- `Packages/Feature.InvoiceTemplateEditor/Sources/Feature.InvoiceTemplateEditor/`
  - `Layout/`: SectionSplit, FlexibleSizeCalculator, LeafComponentFrameSizing.
  - `Components/`: DocumentGridComponent, InvoiceComponent.
