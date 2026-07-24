# Project: Default Invoice Template Implementation

## Architecture
The Invoice Template Editor uses a custom layout system composed of `InvoiceDocument`, `InvoiceComponent`, and `SectionSplit`.
- `InvoiceDocument` represents a print-optimized document (default A4 dimensions: 595.2 x 841.8 points).
- `SectionSplit` represents a tree structure partitioning the page space into linear horizontal/vertical splits or grid areas.
- `InvoiceComponent` represents individual content components (`companyName`, `companyLogo`, `billTo`, `servicesTable`, `totals`, etc.) which reside inside the leaf splits.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Explore | Analyze codebase, existing components, layout APIs, and test infrastructure | None | DONE |
| 2 | Model | Create `DefaultInvoiceTemplate.swift` with print-optimized `SectionSplit` layout and comprehensive invoice components | M1 | DONE |
| 3 | Integrate | Hook the default template into `InvoiceTemplateEditorViewModel` and verify compiling | M2 | DONE |
| 4 | Verify | Create test suite/automated test cases in `DefaultInvoiceTemplateTests.swift` to verify presence of elements and successful rendering | M3 | DONE |
| 5 | Audit | Audit the layout, styling, and integrity of the template | M4 | DONE |

## Code Layout
- Model: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Models/Domain/DefaultInvoiceTemplate.swift`
- ViewModel: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/ViewModels/InvoiceTemplateEditorViewModel.swift`
- Tests: `Packages/Feature.InvoiceTemplateEditor/Tests/Feature_InvoiceTemplateEditorTests/DefaultInvoiceTemplateTests.swift`

## Interface Contracts
### `DefaultInvoiceTemplate`
- Static builder or getter: `public static func createDefaultDocument() -> InvoiceDocument`
- Must produce an `InvoiceDocument` configured with:
  - Page size A4 (595.2 x 841.8) or US Letter.
  - Page margins (e.g. 36 points).
  - A comprehensive tree of `SectionSplit` (horizontal, vertical splits, or grids) partitioning the page.
  - Leaves populated with default configured `InvoiceComponent` instances of types:
    - `.companyName`, `.companyABN`, `.companyEmail`, `.companyLogo`, `.invoiceTitle` (Sender information)
    - `.billTo`, `.participant` (Recipient information)
    - `.invoiceNumberAndDates` (Invoice metadata)
    - `.servicesTable` (Itemized line items)
    - `.totals` (Subtotal, taxes, grand total)
    - `.paymentDetails`, `.paymentTerms`, `.notes` (Payment details/terms/notes)
