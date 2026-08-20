# Handoff Report: Architecture Refactoring Plan Creation

## 1. Observation

1. **Synthesized Architecture Findings**:
   - Synthesized findings in `.agents/orchestrator_architecture/synthesis.md` and explorer handoff reports (`explorer_1`, `explorer_2`, `explorer_3`) were verified against the live codebase.
2. **State Initialization Anti-Pattern**:
   - `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceRootView.swift` (lines 22 & 79): Declares `@State private var viewModel: InvoiceEditorViewModel` and sets `_viewModel = State(initialValue: viewModel)` in `init`.
3. **Bloated Source Files**:
   - `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceDocumentSections.swift`: 1,845 lines.
   - `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceFormatting.swift`: 1,078 lines.
   - `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceDocumentPreview.swift`: 939 lines.
   - `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceRootView.swift`: 810 lines.
4. **Code Duplication & Layer Inversion**:
   - Area 1: `InvoiceFilterAmountInput` (`InvoiceFilterAmountField.swift`:10–53) duplicates `InvoiceDecimalInput` / `InvoiceDoubleInput` (`InvoiceValidatedDecimalField.swift`:5–58, 179–220).
   - Area 2: `SessionAddressEditingSheet.swift` (`Feature.Calendar`:8–52) shadows `WorkspaceUI.AddressEditingSheet` and bypasses `WorkspaceUI.AddressFormSheet`.
   - Area 3: Formatting churn in `InvoiceFormatting.swift` (lines 411–518, 1017–1048), `InvoicesContentToolbar.swift` (line 28), and `NDISPriceUtilities.swift` (lines 74–81).
   - Area 4: 14 duplicate `TestTags.swift` files across package test targets.
   - Domain logic inversion: `NDISPriceUtilities.swift` in `PersistenceModels` and `BulkClaimValidationService.swift` in `Data`.
   - Schema duplication: `PersistenceSchema.swift` in `Data` duplicates `PersistenceSchema` in `PersistenceModels`.
5. **Verification Baseline Execution**:
   - `./scripts/architecture-check.sh`: Executed via `run_command`. Result: **PASSED** (6/6 checks clean).
   - `swift test --package-path Packages/Feature.Invoices`: Executed via `run_command` with `BypassSandbox: true`. Result: **PASSED** (75 tests passed in 0.696s).
   - `swift test --package-path Packages/Feature.InvoiceTemplateEditor`: Executed via `run_command` with `BypassSandbox: true`. Result: **PASSED** (159 tests passed in 0.897s).
6. **Artifact Deliverables**:
   - `REFACTOR_PLAN.md` written to `/Users/user/Developer/InvoicingApplication/InvoicingApplication/REFACTOR_PLAN.md`.
   - Copy written to `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_architecture/REFACTOR_PLAN.md`.

---

## 2. Logic Chain

1. **Data Flow & Concurrency**:
   - `@State` storage in SwiftUI is owned by view node identity. Wrapping `@Observable` view models in `@State` and initializing `_viewModel` inside `init(viewModel:)` prevents parent view model mutations from being reflected in the view tree. Converting to `@Bindable` fixes this data flow bug cleanly.
2. **File Decomposition**:
   - High line count files in `InvoiceTableLayoutEditor` bundle unrelated concerns (PDF generation, typography tokens, border modifiers, inspector targets, custom layout logic). Splitting them into single-responsibility files reduces compile dependency cascades and merge conflicts.
3. **Consolidation & Layer Hygiene**:
   - Shared input parsing, address form wrappers, and formatting helpers belong in `SharedUI` and `WorkspaceUI` to eliminate copy-paste logic across feature targets.
   - Pure domain validation (`BulkClaimValidationService`) and pricing algorithms (`NDISPriceUtilities`) belong in `Core`, allowing feature targets to execute validation/pricing without dragging in database dependencies.
4. **Tooling & Test Modernization**:
   - Centralizing `@Tag` test extensions in `Core` removes 13 duplicate files. Updating `refactor-verify.sh` guarantees test execution across all 14 packages.

---

## 3. Caveats

- **CloudKit Persistence Safety**: Model attribute original names must remain unchanged in `PersistenceModels` to maintain backward compatibility with existing CloudKit schemas.
- **Xcode Toolchain Path**: System testing requires running `swift test` commands with `BypassSandbox: true` due to macOS beta Xcode toolchain library paths (`/Users/user/Downloads/Xcode-beta.app`).

---

## 4. Conclusion

The refactoring plan `REFACTOR_PLAN.md` is complete, official, and actionable. It satisfies all acceptance criteria:
- Detailed analysis across macro data flow, micro code defects, and package boundaries.
- Explicit file paths, line numbers, and struct names for all proposed refactorings.
- 4 concrete code deduplication areas and a 4-phase implementation roadmap.
- Full documentation of baseline verification test and script results.

---

## 5. Verification Method

To verify the plan and baseline status independently:

```bash
# 1. Run architecture boundary check
./scripts/architecture-check.sh

# 2. Run feature test suites
swift test --package-path Packages/Feature.Invoices
swift test --package-path Packages/Feature.InvoiceTemplateEditor

# 3. Inspect generated refactoring plan artifacts
ls -l /Users/user/Developer/InvoicingApplication/InvoicingApplication/REFACTOR_PLAN.md
ls -l /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_architecture/REFACTOR_PLAN.md
```
