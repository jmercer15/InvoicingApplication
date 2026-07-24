# Plan: InvoicingApplication Multi-Window & SwiftData Compliance

## Goal
Conform SwiftUI scene topology to macOS HI guidelines, ensure thread-safe SwiftData ModelContainer/ModelContext, isolate window state, and write automated tests.

## Phase 1: Exploration & Baseline Verification
- **Objective**: Identify all scene declarations, window types, ModelContainer instances, and local UI state properties. Run baseline tests to verify the initial state.
- **Tasks**:
  1. Dispatch Explorer to explore scene topology, SwiftData context usage, and window-state mechanisms.
  2. Verify existing test targets compile and pass.
- **Verification**: Handoff analysis report with file paths, code locations, and test results.

## Phase 2: Implementation of R1, R2, R3
- **Objective**: Implement SwiftUI multi-window topology, thread-safe SwiftData, and isolated scene/window state.
- **Tasks**:
  1. Refactor SwiftUI scene topology to allow multiple independent Workspace windows, singleton Settings, and managed utility panels.
  2. Update ModelContainer to be a single shared instance, and make ModelContext access thread-safe.
  3. Refactor scoped window-specific states using `@SceneStorage` or view-local states.
- **Verification**: Worker build succeeds, manual checks verify independent navigation and singleton window compliance.

## Phase 3: Automated Testing & Verification (R4)
- **Objective**: Write unit/integration tests for the new window state isolation and thread safety. Ensure no regressions in existing tests.
- **Tasks**:
  1. Add tests checking independent window states (tab navigation, panel focus).
  2. Add concurrency and multi-context validation tests.
  3. Run all tests to verify 100% pass rate.
- **Verification**: Clean test run command output and 100% success.

## Phase 4: Review, Audit, and Handoff
- **Objective**: Complete independent peer review and forensic integrity audit.
- **Tasks**:
  1. Dispatch Reviewer to review code changes.
  2. Dispatch Forensic Auditor to check compliance and verify no cheating/hardcoding.
  3. Synthesize results and prepare handoff.md.
