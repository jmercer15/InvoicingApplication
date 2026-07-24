# Scope: DocumentGrid Layout Fix for All-Shrink Axis Sizing

## Architecture
- Invoicing application template editor with components placed inside split-layout leaf containers.
- `DocumentGrid` component calculates dynamic cell widths and heights from text content.
- `LeafComponentFrameSizing` resolves frame layout dimensions based on split sizing modes (`.fixed`, `.expand`, `.shrink`).
- `DocumentGridComponent` wraps the grid inside the SwiftUI canvas, applying `.frame` bounds and alignments.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Baseline Verification | Run baseline tests to verify compile/test correctness. | none | DONE |
| 2 | Implementation of Sizing Constraints | Update `LeafComponentFrameSizing.swift` and `DocumentGridComponent.swift` to limit dimensions under all-shrink sizing. | M1 | DONE |
| 3 | Extended Layout Math Tests | Add unit tests to `DocumentGridLayoutMathTests.swift` for all `.shrink` sizing behavior. | M2 | DONE |
| 4 | Verification & Audit Gates | Verify changes, run reviews and challengers, run Forensic Integrity Auditor. | M3 | DONE |

## Interface Contracts
- When all columns have a `.shrink` (Fit) sizing mode, the overall width must not exceed the sum of columns' intrinsic widths.
- When all rows have a `.shrink` (Fit) sizing mode, the overall height must not exceed the sum of rows' intrinsic heights.
- Leaves smaller than parent containers must respect leaf/container alignment settings without artificially inflating bounding boxes.
- Flexible/fit/fixed column sizing behaviors must remain unaffected.
