# Design Token Compliance Analysis — Feature.Invoices

This report details the design token compliance gaps identified in the views within `Feature.Invoices` at `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/`. It includes specific findings for the five requested views, as well as an audit of the other views in the module, and proposes a remediation mapping strategy to resolve them.

---

## Part 1: Analysis of the 5 Focused Views

### 1. `InvoiceTemplateRendererView.swift`
- **Location**: `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceTemplateRendererView.swift`
- **Findings**: **Fully Compliant**.
  - This view serves purely as a data-binding container that resolves the effective template ID and delegates layout and drawing to `InvoiceCanvasView` (from `Feature_InvoiceTemplateEditor`).
  - No raw layout margins, paddings, corner-radii, spacing, or hardcoded color structures are declared.

### 2. `InvoicesColumns.swift`
- **Location**: `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesColumns.swift`
- **Findings**: **Fully Compliant**.
  - Serves as the navigation split layout container (`InvoicesContentColumn`) and binds lists to `InvoicesView`.
  - The only numeric literal is a `Task.sleep` duration (`.milliseconds(150)`), which is standard thread execution logic, not a style or spacing declaration. No custom styling or color declarations are present.

### 3. `InvoicesContentToolbar.swift`
- **Location**: `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesContentToolbar.swift`
- **Findings**: **1 Token Compliance Gap**.
  - **Line 72**: Uses a hardcoded string asset lookup for the primary theme color:
    ```swift
    .foregroundStyle(Color("Primary", bundle: .sharedUI))
    ```
    *Gap*: This bypasses the centralized design token system. It should use `StyleGuide.Colors.primary` instead, which is defined as `Color("Primary", bundle: .sharedUI)` inside `SharedUI/StyleGuide.swift`.

### 4. `InvoicesDetailColumn.swift`
- **Location**: `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesDetailColumn.swift`
- **Findings**: **Fully Compliant**.
  - Binds toolbar configurations and selects presentation layout structures (either `InvoiceEditor` or `InvoiceEditorFormContent`).
  - Contains no hardcoded paddings, spacers, corner-radii, or color declarations.

### 5. `InvoicesView.swift`
- **Location**: `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesView.swift`
- **Findings**: **3 Design Token / Color Compliance Gaps**.
  - **Line 171**: Uses a raw numeric literal for animation duration:
    ```swift
    withAnimation(.easeOut(duration: 0.2)) {
    ```
    *Gap*: Animation durations should be centralized. This should map to `StyleGuide.Animations.durationShort` (0.1) or `StyleGuide.Animations.durationMedium` (0.3). Given it's a quick list selection, `StyleGuide.Animations.durationMedium` is recommended (consistent with other animated toolbar actions on line 165 and line 223 which use `StyleGuide.Animations.durationMedium`).
  - **Lines 212, 215, 229, 245, 262, 279**: Hardcoded `Color.white` and `Color.white.opacity(0.8)`:
    ```swift
    .foregroundColor(Color.white)
    .foregroundColor(Color.white.opacity(0.8))
    ```
    *Gap*: Pure hardcoded colors are present. Since these text labels reside on dark background shapes inside a glass container, pure white is visually required. However, utilizing `ColorSystem` is best practice. Under `ColorSystem.Neutral`, `white` maps to `windowBackgroundColor`. For high-contrast white text, the system currently lacks a dedicated high-contrast light text token. We recommend either introducing a dedicated high-contrast text color token or keeping it mapped under a semantic name.
  - **Lines 256, 306 (InvoiceFilterPopoverContent)**: Uses `lineWidth: 1` as a raw numeric border weight. This is acceptable for simple thin borders, but can be aligned to `StyleGuide` if a general borders/separators width standard becomes available (or mapped to a local token if required).

---

## Part 2: Analysis of Additional Views in the Package

For completeness, the remaining views in `Sources/Feature_Invoices/Views/` were audited:

### 6. `InvoiceEditor.swift`
- **Location**: `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceEditor.swift`
- **Findings**: **1 Gap**.
  - **Line 87**: Uses a raw AppKit system color representation for the header bar in edit mode:
    ```swift
    .background(Color(NSColor.controlBackgroundColor))
    ```
    *Gap*: This bypasses design token wrappers. It should be replaced with `PanelShellTokens.panelSecondaryBackground` or another design token matching secondary background colors.

### 7. `InvoiceFilterPopoverContent.swift`
- **Location**: `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceFilterPopoverContent.swift`
- **Findings**: **Compliant**.
  - Fully uses `StyleGuide.Dimensions` for all paddings, popover widths, and field sizes.
  - Fully uses `ColorSystem.Status` and `ColorSystem.Primary` for states.

### 8. `InvoiceInspectorFormView.swift`
- **Location**: `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceInspectorFormView.swift`
- **Findings**: **Compliant**.
  - Uses `StyleGuide.Dimensions.paddingXSmall` and `StyleGuide.Dimensions.paddingXXSmall` for internal layout spacing.

### 9. `InvoiceLineItemsSection.swift`
- **Location**: `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceLineItemsSection.swift`
- **Findings**: **Compliant**.
  - Layout is built using `StyleGuide.Dimensions.paddingLarge`, `StyleGuide.Dimensions.paddingMedium`, and `StyleGuide.Dimensions.paddingXSmall`.
  - Colors are mapped to `ColorSystem.Primary.blue` and `StyleGuide.Opacity`.

---

## Part 3: Recommended Fix & Remediation Strategy

The proposed fixes map raw literals to existing tokens in `StyleGuide` and `ColorSystem`.

### 1. InvoicesContentToolbar.swift (Line 72)
- **Problem**: Raw asset color `Color("Primary", bundle: .sharedUI)`
- **Solution**: Replace with centralized token `StyleGuide.Colors.primary`.
```swift
// BEFORE
.foregroundStyle(Color("Primary", bundle: .sharedUI))

// AFTER
.foregroundStyle(StyleGuide.Colors.primary)
```

### 2. InvoicesView.swift (Line 171)
- **Problem**: Raw duration `0.2` in `withAnimation`.
- **Solution**: Replace with `StyleGuide.Animations.durationMedium`.
```swift
// BEFORE
withAnimation(.easeOut(duration: 0.2)) {
    containerViewModel.requestSelectInvoice(invoice)
}

// AFTER
withAnimation(.easeOut(duration: StyleGuide.Animations.durationMedium)) {
    containerViewModel.requestSelectInvoice(invoice)
}
```

### 3. InvoiceEditor.swift (Line 87)
- **Problem**: Raw AppKit color `Color(NSColor.controlBackgroundColor)`
- **Solution**: Map to `PanelShellTokens.panelSecondaryBackground` (which standardizes secondary control elements).
```swift
// BEFORE
.background(Color(NSColor.controlBackgroundColor))

// AFTER
.background(PanelShellTokens.panelSecondaryBackground)
```

### 4. Hardcoded Color.white in Glass Cards (InvoicesView.swift)
- **Problem**: Raw `Color.white` and `Color.white.opacity(0.8)` for labels.
- **Solution**: For true white labels over dark/colored glass components, we recommend introducing a semantic layout token for high-contrast labels on colored shapes, or mapping to a semantic color wrapper.
