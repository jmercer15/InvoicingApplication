# Project: Architecture Refactoring (InvoicingApplication)

## Architecture
Multi-package Swift macOS workspace with strict package boundaries verified by `scripts/architecture-check.sh` and test verification via `scripts/refactor-verify.sh`.

## Feature Inventory
| # | Feature / Refactor Item | Description | Milestone | Source |
|---|-------------------------|-------------|-----------|--------|
| 1 | Delete DTOMacros | Remove empty directory `Packages/DTOMacros/` | M1 | REFACTOR_PLAN §2.3.1 |
| 2 | Centralize TestTags | Move `@Tag static var unit/integration` to `Core/Testing/TestTags.swift` and remove 13 duplicate files | M1 | REFACTOR_PLAN §4 Area 4 |
| 3 | Root & Repo Cleanup | Delete `default.profraw`, add `*.profraw` to `.gitignore`, delete scratch logs, remove `Agents/` folder | M1 | REFACTOR_PLAN §3.2.3 |
| 4 | Clean Legacy Scripts | Delete 13 single-use legacy python scripts in `scripts/` | M1 | REFACTOR_PLAN §3.2.4 |
| 5 | Update refactor-verify.sh | Update `scripts/refactor-verify.sh` to run tests across all 14 active packages | M1 | REFACTOR_PLAN §1.1.D |
| 6 | Validated Decimal Field Deduplication | Extract `ValidatedDecimalField` & `Parser` to `SharedUI` and replace in `Feature.Invoices` and `Feature.InvoiceTemplateEditor` | M2 | REFACTOR_PLAN §4 Area 1 |
| 7 | Address Form Standardization | Standardize `SessionAddressEditingSheet` in `Feature.Calendar` to consume `WorkspaceUI.AddressFormSheet` | M2 | REFACTOR_PLAN §4 Area 2 |
| 8 | Centralize Date & Currency Formatters | Consolidate date/currency formatting across `InvoiceFormatting.swift`, `InvoicesContentToolbar.swift`, `NDISPriceUtilities.swift` into `SharedUI` helpers | M2 | REFACTOR_PLAN §4 Area 3 |
| 9 | BulkClaimValidationService Relocation | Move `BulkClaimValidationService.swift` from `Data` to `Core/Domain/Validation/` | M3 | REFACTOR_PLAN §2.2.1 |
| 10| NDIS Pricing Extraction | Move `NDISPriceUtilities.swift` calculations to `Core/Domain/Pricing/` and delegate string formatting to `SharedUI.CurrencyFormatting` | M3 | REFACTOR_PLAN §2.2.2 |
| 11| PersistenceSchema Typealias & Model Cleanup | Replace duplicate array in `Data/Persistence/PersistenceSchema.swift` with typealias, remove redundant re-export files in `Data/Models/` | M3 | REFACTOR_PLAN §2.3.2-3 |
| 12| Decompose NDISBillingIntegrationService | Split `NDISBillingIntegrationService.swift` (1,028 lines) into `NDISInvoiceBuilder.swift`, `NDISSessionClaimProcessor.swift`, and facade | M3 | REFACTOR_PLAN §2.4 |
| 13| Fix @State Initialization Anti-pattern | Fix `@State` view model init hazard in `InvoiceRootView.swift` | M4 | REFACTOR_PLAN §2.1 |
| 14| Split InvoiceDocumentSections.swift | Split `InvoiceDocumentSections.swift` (1,845 lines) into 4 sub-files | M4 | REFACTOR_PLAN §3.1.A |
| 15| Split InvoiceFormatting.swift | Split `InvoiceFormatting.swift` (1,078 lines) into 3 sub-files | M4 | REFACTOR_PLAN §3.1.B |
| 16| Split InvoiceDocumentPreview.swift | Split `InvoiceDocumentPreview.swift` (939 lines) into 3 sub-files | M4 | REFACTOR_PLAN §3.1.C |
| 17| Split InvoiceRootView.swift | Split `InvoiceRootView.swift` (810 lines) into 2 sub-files | M4 | REFACTOR_PLAN §3.1.D |
| 18| Consolidate Invoices Toolbar | Combine `InvoicesViewToolbar.swift` and `InvoicesContentToolbar.swift` into `InvoicesToolbarComponents.swift` & fix line 2 comment in `InvoicesViewList.swift` | M4 | REFACTOR_PLAN §3.2.1-2 |
| 19| Architecture & Verification Certification | Verify `./scripts/architecture-check.sh`, `./scripts/refactor-verify.sh`, and `xcodebuild test` pass with 0 errors | M5 | REFACTOR_PLAN §6 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Package Cleanup & Tooling Modernization | Features 1-5 | None | IN_PROGRESS |
| M2 | Code Deduplication & Shared UI | Features 6-8 | M1 | PLANNED |
| M3 | Domain & Data Layer Realignment | Features 9-12 | M1 | PLANNED |
| M4 | UI File Decomposition & State Refactoring | Features 13-18 | M2 | PLANNED |
| M5 | Verification & Gate Certification | Feature 19 | M1, M2, M3, M4 | PLANNED |

## Interface Contracts
### SharedUI ↔ Feature Packages
- `ValidatedDecimalField` & `ValidatedDecimalParser` in `SharedUI` consumed by `Feature.Invoices` and `InvoiceTableLayoutEditor`.
- `CurrencyFormatting` & `DateFormatting` in `SharedUI` consumed by `Core`, `PersistenceModels`, `Feature.Invoices`, `InvoiceTableLayoutEditor`.

### WorkspaceUI ↔ Feature.Calendar
- `AddressFormSheet` and `AddressFormState` in `WorkspaceUI` consumed by `Feature.Calendar`.

### Core ↔ Data / Feature Packages
- `BulkClaimValidationService` in `Core.Domain.Validation` consumed by `Data` / features.
- `NDISPriceUtilities` / pricing logic in `Core.Domain.Pricing` consumed by `PersistenceModels` / features.
