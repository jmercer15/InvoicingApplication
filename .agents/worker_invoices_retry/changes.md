# Changes

## Modified Files

### `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceLineItemsSection.swift`
- Refactored the `LineItemEditor` custom form label/input blocks (Description, Quantity, and Rate) to adopt the `FormField` component from `SharedUI`.
- Kept all original bindings, formatters, and text field styles.

### `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceEditor.swift`
- Verified `.background(Color(NSColor.controlBackgroundColor))` on line 87 is replaced with `.background(StyleGuide.Colors.background)`. (Already completed in a previous attempt).

### `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/Components/InvoicesDetailToolbar.swift`
- Verified `.font(.caption)` on line 198 is replaced with `.font(StyleGuide.Typography.caption)`. (Already completed in a previous attempt).
