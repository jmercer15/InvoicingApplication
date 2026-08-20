# Domain, Core, and Data Layer Architecture & Code Duplication Report

## 1. Observation

Direct observations from examining package sources, models, schemas, formatters, and service implementations across `Packages/Core`, `Packages/Data`, `Packages/DataInterfaces`, and `Packages/PersistenceModels`:

### Macro-Level Architecture & Layer Boundaries
- **Core Snapshot DTO Pattern**: `Packages/Core/Sources/Core/Models/Snapshots/` defines ~19 value-type (`Sendable`, `Codable`) snapshot structs (`InvoiceSnapshot`, `ClientSnapshot`, `SessionSnapshot`, `BulkClaimLineSnapshot`, etc.). `Packages/PersistenceModels/Sources/PersistenceModels/SnapshotMapping.swift` (485 lines) maps live `@Model` instances into these thread-safe snapshots, successfully creating a concurrency barrier between background actors and main-thread UI components.
- **Background `@ModelActor` Isolation**: SwiftData context execution is separated via background `@ModelActor`s (`BulkClaimBuilderActor.swift`, `NDISComplianceValidator.swift`, `DataExporterActor.swift`, `DataImporterActor.swift`, `EventKitSyncActor.swift`, `TravelChargeAutomationActor.swift`) and ephemeral context creation (`ModelContainerFactory.makeEphemeralContext`).
- **Interface Segregation**: `Packages/DataInterfaces/Sources/DataInterfaces/` defines 25+ protocol interfaces (`BusinessPersisting`, `ClaimBatchBuilding`, `ClaimBatchPersisting`, `ImportExportCoordinating`, `NDISCatalogueFetching`, etc.) separating feature targets from concrete data persistence.

### Micro-Level Code Duplication & Misplaced Code
- **Duplicate `PersistenceSchema` Declaration**:
  - `Packages/PersistenceModels/Sources/PersistenceModels/PersistenceSchema.swift:5-30`: Declares `public enum PersistenceSchema { public static let appModels: [any PersistentModel.Type] = [ Client.self, ... ] }`.
  - `Packages/Data/Sources/Data/Persistence/PersistenceSchema.swift:5-30`: Duplicate 26-line copy of the exact same array `public static let appModels: [any PersistentModel.Type]` instead of reusing or typealiasing `PersistenceModels.PersistenceSchema`.
- **Misplaced Domain Pricing Logic & Currency Formatting in Persistence Layer**:
  - `Packages/PersistenceModels/Sources/PersistenceModels/Utilities/NDISPriceUtilities.swift:6-153`: Defines `NDISPriceUtilities`, `NDISPriceError`, `PriceFallbackStrategy`, price comparisons, AND a `private static let priceFormatter: NumberFormatter` with Australian dollar currency formatting (`formatPrice`, `formatPriceRange`). This mixes domain pricing algorithms and UI string formatting directly inside the persistence model package.
- **Misplaced Pure Domain Validation in Data Layer**:
  - `Packages/Data/Sources/Data/Services/BulkClaimValidationService.swift:4-142`: Validates `BulkClaimLineSnapshot` instances using pure domain rules (registration number presence, NDIS numeric check, GST codes, HHH:MM hours formatting, provider ABN length). It imports no SwiftData types or DB context, but is located in `Packages/Data` instead of `Packages/Core`.
- **Redundant Re-export Files**:
  - `Packages/Data/Sources/Data/Models/CalendarPreferences.swift:3` (`public typealias CalendarPreferences = Core.CalendarPreferences`).
  - `Packages/Data/Sources/Data/Models/CalendarPreferencesStore.swift:3-5` (`public typealias CalendarPreferencesStore = Core.CalendarPreferencesStore`).
  - `Packages/Data/Sources/Data/Persistence/EntityPredicateBuilders.swift:4` (`public typealias EntityPredicateBuilders = PersistenceModels.EntityPredicateBuilders`).
- **Redundant Local Formatter Instantiations**:
  - Local `NumberFormatter` instances constructed across features instead of sharing locale-aware formatters:
    - `Packages/PersistenceModels/Sources/PersistenceModels/Utilities/NDISPriceUtilities.swift:74-81`
    - `Packages/Core/Sources/Core/Formatting/ExportMachineFormatting.swift:88-94`
    - `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceFormatting.swift:414-522`
    - `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceValidatedDecimalField.swift:49-213`
    - `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceFilterAmountField.swift:43-44`
    - `Packages/Feature.Settings/Sources/Feature_Settings/Views/NDIS/NDISBillingSettingsView.swift:10-11`

### File Organization & Service Bloat
- **Monolithic Service Bloat**:
  - `Packages/Data/Sources/Data/Services/NDISBillingIntegrationService.swift`: **1,028 lines** in a single file combining SwiftData fetching, ephemeral context management, invoice creation, input vector construction, travel charge calculation, entity resolution, and report generation.
  - `Packages/Data/Sources/Data/Services/EventKitSyncService.swift` and 11 extension files (19 total files under `Data/Services/` for EventKit sync).
  - `Packages/Core/Sources/Core/Models/CalendarPreferencesStore.swift`: **408 lines** class manually managing 25+ individual `UserDefaults` observation keys and properties.
- **Split Service Protocols Across Packages**:
  - `ComplianceValidating.swift` and `ServiceProtocols.swift` live in `Packages/Core/Sources/Core/Protocols/`, while all other data/persistence protocols live in `Packages/DataInterfaces/Sources/DataInterfaces/`.

---

## 2. Logic Chain

1. **Observation**: `Packages/Data/Sources/Data/Persistence/PersistenceSchema.swift` recreates the `appModels` array word-for-word from `Packages/PersistenceModels/Sources/PersistenceModels/PersistenceSchema.swift`.
   - **Reasoning**: `EntityPredicateBuilders.swift` in `Data` correctly uses a typealias `public typealias EntityPredicateBuilders = PersistenceModels.EntityPredicateBuilders`. `PersistenceSchema` was copied during a past refactor.
   - **Deduction**: `PersistenceSchema.swift` in `Data` can be simplified to a single-line typealias.

2. **Observation**: `NDISPriceUtilities.swift` lives inside `Packages/PersistenceModels`.
   - **Reasoning**: `PersistenceModels` should contain only SwiftData `@Model` class declarations and snapshot mappers. `NDISPriceUtilities` performs domain price validation, handles strategy-based price resolution (`PriceFallbackStrategy`), and formats currency strings using `NumberFormatter`.
   - **Deduction**: This violates clean architecture layer boundaries. Placing domain calculation and string formatting inside the persistence model package forces UI/domain callers to rely on persistence utilities.

3. **Observation**: `BulkClaimValidationService.swift` in `Packages/Data/Sources/Data/Services` takes `[BulkClaimLineSnapshot]` and returns `BulkClaimValidationResult`.
   - **Reasoning**: The inputs and outputs are pure Core snapshots, and the validation logic is 100% pure domain rule checking (ABN digits, NDIS number check, GST code validation, time format parsing). It makes zero SwiftData calls and accesses no database context.
   - **Deduction**: Moving `BulkClaimValidationService` to `Packages/Core/Sources/Core/Domain/` allows `Core` or offline feature validation to run without dragging in `Data` dependencies.

4. **Observation**: `NDISBillingIntegrationService.swift` spans 1,028 lines and handles DB context setup, invoice creation, vector mapping, session linking, and report generation.
   - **Reasoning**: Single responsibility principle is violated. Combining data persistence, domain vector transformation, and invoice construction in one class makes unit testing difficult and increases refactoring risk.
   - **Deduction**: Decomposing `NDISBillingIntegrationService` into sub-components (`NDISInvoiceBuilder`, `NDISSessionClaimProcessor`) will improve testability and maintainability.

---

## 3. Caveats

- **CloudKit Schema Stability**: `Invoice.swift` and `Client.swift` physical attribute names must remain stable due to CloudKit sync compatibility (documented in `DEVELOPER_NOTES.md`). Any refactoring of model properties must preserve existing `@Attribute(originalName:)` annotations.
- **`DataInterfaces` Payload Exceptions**: As documented in `Packages/DataInterfaces/Sources/DataInterfaces/InterfacePayloadExceptions.md`, a few specific protocols (`ClaimBatchPersisting`, `BusinessPersisting`, `TravelChargeReviewFetching`, `ClientRelationshipDeleting`) intentionally retain live `@Model` types or `PersistentIdentifier` for UI `@Query` binding.

---

## 4. Conclusion

The Domain, Core, and Data architecture is logically sound around snapshot isolation (`SnapshotMapping.swift`) and background actor boundaries (`ModelActor`). However, concrete technical debt exists in four areas:

1. **Direct Code Duplication**: `PersistenceSchema.swift` in `Data` duplicates `PersistenceSchema` in `PersistenceModels`.
2. **Layer Inversion / Misplaced Logic**:
   - `NDISPriceUtilities.swift` (domain pricing & formatting) is misplaced in `PersistenceModels`.
   - `BulkClaimValidationService.swift` (pure snapshot validation) is misplaced in `Data`.
3. **Service Monoliths**: `NDISBillingIntegrationService.swift` (1,028 lines) is overloaded with multi-domain responsibilities.
4. **Formatter Instantiation Overhead**: Scatter of local `NumberFormatter` instantiations across feature views and data services instead of centralizing locale-aware currency formatters.

---

## 5. Verification Method

To verify findings and validate future consolidation:

1. **Verify `PersistenceSchema` duplication**:
   - Inspect `Packages/PersistenceModels/Sources/PersistenceModels/PersistenceSchema.swift:5-30` and `Packages/Data/Sources/Data/Persistence/PersistenceSchema.swift:5-30`.
2. **Verify `BulkClaimValidationService` independence from Data**:
   - Inspect `Packages/Data/Sources/Data/Services/BulkClaimValidationService.swift`. Note lack of SwiftData/ModelContext imports.
3. **Verify build and test suite execution**:
   - Run swift test on target packages:
     ```bash
     swift test --package-path Packages/Core
     swift test --package-path Packages/PersistenceModels
     swift test --package-path Packages/DataInterfaces
     swift test --package-path Packages/Data
     ```
