# Architecture Refactoring Plan Review Report

## Review Summary

**Verdict**: APPROVE  
**Target Document**: `/Users/user/Developer/InvoicingApplication/InvoicingApplication/REFACTOR_PLAN.md`  
**Reviewer**: reviewer_2  
**Date**: 2026-08-10  

---

## 1. Observation

Direct observations from codebase inspection and execution:

- **Baseline Architecture Script Execution**:
  Command: `./scripts/architecture-check.sh`
  Result: PASSED (6/6 checks clean).
  Output snippet:
  ```
  ==> Checking forbidden AppShell imports in feature packages
  ✅ No forbidden AppShell imports in feature packages.
  ==> Checking direct workspaceStandardServicesEnvironment callsites
  ✅ workspaceStandardServicesEnvironment usage constrained to bridge points.
  ==> Checking unsafe persistent-identifier materialization
  ✅ ModelActor identifier resolution uses safe fetches.
  ==> Checking feature-owned ModelContainer creation
  ✅ Production ModelContainer ownership stays in composition/data layers.
  ==> Checking workspace search ownership
  ✅ Workspace search stays owned by WorkspaceSearchHost.
  ==> Checking invoice template preference ownership
  ✅ Template preferences stay isolated from persisted invoice decoding and rendering.
  ✅ Architecture check completed.
  ```

- **`@State` Initialization Hazard**:
  File: `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceRootView.swift`
  Line 22: `@State private var viewModel: InvoiceEditorViewModel`
  Line 79: `_viewModel = State(initialValue: viewModel)`
  Observation: View model passed via initializer into `@State` storage. Violates SwiftUI `@Observable` reference handling.

- **Abandoned Package Directory**:
  Path: `Packages/DTOMacros/`
  Observation: No `Package.swift` file. `find_by_name` returned 0 `.swift` source files.

- **Incomplete Test Harness Script**:
  File: `scripts/refactor-verify.sh`
  Lines 21–23: Executes `swift test` only for `SharedUI` and `Feature.Settings`. Skips test suites for 11 active workspace packages.

- **Duplicate Input Parsing**:
  Files:
  1. `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceFilterAmountField.swift` (lines 10–53)
  2. `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceValidatedDecimalField.swift` (lines 5–58 & 179–220)
  Observation: Identical `NumberFormatter` setup, `try formatter.getObjectValue(...)`, and consumed range length check logic duplicated across packages.

- **Component Shadowing**:
  File: `Packages/Feature.Calendar/Sources/Feature_Calendar/Views/SessionEditor/SessionAddressEditingSheet.swift`
  Line 8: `struct AddressEditingSheet: View`
  Observation: Local struct shadows `WorkspaceUI.AddressEditingSheet` while manually binding 10 individual keypaths instead of using `WorkspaceUI.AddressFormSheet`.

- **Duplicate Persistence Schema**:
  File: `Packages/Data/Sources/Data/Persistence/PersistenceSchema.swift` (lines 5–30) vs `Packages/PersistenceModels/Sources/PersistenceModels/PersistenceSchema.swift` (lines 5–30)
  Observation: Verbatim 26-line duplicate copy of `appModels` array.

- **Duplicate Test Tags**:
  Files: 14 `TestTags.swift` files across test packages (e.g. `Packages/AppShell/Tests/AppShellTests/TestTags.swift`, `Packages/Core/Tests/CoreTests/TestTags.swift`).
  Observation: Each file contains identical 8-line extension declaring `@Tag static var unit` and `@Tag static var integration`.

---

## 2. Logic Chain

1. **Macro Analysis Accuracy**:
   - `InvoiceRootView.swift` initializes `@State` from init parameters. In SwiftUI, `@State` value persists across parent re-evaluations, locking stale view model instances when workspace selection changes. `REFACTOR_PLAN.md` Section 1.1 A accurately diagnoses this bug and Section 2.1 provides correct `@Bindable` fix.
   - `scripts/refactor-verify.sh` omits 11 package test suites. `REFACTOR_PLAN.md` Section 1.1 D correctly flags this gap and Section 5 Phase 1 fixes it.

2. **Micro Analysis Accuracy & Bloat Decomposition**:
   - `InvoiceDocumentSections.swift` (1,845 lines) and `InvoiceFormatting.swift` (1,078 lines) exceed single-responsibility limits. `REFACTOR_PLAN.md` Section 3.1 provides explicit line-range mappings for splitting them into targeted sub-files.
   - `Packages/Data/Sources/Data/Persistence/PersistenceSchema.swift` duplicates `PersistenceModels.PersistenceSchema`. Replacing with `public typealias PersistenceSchema = PersistenceModels.PersistenceSchema` (Section 2.3) preserves API compatibility and eliminates dual maintenance.

3. **Concrete Consolidation Areas**:
   - Plan details 4 concrete consolidation areas with complete source file paths and implementation steps:
     1. Validated Decimal/Double parsing -> `SharedUI.ValidatedDecimalParser`
     2. Calendar address editor shadowing -> `WorkspaceUI.AddressFormSheet`
     3. Date & Currency formatting -> `SharedUI.CurrencyFormatting` & `SharedUI.DateFormatting`
     4. Duplicate test tags -> `Core.TestTags`

4. **Actionability & Phasing**:
   - Plan formatted in structured Markdown with explicit paths for every change.
   - 4-phase implementation roadmap safely orders low-risk tooling cleanups before medium/high-risk domain and UI refactorings.

---

## 3. Caveats

- **Runtime Performance Benchmarks**: Allocating `NumberFormatter` inside view render passes identified in `InvoiceFormatting.swift` causes micro-allocations; actual frame-rate impact should be measured via Instruments during scrolling after Phase 2 refactoring.
- **No Integrity Violations Found**: Codebase state and refactoring plan verified genuine. No hardcoded test shortcuts, facade implementations, or self-certifying work detected.

---

## 4. Conclusion

`REFACTOR_PLAN.md` meets all project criteria. Technical analysis accurate, plan fully actionable, concrete consolidation areas fully specified with source paths, baseline architecture script clean. Verdict: **APPROVE**.

---

## 5. Verification Method

To independently verify codebase state and plan alignment:

1. **Architecture Guardrails**:
   ```bash
   ./scripts/architecture-check.sh
   ```
   Expectation: All 6 checks pass cleanly with exit code 0.

2. **Package Test Verification**:
   ```bash
   swift test --package-path Packages/Feature.Invoices
   swift test --package-path Packages/Feature.InvoiceTemplateEditor
   swift test --package-path Packages/SharedUI
   ```
   Expectation: All test suites compile and pass.

3. **File Path Verification**:
   Inspect line ranges in `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceRootView.swift` (lines 22, 79) and `Packages/Data/Sources/Data/Persistence/PersistenceSchema.swift` (lines 5-30).

---

## Challenge Summary (Adversarial Review)

**Overall Risk Assessment**: LOW

### Stress Test Results

| Attack Scenario / Assumption | Expected Behavior | Actual Behavior | Verdict |
|---|---|---|---|
| Moving `BulkClaimValidationService` to `Core/Domain/Validation/` breaks dependencies | Pure snapshot validation functions without database import | `BulkClaimValidationService` depends only on `Foundation` and `Core` snapshots | PASS |
| Typealiasing `Data.PersistenceSchema` breaks existing callers | Typealias resolves `Data.PersistenceSchema.appModels` to `PersistenceModels` | Identical static property accessor preserved | PASS |
| Centralizing `TestTags` into `Core` breaks non-Core test targets | `@Tag static var unit` available via `import Core` | All test targets depend on `Core` | PASS |

---

## Recommendations for Implementation Phase

1. **Execute Phase 1 First**: Ensure `scripts/refactor-verify.sh` tests all packages before performing code moves in Phase 2 & 3.
2. **Preserve Public API Contracts**: When splitting `InvoiceDocumentSections.swift`, ensure all exported SwiftUI views maintain `public` access modifiers to prevent target import errors.
