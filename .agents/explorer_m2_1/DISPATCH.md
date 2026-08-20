# DISPATCH — Explorer M2 Area 1 (Validated Decimal Input Deduplication)

## Objective
Investigate Area 1 deduplication:
- Files:
  1. `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceFilterAmountField.swift` (lines 10–53)
  2. `Packages/Feature.InvoiceTemplateEditor/Sources/InvoiceTableLayoutEditor/Views/InvoiceValidatedDecimalField.swift` (lines 5–58 & 179–220)
  3. `Packages/SharedUI/Sources/SharedUI/Components/` (or `SharedUI`)
- Inspect both input field implementations (`InvoiceFilterAmountInput`, `InvoiceDecimalInput`, `InvoiceDoubleInput`).
- Design `ValidatedDecimalParser` and `ValidatedDecimalField` in `SharedUI` to consolidate strict locale parsing (`NumberFormatter` .decimal, `getObjectValue`), dot/comma keypad fallback, and fraction formatting.
- Map out exact changes needed to replace the duplicate parsers in `Feature.Invoices` and `Feature.InvoiceTemplateEditor` with `SharedUI` component.

## References
- `REFACTOR_PLAN.md` Section 4 Area 1
- Original Request: `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/ORIGINAL_REQUEST.md`

## Output
Write findings and recommended patch strategy to `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/explorer_m2_1/handoff.md`.
