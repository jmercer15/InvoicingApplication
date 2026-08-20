# Comprehensive Architecture Refactoring Plan

**Target Application**: InvoicingApplication (macOS)
**Date**: August 10, 2026
**Status**: Implemented and Certified

---

## Executive Summary

> Implementation completed August 17, 2026. Architecture, package, UI decomposition,
> persistence-boundary, warning-cleanup, and verification work described below is implemented.
> Final certification commands and results appear in **Implementation Record**.

An exhaustive analysis of the codebase—spanning UI feature packages, domain and core data layers, persistence models, SPM build manifests, tooling scripts, and repository layout—reveals a well-architected, modular Swift multi-package workspace. The architecture enforces strict domain boundary rules using `./scripts/architecture-check.sh` and isolates SwiftData concurrency via thread-safe snapshot DTOs (`SnapshotMapping.swift`) and background `@ModelActor`s.

However, key architectural debt, code duplication, file bloat, and state management hazards impair long-term maintainability. This document provides a comprehensive, phased refactoring plan to eliminate redundancies, split bloated source files, realign domain boundaries, and update verification tooling.

---

## Section 1: Macro & Micro Architectural Analysis

### 1.1 Macro-Level Architecture & Data Flow Analysis

#### A. `@State` Initialization Anti-Pattern in `@Observable` View Models
- **Location**: `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceRootView.swift` (lines 22 & 79)
- **Defect Description**:
  `InvoiceRootView` declares `@State private var viewModel: InvoiceEditorViewModel` (line 22). In its custom initializer `init(viewModel:...)`, it performs `_viewModel = State(initialValue: viewModel)` (line 79).
  In SwiftUI with `@Observable`, `@State` storage is allocated only once when the view is first initialized in the view tree. If the parent view (`TableLayoutInvoiceEditorView`) updates or replaces `session.viewModel`, `@State` ignores the new reference, keeping the old instance locked in view storage. This causes stale state bugs during workspace transitions and document switches.
- **Architectural Impact**: Violates SwiftUI data flow contracts for reference-type `@Observable` view models.

#### B. Complex State Management Hazards
- **Locations**:
  - `InvoiceRootView.swift` (lines 22–35): Manages 11 distinct state properties (`@State private var viewModel`, `@State private var editorToolbarState`, `@State private var commandActions`, `@State private var templateSaveState`, `@State private var templateSaveTracker`, `@State private var invalidTemplateInputIDs`, `@State private var failedOpeningInvoiceID`, `@State private var creationRequestState`, `@State private var isPreparingWorkspaceHandoff`, `@SceneStorage editorInspectorPresented`, `@SceneStorage restoredSelectedInvoiceID`).
  - `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesView.swift` (lines 21–38): Manages 9 state properties (`@State var isMultiSelectMode`, `@State var selectedInvoiceIDs`, `@State var bulkActionActivity`, `@State var bulkActionResult`, `@State var emailShareCoordinator`, `@State var bulkExportTask`, `@State var bulkEmailPreparationTask`, `@State var deleteBatch`, `isDeleteConfirmationPresented`).
- **Architectural Impact**: Dispersed state properties increase synchronization risk and make state transitions difficult to test in isolation.

#### C. SPM Package Boundary Hygiene & Naming Decay
- **Locations**:
  - `Packages/DTOMacros/`: Abandoned empty directory containing no `Package.swift` and no `.swift` source files.
  - `Packages/Feature.InvoiceTemplateEditor/`: Directory name (`Feature.InvoiceTemplateEditor`) differs from its SPM product/target name (`InvoiceTableLayoutEditor`).
- **Architectural Impact**: Creates confusion for developers navigating package dependencies and breaks automatic tooling scripts.

#### D. Incomplete Verification Tooling
- **Location**: `scripts/refactor-verify.sh` (lines 21–29)
- **Defect Description**:
  `scripts/refactor-verify.sh` currently executes `swift test` for only 2 packages (`SharedUI` and `Feature.Settings`), and performs `swift build` for `Feature.Calendar` and the main App target. It completely skips running tests for 11 active packages (`Core`, `Data`, `DataInterfaces`, `WorkspaceUI`, `AppShell`, `Feature.BillingHub`, `Feature.Clients`, `Feature.Invoices`, `Feature.NDIS`, `Feature.InvoiceTemplateEditor`, `PersistenceModels`).
- **Architectural Impact**: Provides false confidence during automated CI/refactoring checks by ignoring test suites across 80% of the codebase.

---

### 1.2 Micro-Level Code Duplication & Bloat Analysis

#### A. Number & Decimal Input Parsing Duplication
- **Locations**:
  1. `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceFilterAmountField.swift` (lines 10–53) (`InvoiceFilterAmountInput`)
  2. `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceValidatedDecimalField.swift` (lines 5–58 & 179–220) (`InvoiceDecimalInput`, `InvoiceDoubleInput`)
- **Defect Description**:
  Both feature packages instantiate identical `NumberFormatter` objects (`.decimal` style, `isLenient = false`, `usesGroupingSeparator = true`), invoke `try formatter.getObjectValue(&value, for: text, range: &consumedRange)`, and perform identical consumed range boundary checks.
- **Architectural Impact**: Code duplication; localization fixes or keypad fallback logic (e.g. handling comma vs dot separators) added to one editor field do not propagate to filter fields.

#### B. Component Shadowing & Address Form Abstraction Bypassing
- **Locations**:
  1. `Packages/WorkspaceUI/Sources/WorkspaceUI/AddressEditingSheet.swift` (lines 5–290)
  2. `Packages/WorkspaceUI/Sources/WorkspaceUI/AddressFormSheet.swift` (lines 5–51)
  3. `Packages/Feature.Calendar/Sources/Feature_Calendar/Views/SessionEditor/SessionAddressEditingSheet.swift` (lines 8–52)
- **Defect Description**:
  `WorkspaceUI` provides `AddressFormSheet` wrapping `@Bindable state: AddressFormState`. `Feature.Clients` correctly uses `AddressFormSheet`. However, `Feature.Calendar` bypasses `AddressFormSheet`, manually binds 10 individual keypaths to `WorkspaceUI.AddressEditingSheet`, and defines `struct AddressEditingSheet: View`, which shadows `WorkspaceUI.AddressEditingSheet`.
- **Architectural Impact**: Name collision and duplication of binding boilerplate.

#### C. Ad-Hoc Date & Currency Formatter Churn
- **Locations**:
  1. `Packages/SharedUI/Sources/SharedUI/Helpers/CurrencyFormatting.swift` (lines 5–79)
  2. `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceFormatting.swift` (lines 411–518, 1017–1048) (`InvoiceMoneyFormatter`, `InvoiceDateFormatter`)
  3. `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesContentToolbar.swift` (line 28) (`shortDateFormatter`)
  4. `Packages/PersistenceModels/Sources/PersistenceModels/Utilities/NDISPriceUtilities.swift` (lines 74–81)
- **Defect Description**:
  `SharedUI` defines centralized `CurrencyFormatting` and `DateFormatting` using Foundation `FormatStyle`. However, `InvoiceFormatting.swift` instantiates new `NumberFormatter()` instances on every render pass in `currencySymbol` and `currencyString`, while `InvoicesContentToolbar.swift` and `NDISPriceUtilities.swift` instantiate local `DateFormatter` / `NumberFormatter` singletons.
- **Architectural Impact**: Allocating `NumberFormatter` inside view render passes introduces performance overhead during document scrolling and live zooming.

#### D. Direct Code Duplication in Persistence Schema
- **Locations**:
  1. `Packages/PersistenceModels/Sources/PersistenceModels/PersistenceSchema.swift` (lines 5–30)
  2. `Packages/Data/Sources/Data/Persistence/PersistenceSchema.swift` (lines 5–30)
- **Defect Description**:
  `Packages/Data/Sources/Data/Persistence/PersistenceSchema.swift` contains a verbatim 26-line duplicate copy of the `public static let appModels: [any PersistentModel.Type]` array defined in `PersistenceModels.PersistenceSchema`.
- **Architectural Impact**: Maintenance risk; adding a new model to `PersistenceModels` could result in schema mismatch if `Data` is not manually updated.

#### E. Misplaced Domain Logic & Layer Inversion
- **Locations**:
  1. `Packages/PersistenceModels/Sources/PersistenceModels/Utilities/NDISPriceUtilities.swift` (lines 6–153): Contains domain price calculation algorithms AND a private `priceFormatter: NumberFormatter` with currency formatting methods (`formatPrice`, `formatPriceRange`).
  2. `Packages/Data/Sources/Data/Services/BulkClaimValidationService.swift` (lines 4–142): Validates `BulkClaimLineSnapshot` DTOs using pure domain rules (ABN length, NDIS numeric check, GST codes, time parsing). Imports no SwiftData or database context, but resides in `Packages/Data`.
- **Architectural Impact**: Layer inversion; domain logic and string formatting leak into the persistence model layer, while pure domain validation leaks into the infrastructure data layer.

#### F. Test Harness Copy-Paste (14 Duplicate Files)
- **Locations**: 14 `TestTags.swift` files across test targets (`Packages/Core/Tests/CoreTests/TestTags.swift`, `Packages/AppShell/Tests/AppShellTests/TestTags.swift`, `Packages/Feature.Invoices/Tests/Feature_InvoicesTests/TestTags.swift`, etc.).
- **Defect Description**: Each file contains an identical 8-line extension declaring `@Tag static var unit: Self` and `@Tag static var integration: Self`.
- **Architectural Impact**: Fragmented test harness setup across package boundaries.

---

## Section 2: Structural Changes & Data Flow Improvements

### 2.1 Fixing `@State` Initialization in `InvoiceRootView.swift`
- **File**: `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceRootView.swift` (lines 22 & 79)
- **Refactoring Step**:
  1. Replace `@State private var viewModel: InvoiceEditorViewModel` with `@Bindable var viewModel: InvoiceEditorViewModel` (or pass `@Bindable` directly from `TableLayoutInvoiceEditorView`).
  2. Remove `_viewModel = State(initialValue: viewModel)` from `InvoiceRootView.init(viewModel:...)`.
  3. Ensure view model updates from parent views automatically trigger SwiftUI body re-evaluations without stale `@State` retention.

### 2.2 Layer Realignment: Domain Validation & Pricing Logic
- **Refactoring Steps**:
  1. **Move `BulkClaimValidationService`**: Relocate `BulkClaimValidationService.swift` (lines 4–142) from `Packages/Data/Sources/Data/Services/` to `Packages/Core/Sources/Core/Domain/Validation/`. Update namespace and exports so feature packages and offline validators can consume pure snapshot validation without depending on `Data`.
  2. **Extract NDIS Pricing to `Core`**: Move domain price resolution algorithms and strategies (`NDISPriceUtilities`, `NDISPriceError`, `PriceFallbackStrategy`) from `Packages/PersistenceModels/Sources/PersistenceModels/Utilities/NDISPriceUtilities.swift` to `Packages/Core/Sources/Core/Domain/Pricing/`.
  3. **Delegate NDIS Currency Formatting**: Remove `priceFormatter: NumberFormatter` from NDIS utilities and delegate price string formatting to `SharedUI.CurrencyFormatting`.

### 2.3 Package Dependency Graph & Schema Hygiene
- **Refactoring Steps**:
  1. **Delete `DTOMacros`**: Remove empty directory `Packages/DTOMacros/`.
  2. **Typealias `PersistenceSchema`**: Replace the 26-line duplicate array in `Packages/Data/Sources/Data/Persistence/PersistenceSchema.swift` with a single typealias:
     ```swift
     public typealias PersistenceSchema = PersistenceModels.PersistenceSchema
     ```
  3. **Remove Redundant Re-export Files**: Delete redundant 3-line typealias files in `Packages/Data/Sources/Data/Models/` (`CalendarPreferences.swift`, `CalendarPreferencesStore.swift`, `EntityPredicateBuilders.swift`) and import target packages directly where used.

### 2.4 Decomposing Monolithic Data Services
- **File**: `Packages/Data/Sources/Data/Services/NDISBillingIntegrationService.swift` (1,028 lines)
- **Refactoring Step**: Decompose `NDISBillingIntegrationService` into three targeted components:
  1. `NDISInvoiceBuilder.swift`: SwiftData invoice creation, line item generation, and relationship linking.
  2. `NDISSessionClaimProcessor.swift`: Session claim line calculation, travel distance/charge computation, and validation vector assembly.
  3. `NDISBillingIntegrationService.swift`: Lightweight facade coordinating high-level workflows.

---

## Section 3: File Reorganizations & Splitting Bloated Files

### 3.1 Splitting Bloated Source Files in `InvoiceTableLayoutEditor`

#### A. `InvoiceDocumentSections.swift` (1,845 lines)
- **Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceDocumentSections.swift`
- **Decomposition Target**: Split into 4 files:
  1. `InvoiceDocumentLayoutTokens.swift` (lines 3–49): Contains `InvoiceDocumentLayout` and `PartyPreviewProfile`.
  2. `IntrinsicPartyRowLayout.swift` (lines 1124–1192): Custom SwiftUI `Layout` implementation for party headers.
  3. `InvoiceDocumentPartySections.swift` (lines 53–1110, 1194–1420): `InvoiceDocumentSections`, `PartyPreviewInspectorTargets`, and `PartyPreviewBlock`.
  4. `InvoiceDocumentDetailsSections.swift` (lines 1422–1845): `InvoiceDetailsPreviewBlock`, `InvoiceDetailsTableStyle`, `DetailTableCellBorders`, `ThemedDocumentBandedCard`, `TotalsGrandTotalGridRow`, and `PaymentDetailRowView`.

#### B. `InvoiceFormatting.swift` (1,078 lines)
- **Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceFormatting.swift`
- **Decomposition Target**: Split into 3 files:
  1. `InvoiceThemePalette.swift` (lines 7–275): `InvoiceThemePalette` and `InvoiceDocumentResolvedStyle`.
  2. `InvoiceDocumentDesignTokens.swift` (lines 276–410, 536–1016): `InvoiceDocumentDesign`, `InvoiceLineItemsTypography`, `InvoiceLineItemsTableStyle`, `DocumentBandedCardStyle`, and `LineItemCellChromeModifier`.
  3. `InvoiceFormatters.swift` (lines 411–531, 1017–1048): Refactor `InvoiceMoneyFormatter` and `InvoiceDateFormatter` to delegate directly to `SharedUI.CurrencyFormatting` and `SharedUI.DateFormatting`.

#### C. `InvoiceDocumentPreview.swift` (939 lines)
- **Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceDocumentPreview.swift`
- **Decomposition Target**: Split into 3 files:
  1. `InvoiceDocumentPreview.swift` (lines 1–682): View hierarchy, pagination measurement publication policy (`InvoicePaginationMeasurementPublicationPolicy`), scaled page views.
  2. `InvoicePDFExportServices.swift` (lines 683–875): Relocate `InvoicePDFRenderer` and `InvoicePDFSavePanel` to co-locate with `InvoicePDFFileWriter.swift`.
  3. `PreviewCommandScrollZoomMonitor.swift` (lines 877–938): `NSViewRepresentable` scroll and zoom monitor.

#### D. `InvoiceRootView.swift` (810 lines)
- **Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceRootView.swift`
- **Decomposition Target**: Split into 2 files:
  1. `InvoiceRootView.swift` (lines 1–550): Main body and workspace mode routing.
  2. `InvoiceRootViewToolbarActions.swift` (lines 551–810): Toolbar builder, inspector toggle actions, and command execution delegates.

---

### 3.2 Feature & App Layout Cleanups

1. **Consolidate Invoices Toolbar Components**:
   Combine `InvoicesViewToolbar.swift` (186 lines) and `InvoicesContentToolbar.swift` (206 lines) in `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/` into a single cohesive `InvoicesToolbarComponents.swift`.
2. **Fix File Header Misalignment**:
   Correct line 2 header comment in `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesViewList.swift` (currently reads `// InvoicesView.swift` -> change to `// InvoicesViewList.swift`).
3. **Repository Root Artifact Cleanup**:
   - Delete root profiling artifact: `default.profraw`
   - Add `*.profraw` to `.gitignore`
   - Delete root build scratch logs: `scratch_build.log`, `scratch_build2.log`, `scratch_build3.log`, `scratch_build4.log`, `scratch_build5.log`
   - Clean non-compliant root directory `Agents/` (move any remaining logs to `.agents/` and remove `Agents/`).
4. **Tooling Script Modernization**:
   - Delete 13 single-use legacy XCTest -> Swift Testing migration scripts in `scripts/` (`balance_expect_parens.py`, `dedupe_test_harness.py`, `migrate_xctest_to_swift_testing.py`, etc.) and remove `scripts/__pycache__/`.

---

## Section 4: Code Deduplication & Consolidation (Concrete Areas)

### Area 1: Validated Decimal & Double Input Parsing
- **Affected Files**:
  1. `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceFilterAmountField.swift` (lines 10–53)
  2. `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceValidatedDecimalField.swift` (lines 5–58 & 179–220)
- **Consolidation Plan**:
  Extract `ValidatedDecimalParser` and `ValidatedDecimalField` into `Packages/SharedUI/Sources/SharedUI/Components/ValidatedDecimalField.swift`.
  - Consolidate strict locale parsing (`getObjectValue(&value, for: text, range: &consumedRange)`), keypad dot/comma fallback logic (`^\d+\.\d+$`), and fraction formatting into `ValidatedDecimalParser`.
  - Replace `InvoiceFilterAmountInput`, `InvoiceDecimalInput`, and `InvoiceDoubleInput` across both packages with calls to `SharedUI.ValidatedDecimalParser`.

### Area 2: Address Form Sheet & Component Shadowing
- **Affected Files**:
  1. `Packages/WorkspaceUI/Sources/WorkspaceUI/AddressEditingSheet.swift` (lines 5–290)
  2. `Packages/WorkspaceUI/Sources/WorkspaceUI/AddressFormSheet.swift` (lines 5–51)
  3. `Packages/Feature.Calendar/Sources/Feature_Calendar/Views/SessionEditor/SessionAddressEditingSheet.swift` (lines 8–52)
- **Consolidation Plan**:
  Refactor `SessionAddressEditingSheet.swift` in `Feature.Calendar` to consume `WorkspaceUI.AddressFormSheet` using `@Bindable state: AddressFormState`.
  Rename the local wrapper struct in `Feature.Calendar` from `AddressEditingSheet` to `SessionAddressEditingSheet` to eliminate local shadowing of `WorkspaceUI.AddressEditingSheet`.

### Area 3: Centralized Date & Currency Formatters vs Ad-Hoc Singletons
- **Affected Files**:
  1. `Packages/SharedUI/Sources/SharedUI/Helpers/CurrencyFormatting.swift` (lines 5–79)
  2. `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceFormatting.swift` (lines 411–518, 1017–1048)
  3. `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesContentToolbar.swift` (line 28)
  4. `Packages/PersistenceModels/Sources/PersistenceModels/Utilities/NDISPriceUtilities.swift` (lines 74–81)
- **Consolidation Plan**:
  Enhance `SharedUI.CurrencyFormatting` and `SharedUI.DateFormatting` to cover currency symbol extraction, compact currency string formatting, and short date formatting.
  Replace local `NumberFormatter()` instantiations inside `InvoiceMoneyFormatter` render passes with delegates to `SharedUI.CurrencyFormatting`. Replace local static `DateFormatter` singletons in `InvoicesContentToolbar` with `SharedUI.DateFormatting`.

### Area 4: Centralizing Test Tag Extensions Across SPM Test Targets
- **Affected Files**: 14 `TestTags.swift` files across package test directories:
  - `Packages/AppShell/Tests/AppShellTests/TestTags.swift`
  - `Packages/Core/Tests/CoreTests/TestTags.swift`
  - `Packages/Data/Tests/DataTests/BusinessLogic/TestTags.swift`
  - `Packages/Data/Tests/DataTests/Services/TestTags.swift`
  - `Packages/Data/Tests/DataTests/UseCases/TestTags.swift`
  - `Packages/Data/Tests/DataTests/Validation/TestTags.swift`
  - `Packages/DataInterfaces/Tests/DataInterfacesTests/TestTags.swift`
  - `Packages/Feature.BillingHub/Tests/Feature_BillingHubTests/TestTags.swift`
  - `Packages/Feature.Calendar/Tests/Feature_CalendarTests/TestTags.swift`
  - `Packages/Feature.Clients/Tests/Feature_ClientsTests/TestTags.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Tests/InvoiceTableLayoutEditorTests/TestTags.swift`
  - `Packages/Feature.Invoices/Tests/Feature_InvoicesTests/TestTags.swift`
  - `Packages/Feature.NDIS/Tests/Feature_NDISTests/TestTags.swift`
  - `Packages/SharedUI/Tests/SharedUITests/TestTags.swift`
- **Consolidation Plan**:
  Declare `public extension Tag` for `@Tag static var unit: Self` and `@Tag static var integration: Self` inside test-only `Packages/Core/Sources/CoreTesting/TestTags.swift`; production `Core` must not link Swift Testing.
  Delete the 13 duplicate `TestTags.swift` files across all other test packages.

---

## Section 5: Phased Actionable Implementation Roadmap

```
+-----------------------------------------------------------------------------+
| Phase 1: Package Cleanup, Test Harness & Tooling Modernization (Low Risk)   |
| - Delete Packages/DTOMacros                                                 |
| - Centralize TestTags.swift in Core & remove 13 duplicate files             |
| - Clean root profraw, scratch logs, non-compliant Agents/ folder            |
| - Remove 13 legacy Python migration scripts in scripts/                     |
| - Update scripts/refactor-verify.sh to test all 14 packages                 |
+-----------------------------------------------------------------------------+
                                      |
                                      v
+-----------------------------------------------------------------------------+
| Phase 2: Code Deduplication & Shared Component Abstractions (Medium Risk)   |
| - Extract ValidatedDecimalField & Parser to SharedUI                        |
| - Standardize SessionAddressEditingSheet to consume AddressFormSheet        |
| - Unify Date & Currency formatters around SharedUI helpers                  |
+-----------------------------------------------------------------------------+
                                      |
                                      v
+-----------------------------------------------------------------------------+
| Phase 3: Domain & Data Layer Realignment (Medium-High Risk)                 |
| - Relocate BulkClaimValidationService to Core/Domain/Validation/            |
| - Extract NDIS pricing algorithms to Core/Domain/Pricing/                   |
| - Typealias PersistenceSchema in Data to PersistenceModels.PersistenceSchema|
| - Decompose NDISBillingIntegrationService (1,028 lines) into sub-services   |
+-----------------------------------------------------------------------------+
                                      |
                                      v
+-----------------------------------------------------------------------------+
| Phase 4: UI File Decomposition & State Refactoring (Medium Risk)            |
| - Fix @State initialization anti-pattern in InvoiceRootView.swift           |
| - Split InvoiceDocumentSections.swift (1,845 lines) into 4 sub-files        |
| - Split InvoiceFormatting.swift (1,078 lines) into 3 sub-files              |
| - Split InvoiceDocumentPreview.swift (939 lines) into 3 sub-files           |
| - Split InvoiceRootView.swift (810 lines) into 2 sub-files                  |
| - Consolidate InvoicesViewToolbar and InvoicesContentToolbar                |
+-----------------------------------------------------------------------------+
```

---

## Section 6: Verification & Test Impact Assessment

### 6.1 Baseline Verification Status
The current repository state was verified prior to refactoring plan finalization:

1. **Architecture Guardrails Script (`./scripts/architecture-check.sh`)**:
   - Status: **PASSED** (6/6 rule checks clean: forbidden AppShell imports, workspace search ownership, model container creation, safe model actor fetches).
2. **Feature.Invoices Test Suite (`swift test --package-path Packages/Feature.Invoices`)**:
   - Status: **PASSED** (75/75 tests passed across 4 test suites in 0.696s).
3. **Feature.InvoiceTemplateEditor Test Suite (`swift test --package-path Packages/Feature.InvoiceTemplateEditor`)**:
   - Status: **PASSED** (159/159 tests passed across 8 test suites in 0.897s).

### 6.2 Phase-by-Phase Verification Protocol

Every implementation step must run the following verification pipeline before proceeding:

```bash
# 1. Verify architecture boundaries
./scripts/architecture-check.sh

# 2. Execute test suite for modified packages
swift test --package-path Packages/Core
swift test --package-path Packages/SharedUI
swift test --package-path Packages/WorkspaceUI
swift test --package-path Packages/Data
swift test --package-path Packages/Feature.Invoices
swift test --package-path Packages/Feature.InvoiceTemplateEditor

# 3. Execute updated master verification script
./scripts/refactor-verify.sh
```

### 6.3 Implementation Record

Certification completed August 17, 2026:

- Focused combined billable-draft filter regression passed, covering matching client,
  wrong client, inclusive date boundaries, and wrong status.
- `./scripts/architecture-check.sh` passed with zero architecture violations.
- `./scripts/refactor-verify.sh` passed all package builds/tests and application tests.
- `xcodebuild test -project InvoicingApplication.xcodeproj -scheme InvoicingApplication
  -destination 'platform=macOS'` passed.
- Repository-owned warning scan passed with zero warnings. Tool-only destination-selection
  and App Intents metadata notices remain documented outside repository-warning scope.
- Shared Swift Testing tags live in test-only `CoreTesting`; production app launcher and
  debug dylib were verified to contain no `Testing.framework` runtime dependency.
- Owned-source metric reported 944 Swift files; `.agents`, build data, dependency checkouts,
  DerivedData, and `.git` excluded.
- `git diff --check -- . ':(exclude).agents/**'` passed before commit.
