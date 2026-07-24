# Plan: InvoicingApplication Multi-Window Support and SwiftData Concurrency Safety

## Objective
Satisfy the user request to make the Invoicing Application fully conform to macOS multi-window guidelines, ensure thread-safe SwiftData access, isolate window-specific UI states, and verify all changes with automated tests.

## Phase 1: Investigation and Baseline Verification
- Dispatch an Explorer to analyze:
  - App scene topology in `InvoicingApplicationApp.swift` and `InvoicingApplicationApp.swift` (AppShell).
  - Where and how `UtilityWindow` is defined or imported, and how window presence tracking (e.g. `ToolWindowPresenceRegistry`) behaves.
  - Active SwiftData `ModelContainer` and `ModelContext` initialization, checking for multiple ModelContainer instances or unsafe thread sharing.
  - Current window state usage (e.g. active navigation/selection state) to see if they bleed across windows.
  - Existing test suite setup to prepare for unit/integration tests of multi-window functionality.

## Phase 2: Implementation of R1, R2, R3
- Dispatch a Worker to:
  - Refactor App Scene topology (Workspace WindowGroup, Settings, UtilityWindows) for proper multi-window/singleton handling.
  - Ensure a single shared `ModelContainer` is used across all scenes.
  - Audit and fix all `ModelContext` usages to ensure they run on the correct actor/thread.
  - Refactor workspace window states (tab selection, panel focus, sidebar selections, detail views) to use `@SceneStorage` or local view state.
  - Compile the application and ensure it builds cleanly on macOS.

## Phase 3: Testing & Verification (R4)
- Dispatch a Challenger to implement integration/unit tests for multi-window state isolation and thread safety.
- Run all tests to verify zero regressions.
- Dispatch a Reviewer and Forensic Auditor to perform safety, layout, and integrity audits.

## Phase 4: Final Reporting and Handoff
- Synthesize all subagent results.
- Write `handoff.md` and report completion to the Sentinel.
