# Plan - Nested Splits Sizing Bug Fixes

## Goal
Fix layout bug where sizing modes (particularly `.shrink`) are not working properly or propagating correctly for nested splits.

## Milestones

### Milestone 1: Exploration and Codebase Analysis
- **Objective**: Identify exact files, propagation functions (`makeChildContext(for:)`), and secondary sizing resolution points in `LinearSplitView.swift`, `GridSplitView.swift`, `SplittableRectangleView.swift`, `RatioBasedLayout.swift`, `ModernCanvasView.swift`, and `InvoiceCanvasView.swift`.
- **Method**: Spawn Explorer to analyze codebase and provide a fix strategy.
- **Verification**: Explorer handoff report with exact line numbers and concrete strategy.

### Milestone 2: Implement Fixes for Bug 1 and Bug 2
- **Objective**: Implement:
  1. Grandparent-to-parent-to-child propagation of sizing modes (Bug 1).
  2. Nested splits/leaves secondary sizing resolution and alignment (Bug 2).
- **Method**: Spawn Worker to implement changes.
- **Verification**: App and all packages compile cleanly.

### Milestone 3: Write & Run Automated Tests
- **Objective**: Add unit tests (e.g. in `LayoutAdversarialTests.swift`) for propagation and secondary sizing resolution, and run all existing tests in `Feature_InvoiceTemplateEditorTests`.
- **Method**: Spawn Worker/Challenger to add and run tests.
- **Verification**: Test output shows all tests passing (100% pass rate).

### Milestone 4: Review and Quality Assurance
- **Objective**: Review code changes for correctness, robustness, and layout alignment.
- **Method**: Spawn Reviewer to review code changes.
- **Verification**: Reviewer verdict passes with no issues.

### Milestone 5: Forensic Integrity Audit
- **Objective**: Perform forensic audit to ensure no integrity/cheating violations (e.g., hardcoded test results or dummy implementations).
- **Method**: Spawn Auditor.
- **Verification**: Auditor verdict is CLEAN.

### Milestone 6: Reporting and Handoff
- **Objective**: Prepare final completion report and handoff to parent Sentinel.
