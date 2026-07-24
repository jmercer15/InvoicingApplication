# Project: Table and Table-Cell Inspector UX Improvements

## Architecture
- Module: `Feature.InvoiceTemplateEditor`
- Core views to modify:
  - `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/ComponentPropertyEditor+Table.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/TableElementPropertyEditor.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/TableElementPropertyEditor+RowColumnSections.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/TableElementPropertyEditor+SectionTitleSection.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/TableElementPropertyEditor+SelectionSection.swift`
- The inspector UI is divided into:
  - Table-level properties (layout, grid/borders, typography, columns, headers/footers) in `ComponentPropertyEditor+Table.swift` or `TableElementPropertyEditor`.
  - Cell-level properties (row/column selection, width/height constraints, padding, alignment, styling) in `TableElementPropertyEditor` and its section extensions.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| 1 | Table & Cell Inspector UX | Analyze baseline, design clean layout, implement intuitive grouping, verify compile/tests, verify UX | None | IN_PROGRESS |

## Code Layout
- Inspect view source files under `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/`
- Existing tests in `Packages/Feature.InvoiceTemplateEditor/Tests/Feature_InvoiceTemplateEditorTests/`

## Interface Contracts
- No database model changes allowed.
- Must preserve SwiftUI bindings and state updates correctly.
- Layout must be responsive and follow macOS HIG.
