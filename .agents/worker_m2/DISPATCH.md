# DISPATCH — Worker M2 (Code Deduplication & Shared Component Abstractions)

## Objective
Execute all Area 1, Area 2, and Area 3 tasks for Milestone 2:

### 1. Area 1: Validated Decimal Input Deduplication
- Create `Packages/SharedUI/Sources/SharedUI/Components/ValidatedDecimalField.swift` containing `ValidatedDecimalParseResult` and `ValidatedDecimalParser` (supporting strict locale parsing, keypad dot fallback, decimal/double/filter parsing).
- Refactor `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceFilterAmountField.swift` to delegate `InvoiceFilterAmountInput` to `ValidatedDecimalParser`.
- Refactor `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceValidatedDecimalField.swift` to delegate `InvoiceDecimalInput` and `InvoiceDoubleInput` to `ValidatedDecimalParser`.

### 2. Area 2: Address Form Standardization & Shadowing Elimination
- In `Packages/Feature.Calendar/Sources/Feature_Calendar/Views/SessionEditor/SessionAddressEditingSheet.swift`, rename `struct AddressEditingSheet` to `struct SessionAddressEditingSheet`.
- Refactor `SessionAddressEditingSheet` to consume `WorkspaceUI.AddressFormSheet` backed by `@State private var form = AddressFormState()`.
- Update line 45 in `Packages/Feature.Calendar/Sources/Feature_Calendar/Views/SessionEditor/NativeSessionFormLocationSection.swift` to instantiate `SessionAddressEditingSheet`.

### 3. Area 3: Date & Currency Formatter Centralization
- Extend `Packages/SharedUI/Sources/SharedUI/Helpers/CurrencyFormatting.swift` with `symbol(for:locale:)` and `display(_:code:omitFractionIfWhole:locale:)`.
- In `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceFormatting.swift`, delegate `currencySymbol` and `currencyString` to `SharedUI.CurrencyFormatting`, and update `InvoiceDateFormatter` to delegate to `SharedUI.DateFormatting`.
- In `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesContentToolbar.swift`, remove static `shortDateFormatter: DateFormatter` and delegate to `SharedUI.DateFormatting.shortDate`.
- In `Packages/PersistenceModels/Sources/PersistenceModels/Utilities/NDISPriceUtilities.swift`, remove static `priceFormatter: NumberFormatter` and use Foundation `price.formatted(.currency(code: "AUD"))`.

### 4. Verification
- Run `swift test --package-path Packages/SharedUI`
- Run `swift test --package-path Packages/Feature.Invoices`
- Run `swift test --package-path Packages/Feature.InvoiceTemplateEditor`
- Run `swift test --package-path Packages/Feature.Calendar`
- Run `./scripts/architecture-check.sh`
- Run `./scripts/refactor-verify.sh`

## Mandatory Integrity Warning
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_preview_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

## Reports to Reference
- `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_m2_1/handoff.md`
- `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_m2_2/handoff.md`
- `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_m2_3/handoff.md`
- `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/ORIGINAL_REQUEST.md`

## Required Output
Write report with build/test results to `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_m2/handoff.md`.
