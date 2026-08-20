# DISPATCH — Explorer M2 Area 3 (Date & Currency Formatter Centralization)

## Objective
Investigate Area 3 formatter consolidation:
- Files:
  1. `Packages/SharedUI/Sources/SharedUI/Helpers/CurrencyFormatting.swift` (lines 5–79) & `DateFormatting.swift`
  2. `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceFormatting.swift` (lines 411–518, 1017–1048) (`InvoiceMoneyFormatter`, `InvoiceDateFormatter`)
  3. `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesContentToolbar.swift` (line 28) (`shortDateFormatter`)
  4. `Packages/PersistenceModels/Sources/PersistenceModels/Utilities/NDISPriceUtilities.swift` (lines 74–81)
- Inspect existing helpers in `SharedUI` and ad-hoc singletons / render-pass instantiations of `NumberFormatter` / `DateFormatter`.
- Design enhancements to `SharedUI.CurrencyFormatting` and `SharedUI.DateFormatting`.
- Map out replacements in `InvoiceFormatting.swift`, `InvoicesContentToolbar.swift`, and `NDISPriceUtilities.swift` to delegate to `SharedUI`.

## References
- `REFACTOR_PLAN.md` Section 4 Area 3
- Original Request: `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/ORIGINAL_REQUEST.md`

## Output
Write findings and recommended patch strategy to `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_m2_3/handoff.md`.
