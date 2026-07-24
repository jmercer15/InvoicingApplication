# Handoff Report: Feature.Invoices UI Refinement (Milestone 4)

## 1. Observation
We observed the following files and lines in `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/`:
- **Line Item actions (pencil & trash)**:
  `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceLineItemsSection.swift`, lines 178-203:
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
  Neither button has hover/active pointer modifiers or accessibility properties.

- **Add Line Item button**:
  `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceLineItemsSection.swift`, lines 106-127:
  ```swift
  private var addLineItemButton: some View {
      Button {
          ...
      } label: {
          HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
              Image(systemName: "plus.circle.fill")
              Text("Add Line Item")
          }
          ...
      }
      .buttonStyle(.borderless)
      .padding(.top, StyleGuide.Dimensions.paddingMedium)
  }
  ```
  No hover modifier (`.onHover`), custom pointer style (`.pointerStyle`), or accessibility labels/hints.

- **Text contrast in grid header**:
  `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceLineItemsSection.swift`, lines 64-65:
  ```swift
  .font(StyleGuide.Typography.caption)
  .foregroundStyle(ColorSystem.Neutral.gray500)
  ```
  The grid header uses `ColorSystem.Neutral.gray500` (backed by `NSColor.systemGray`).

- **Text contrast in form currency and percentage indicators**:
  `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceInspectorFormView.swift`, lines 300, 308:
  ```swift
  Text("%").foregroundStyle(ColorSystem.Neutral.gray500)
  ...
  Text("$").foregroundStyle(ColorSystem.Neutral.gray500)
  ```
  These indicators use `ColorSystem.Neutral.gray500`.

- **Done/Cancel affordances in Popover**:
  `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceLineItemsSection.swift`, lines 206-251:
  The `LineItemEditor` struct lacks explicit Done/Save or Cancel buttons. It has text fields and displays totals, relying on click-outside to commit edits.

---

## 2. Logic Chain
- **Point A**: The `pencil`, `trash`, and `addLineItemButton` buttons are critical interactive elements in the line items edit flow.
- **Point B**: Lack of hover indicators (color changes, opacity transitions) and custom pointer shapes (e.g. `pointerStyle(.link)`) means the cursor does not indicate clickability.
- **Point C**: The absence of `.accessibilityLabel` and `.accessibilityHint` on the pencil and trash buttons prevents screen readers from announcing their actions, causing accessibility issues.
- **Point D**: `ColorSystem.Neutral.gray500` is defined as `Color(NSColor.systemGray)`. On standard material/panel backgrounds, this gray has a contrast ratio below 4.5:1, failing WCAG AA guidelines for body/caption text.
- **Point E**: In the `LineItemEditor` popover, the absence of a "Done" or "Cancel" action creates friction for users (particularly keyboard-only users who must press Esc or know to click outside).

---

## 3. Caveats
- We did not audit the visual rendering inside Xcode previews or simulate VoiceOver directly.
- We assume standard system behaviors for macOS popovers.
- We did not modify the source code, as this is a read-only investigation.

---

## 4. Conclusion
We conclude that the Invoice views are elevated properly using the `EnhancedGroupBoxStyle` but have deficiencies in interactive feedback, contrast, and accessibility. Specifically, the line item grid actions lack hover/pointer affordances, the grid headers and symbols violate WCAG AA contrast standards, and popovers lack explicit closure actions.

---

## 5. Verification Method
- **Files to Inspect**:
  - `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceLineItemsSection.swift`
  - `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceInspectorFormView.swift`
- **Build / Test Verification**:
  - Verified compilation and unit tests pass locally:
    ```bash
    swift test --package-path Packages/Feature.Invoices
    ```
    Result: 19 tests executed, 0 failures.
- **Runtime Verification**:
  - Hover over the edit/delete and add buttons to see color changes and the cursor change to a pointer hand.
  - Inspect the buttons using the Accessibility Inspector to verify that labels and hints are read correctly.
  - Open the popover to edit a line item and verify that a "Done" button is visible and dismisses the popover correctly.

---

## 6. Remaining Work
- Implement the proposed refactorings specified in `analysis.md`.
- Run the build and test suite to verify no regressions occur in the unit tests.
