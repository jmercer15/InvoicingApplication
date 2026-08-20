# Aggregated Architecture Synthesis & Refactoring Strategy

## Executive Summary
Exploration across UI/Feature packages, Domain/Core data layers, build manifests, scripts, and repository layout reveals a modular Swift multi-package architecture with strong boundary rules, but significant opportunities for consolidation, deduplication, and file organization.

---

## 1. Macro-Level Architecture & Data Flow Analysis

### A. `@State` Initialization Anti-Pattern in `@Observable` View Models
- **Location**: `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceRootView.swift` (lines 22, 79)
- **Issue**: `InvoiceRootView` receives `viewModel: InvoiceEditorViewModel` in `init` and assigns `_viewModel = State(initialValue: viewModel)`. In SwiftUI with `@Observable`, `@State` storage is instantiated once on initial view creation. If parent (`TableLayoutInvoiceEditorView`) passes an updated `session.viewModel`, `@State` ignores the change, causing stale state bugs.
- **Structural Strategy**: Convert `@State private var viewModel` to `@Bindable var viewModel` or pass `@Bindable` directly from the parent view.

### B. Package Dependency Graph & Boundary Hygiene
- **Locations**: `Packages/AppShell/Package.swift`, `Packages/DTOMacros/`, `Packages/Feature.InvoiceTemplateEditor/Package.swift`
- **Issue**:
  - `Packages/DTOMacros/` is an abandoned, empty directory missing `Package.swift` and containing no `.swift` source code.
  - `Feature.InvoiceTemplateEditor` uses mismatched folder vs product target naming (`Feature.InvoiceTemplateEditor` directory vs `InvoiceTableLayoutEditor` target name).
- **Structural Strategy**: Remove abandoned `DTOMacros` package directory; document target naming conventions in project architecture guidelines.

### C. Test Verification Script Completeness
- **Location**: `scripts/refactor-verify.sh` (lines 21–29)
- **Issue**: `scripts/refactor-verify.sh` only tests `SharedUI` and `Feature.Settings`, and builds `Feature.Calendar` and App target. It skips testing 11 active packages (`Core`, `Data`, `DataInterfaces`, `WorkspaceUI`, `AppShell`, `Feature.BillingHub`, `Feature.Clients`, `Feature.Invoices`, `Feature.NDIS`, `Feature.InvoiceTemplateEditor`).
- **Structural Strategy**: Update `refactor-verify.sh` to execute `swift test` across all active SPM packages in sequence or via workspace test execution.

---

## 2. Micro-Level Code Duplication & Consolidation Areas

### Area 1: Validated Decimal & Double Input Parsing
- **Locations**:
  1. `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceFilterAmountField.swift` (lines 10–53) (`InvoiceFilterAmountInput`)
  2. `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceValidatedDecimalField.swift` (lines 5–58, 179–220) (`InvoiceDecimalInput`, `InvoiceDoubleInput`)
- **Duplication Detail**: Both files instantiate identical `NumberFormatter` (`.decimal` style, `isLenient = false`, `usesGroupingSeparator = true`), call `getObjectValue(&value, for: text, range: &consumedRange)`, and check range bounds.
- **Deduplication Strategy**: Extract shared `ValidatedDecimalField` and `DecimalInputParser` into `SharedUI` (or `WorkspaceUI`) and replace local implementations in `Feature.Invoices` and `Feature.InvoiceTemplateEditor`.

### Area 2: Address Form Sheet & Component Shadowing
- **Locations**:
  1. `Packages/WorkspaceUI/Sources/WorkspaceUI/AddressEditingSheet.swift` (lines 5–290)
  2. `Packages/WorkspaceUI/Sources/WorkspaceUI/AddressFormSheet.swift` (lines 5–51)
  3. `Packages/Feature.Calendar/Sources/Feature_Calendar/Views/SessionEditor/SessionAddressEditingSheet.swift` (lines 8–52)
- **Duplication & Structural Detail**: `WorkspaceUI` provides `AddressFormSheet` wrapping `@Bindable state: AddressFormState`. `Feature.Clients` correctly uses `AddressFormSheet`. `Feature.Calendar` bypasses `AddressFormSheet`, directly binds 10 individual keypaths to `WorkspaceUI.AddressEditingSheet`, and defines `struct AddressEditingSheet: View`, which shadows `WorkspaceUI.AddressEditingSheet`.
- **Deduplication Strategy**: Refactor `SessionAddressEditingSheet.swift` to consume `WorkspaceUI.AddressFormSheet` with `@Bindable state: AddressFormState`, and rename local wrapper struct to `SessionAddressEditingSheet`.

### Area 3: Ad-Hoc Date & Currency Formatters vs. Shared Formatters
- **Locations**:
  1. `Packages/SharedUI/Sources/SharedUI/Helpers/CurrencyFormatting.swift` (lines 5–79)
  2. `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceFormatting.swift` (lines 411–518, 1017–1048) (`InvoiceMoneyFormatter`, `InvoiceDateFormatter`)
  3. `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesContentToolbar.swift` (line 28) (`shortDateFormatter`)
- **Duplication & Performance Detail**: `SharedUI` provides centralized `CurrencyFormatting` and `DateFormatting` using modern Foundation `FormatStyle`. `InvoiceFormatting.swift` instantiates new `NumberFormatter()` objects on every formatting pass in `currencySymbol` and `currencyString`, while `InvoicesContentToolbar.swift` creates duplicate legacy `DateFormatter` singletons.
- **Deduplication Strategy**: Centralize formatting calls in `SharedUI` helpers and replace ad-hoc `NumberFormatter` / `DateFormatter` instantiations across feature packages.

### Area 4: Test Tag Extensions (14 Duplicate Files)
- **Locations**: 14 `TestTags.swift` files across test targets (`Packages/Core/Tests/CoreTests/TestTags.swift`, `Packages/AppShell/Tests/AppShellTests/TestTags.swift`, `Packages/Feature.Invoices/Tests/Feature_InvoicesTests/TestTags.swift`, etc.)
- **Duplication Detail**: Verbatim copy of `@Tag static var unit: Self` and `@Tag static var integration: Self`.
- **Deduplication Strategy**: Centralize `@Tag` definitions in `Packages/Core/Sources/Core/Testing/TestTags.swift` and remove redundant `TestTags.swift` files across individual package test targets.

---

## 3. File Reorganization & Bloat Reduction

### A. Splitting Bloated Source Files
1. **`Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceDocumentSections.swift`** (1,845 lines)
   - Split into:
     - `InvoiceDocumentLayoutTokens.swift` (`InvoiceDocumentLayout`, `PartyPreviewProfile`)
     - `IntrinsicPartyRowLayout.swift` (`IntrinsicPartyRowLayout`)
     - `InvoiceDocumentPartySections.swift` (`PartyPreviewBlock`)
     - `InvoiceDocumentDetailsSections.swift` (`InvoiceDetailsPreviewBlock`, `DetailTableCellBorders`, `TotalsGrandTotalGridRow`, etc.)
2. **`Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceFormatting.swift`** (1,078 lines)
   - Split into:
     - `InvoiceThemePalette.swift` (`InvoiceThemePalette`)
     - `InvoiceDocumentDesignTokens.swift` (`InvoiceDocumentDesign`, `InvoiceLineItemsTypography`, `InvoiceLineItemsTableStyle`)
     - `InvoiceFormatters.swift` (`InvoiceMoneyFormatter`, `InvoiceDateFormatter` delegation)
3. **`Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceDocumentPreview.swift`** (939 lines)
   - Split into:
     - `InvoiceDocumentPreview.swift` (View hierarchy & zoom only)
     - `InvoicePDFExportServices.swift` (`InvoicePDFRenderer`, `InvoicePDFSavePanel`)
     - `PreviewCommandScrollZoomMonitor.swift` (`PreviewCommandScrollZoomMonitor`)
4. **`Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceRootView.swift`** (810 lines)
   - Split into `InvoiceRootView.swift` (view structure) and `InvoiceRootViewToolbarActions.swift`.

### B. Moving & Re-locating Misplaced Components
- Move `InvoicePDFRenderer` (lines 683–743) and `InvoicePDFSavePanel` (lines 745–875) from `InvoiceDocumentPreview.swift` into `InvoicePDFExportServices.swift` alongside `InvoicePDFFileWriter.swift`.
- Combine `InvoicesViewToolbar.swift` (186 lines) and `InvoicesContentToolbar.swift` (206 lines) in `Feature.Invoices` into a single cohesive `InvoicesToolbarComponents.swift`.
- Fix header comment on line 2 of `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesViewList.swift` (currently reads `// InvoicesView.swift`).

### C. Repository Layout & Artifact Cleanup
- **Remove Root Pollution**: Delete `/Users/user/Developer/InvoicingApplication/InvoicingApplication/default.profraw` and add `*.profraw` to `.gitignore`.
- **Remove Build Logs**: Delete `scratch_build.log`, `scratch_build2.log`, `scratch_build3.log`, `scratch_build4.log`, `scratch_build5.log`.
- **Clean Up Legacy Python Scripts**: Remove 13 single-use XCTest -> Swift Testing migration scripts and `scripts/__pycache__/` in `scripts/`.
- **Enforce Agent Directory Standards**: Remove non-compliant capitalized root directory `Agents/`.
