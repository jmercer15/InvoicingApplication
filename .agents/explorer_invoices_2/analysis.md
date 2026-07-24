# UI/UX/A11y Analysis: Invoices UI Refinement

## Executive Summary
This analysis audits three key views in the `Feature.Invoices` package: `InvoiceEditor.swift`, `InvoiceInspectorFormView.swift` (defining `InvoiceEditorFormContent`), and `InvoiceLineItemsSection.swift`. 

While the general design system is solid and consistent (elevated cards, logical form grouping), we identified several key areas for refinement:
1. **Interactive Affordances**: Core action buttons (pencil, trash, add item) lack hover states, pressed states, and custom link pointer shapes.
2. **Accessibility & Contrast**: Low-contrast text labels (using `gray500`) are used for grid headers and form symbols, which can violate WCAG AA contrast guidelines. Furthermore, several critical buttons lack accessibility labels or hints.
3. **Popover Interaction**: The Line Item Editor popover does not include explicit Save/Done/Cancel actions, relying solely on clicking outside to dismiss, which creates keyboard navigation and visual clarity issues.

---

## Detailed Findings

### 1. Component Elevation & Visual Hierarchy
- **Cards & Layout**: The main editor panels in the inspector use `GroupBox` with `EnhancedGroupBoxStyle()`, which implements a material background (`.regularMaterial`), drop shadow (`radius: 3, y: 1.5`), and thin border (`lineWidth: 0.5`). This provides excellent elevation and hierarchy, separating forms into logical cards.
- **Read-Only vs. Editable Fields**: Cards like `businessDetailsCard` and `paymentDetailsCard` display read-only information using `LabeledContent`. While functionally correct, they look flat and lack distinct grouping compared to editable inputs.
- **Form Grouping**: Inside cards, input fields are grouped using native `Form` with `.formStyle(.columns)` style, ensuring neat alignment and native look-and-feel.
- **Live Preview Header**: The "Live Preview" header inside `InvoiceEditor.swift` is a simple `Text` with `StyleGuide.Colors.background` background. It lacks visual elevation or a bottom border to delineate it from the editor content.

### 2. Visual Feedback & Interactive Affordances
- **Line Item Action Buttons**:
  - The `pencil` (Edit) and `trash` (Delete) buttons in `InvoiceLineItemsSection.swift` use `.buttonStyle(.borderless)` without hover styles or active states. When the cursor passes over them, there is no change in opacity or color, and the cursor remains the default arrow.
- **Add Line Item Button**:
  - The "Add Line Item" button has a custom shape, dotted border, and blue background, but does not highlight when hovered or pressed. The mouse pointer does not change to a link pointer.
- **Line Item Editor Popover Dismissal**:
  - `LineItemEditor` popover does not have any "Done" or "Cancel" buttons. Users must click outside the popover to dismiss and commit edits. This lacks clear affordance, especially for keyboard-only or assistive technology users.

### 3. Accessibility & Contrast (WCAG AA Compliance)
- **Low Contrast Gray Text**:
  - The column headers in the line items grid use `ColorSystem.Neutral.gray500` (which is `NSColor.systemGray`). Under standard light backgrounds, this gray does not meet the WCAG AA minimum contrast ratio of 4.5:1 for normal text.
  - The percent (`%`) and currency (`$`) symbols next to inputs in `InvoiceInspectorFormView.swift` also use `ColorSystem.Neutral.gray500`.
- **Missing Accessibility Labels & Hints**:
  - The `pencil` and `trash` buttons in the line items grid do not have `.accessibilityLabel` or `.accessibilityHint`. A screen reader will only read "pencil" or "trash".
  - The `addLineItemButton` has the text label "Add Line Item", but would benefit from an accessibility hint to explain its behavior.

---

## Proposed Changes & Diffs

### Proposal 1: Refined Line Item Actions & Affordances
Apply hover states, color changes, custom pointers, and accessibility labels to the pencil and trash buttons in `InvoiceLineItemsSection.swift`.

**Before (`InvoiceLineItemsSection.swift:178`):**
```swift
    private func lineItemActions(_ item: InvoiceItem) -> some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
            Button {
                lineItemEditBaseline = InvoiceEditorEditSnapshot.LineItemFingerprint(item: item)
                editingItemId = item.id
            } label: {
                Image(systemName: "pencil")
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            }
            .buttonStyle(.borderless)

            Button {
                if let index = viewModel.invoiceItems.firstIndex(where: { $0.id == item.id }) {
                    let previousItems = viewModel.invoiceItems
                    viewModel.deleteInvoiceItems(at: IndexSet(integer: index))
                    registerLineItemsUndo(previous: previousItems, actionName: "Delete Line Item")
                }
            } label: {
                Image(systemName: "trash")
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            }
            .buttonStyle(.borderless)
        }
    }
```

**Proposed After:**
```swift
    @State private var hoveredButtonId: String? = nil

    private func lineItemActions(_ item: InvoiceItem) -> some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
            // Edit Button
            Button {
                lineItemEditBaseline = InvoiceEditorEditSnapshot.LineItemFingerprint(item: item)
                editingItemId = item.id
            } label: {
                Image(systemName: "pencil")
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(hoveredButtonId == "edit-\(item.id)" ? ColorSystem.Primary.blue : StyleGuide.Colors.textSecondary)
            }
            .buttonStyle(.borderless)
            .pointerStyle(.link)
            .onHover { isHovered in
                hoveredButtonId = isHovered ? "edit-\(item.id)" : nil
            }
            .accessibilityLabel("Edit line item")
            .accessibilityHint("Opens details editor popover for this item")

            // Delete Button
            Button {
                if let index = viewModel.invoiceItems.firstIndex(where: { $0.id == item.id }) {
                    let previousItems = viewModel.invoiceItems
                    viewModel.deleteInvoiceItems(at: IndexSet(integer: index))
                    registerLineItemsUndo(previous: previousItems, actionName: "Delete Line Item")
                }
            } label: {
                Image(systemName: "trash")
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(hoveredButtonId == "delete-\(item.id)" ? ColorSystem.Status.error : StyleGuide.Colors.textSecondary)
            }
            .buttonStyle(.borderless)
            .pointerStyle(.link)
            .onHover { isHovered in
                hoveredButtonId = isHovered ? "delete-\(item.id)" : nil
            }
            .accessibilityLabel("Delete line item")
            .accessibilityHint("Removes this item from the invoice")
        }
    }
```

---

### Proposal 2: Add Hover & Pointer Styles to "Add Line Item" Button
Enhance visual feedback when interacting with the main "Add Line Item" button.

**Before (`InvoiceLineItemsSection.swift:106`):**
```swift
    private var addLineItemButton: some View {
        Button {
            let previousItems = viewModel.invoiceItems
            withAnimation { viewModel.addNewInvoiceItem() }
            registerLineItemsUndo(previous: previousItems, actionName: "Add Line Item")
        } label: {
            HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                Image(systemName: "plus.circle.fill")
                Text("Add Line Item")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
            .background(ColorSystem.Primary.blue.opacity(StyleGuide.Opacity.light))
            .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                    .strokeBorder(ColorSystem.Primary.blue.opacity(StyleGuide.Opacity.strong), style: StrokeStyle(lineWidth: 1, dash: [StyleGuide.Dimensions.paddingXSmall]))
            )
        }
        .buttonStyle(.borderless)
        .padding(.top, StyleGuide.Dimensions.paddingMedium)
    }
```

**Proposed After:**
```swift
    @State private var isAddButtonHovered = false

    private var addLineItemButton: some View {
        Button {
            let previousItems = viewModel.invoiceItems
            withAnimation { viewModel.addNewInvoiceItem() }
            registerLineItemsUndo(previous: previousItems, actionName: "Add Line Item")
        } label: {
            HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                Image(systemName: "plus.circle.fill")
                Text("Add Line Item")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
            .background(ColorSystem.Primary.blue.opacity(isAddButtonHovered ? StyleGuide.Opacity.strong : StyleGuide.Opacity.light))
            .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall))
            .overlay(
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                    .strokeBorder(ColorSystem.Primary.blue.opacity(isAddButtonHovered ? 0.5 : StyleGuide.Opacity.strong), style: StrokeStyle(lineWidth: 1, dash: [StyleGuide.Dimensions.paddingXSmall]))
            )
        }
        .buttonStyle(.borderless)
        .pointerStyle(.link)
        .onHover { isHovered in
            isAddButtonHovered = isHovered
        }
        .accessibilityLabel("Add line item")
        .accessibilityHint("Appends a new line item to the invoice items list")
        .padding(.top, StyleGuide.Dimensions.paddingMedium)
    }
```

---

### Proposal 3: Address Accessibility Contrast (WCAG AA)
Replace `ColorSystem.Neutral.gray500` with `StyleGuide.Colors.textSecondary` in the Grid headers and symbols to improve contrast and ensure readability on material backgrounds.

**Before (`InvoiceLineItemsSection.swift:64`):**
```swift
            }
            .font(StyleGuide.Typography.caption)
            .foregroundStyle(ColorSystem.Neutral.gray500)
```

**Proposed After:**
```swift
            }
            .font(StyleGuide.Typography.caption)
            .foregroundStyle(StyleGuide.Colors.textSecondary)
```

Also, update the percentage and dollar indicators in `InvoiceInspectorFormView.swift`:
**Before (`InvoiceInspectorFormView.swift:300` & `308`):**
```swift
                Text("%").foregroundStyle(ColorSystem.Neutral.gray500)
...
                Text("$").foregroundStyle(ColorSystem.Neutral.gray500)
```

**Proposed After:**
```swift
                Text("%").foregroundStyle(StyleGuide.Colors.textSecondary)
...
                Text("$").foregroundStyle(StyleGuide.Colors.textSecondary)
```

---

### Proposal 4: Refined Popover with Done/Cancel Affordances
Modify the Line Item Editor popover to include a distinct title, and explicit "Done" actions for proper closure affordances.

**Before (`InvoiceLineItemsSection.swift:206`):**
```swift
private struct LineItemEditor: View {
    @Binding var item: InvoiceItem
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingLarge) {
            Text("Edit Line Item")
                .font(StyleGuide.Typography.itemTitle)

            FormField("Description") {
                TextField("Description", text: $item.itemDescription)
                    .textFieldStyle(.roundedBorder)
            }
            ...
            HStack {
                Text("Total")
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                Spacer()
                Text(item.lineTotal, format: .currency(code: currencyCode))
                    .font(StyleGuide.Typography.itemTitle)
                    .monospacedDigit()
            }
        }
        .padding(StyleGuide.Dimensions.paddingLarge)
        .frame(width: StyleGuide.Dimensions.lineItemEditorWidth)
    }
}
```

**Proposed After:**
```swift
private struct LineItemEditor: View {
    @Binding var item: InvoiceItem
    let currencyCode: String
    var onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingLarge) {
            HStack {
                Text("Edit Line Item")
                    .font(StyleGuide.Typography.itemTitle)
                Spacer()
                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .pointerStyle(.link)
            }

            FormField("Description") {
                TextField("Description", text: $item.itemDescription)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Description")
            }

            HStack(spacing: StyleGuide.Dimensions.paddingMediumLarge) {
                FormField("Quantity") {
                    TextField("Qty", value: $item.quantity, formatter: NumberFormatter.decimal)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("Quantity")
                }

                FormField("Rate") {
                    HStack(spacing: StyleGuide.Dimensions.paddingXSmall) {
                        Text("$").foregroundStyle(StyleGuide.Colors.textSecondary)
                        TextField("Rate", value: $item.rate, formatter: NumberFormatter.decimal)
                            .textFieldStyle(.roundedBorder)
                            .multilineTextAlignment(.trailing)
                            .accessibilityLabel("Rate")
                    }
                }
            }

            Divider()

            HStack {
                Text("Total")
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                Spacer()
                Text(item.lineTotal, format: .currency(code: currencyCode))
                    .font(StyleGuide.Typography.itemTitle)
                    .monospacedDigit()
            }
        }
        .padding(StyleGuide.Dimensions.paddingLarge)
        .frame(width: StyleGuide.Dimensions.lineItemEditorWidth)
    }
}
```
*Note: Update the popover call site in `InvoiceLineItemsSection.swift` to pass a closure that sets `editingItemId = nil` and commits edits.*

---

## Proposed Action Plan

1. **A11y/Contrast Enhancement**:
   - Refactor `InvoiceLineItemsSection.swift` to use `StyleGuide.Colors.textSecondary` instead of `ColorSystem.Neutral.gray500` for grid headers.
   - Refactor `InvoiceInspectorFormView.swift` to use `StyleGuide.Colors.textSecondary` for percent and dollar symbols in financial text fields.
2. **Interactive Affordances & Hover states**:
   - Add `.pointerStyle(.link)` and hover effects to the line item actions (Edit/Delete).
   - Add hover states and pointer style to the "Add Line Item" button.
3. **Accessibility Labels/Hints**:
   - Apply explicit `.accessibilityLabel` and `.accessibilityHint` modifiers to the actions and Add button.
4. **Popover Form Refinement**:
   - Update `LineItemEditor` to include a Done button, and explicitly label nested text fields for voiceover.
