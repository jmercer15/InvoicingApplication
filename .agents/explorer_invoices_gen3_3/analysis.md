# Design Token Compliance Analysis: Feature.Invoices Component Views

## Summary
A comprehensive audit of the five target views in `Sources/Feature_Invoices/Views/Components/` reveals **100% compliance** with the application's design systems (`StyleGuide`, `ColorSystem`, `PanelShellTokens`). No raw numeric literals for padding, corner-radius, spacing, or local custom/hardcoded colors were found in these files.

---

## 1. Compliance Audit of Components Directory
Every file in `Sources/Feature_Invoices/Views/Components/` was inspected. The results are summarized below:

| Component File | Status | Found Literals | Current Token Usage |
| :--- | :---: | :---: | :--- |
| `InvoiceEditUndoWindowInstaller.swift` | **Compliant** | None | Uses `StyleGuide.Dimensions.hiddenFrameWidth` and `StyleGuide.Dimensions.hiddenFrameHeight` for frame dimensioning. |
| `InvoiceEditorUndoComponents.swift` | **Compliant** | None | No layout, padding, spacing, or custom colors. The state initializer `valueAtFocusStart = 0.0` is logical, not styling/layout. |
| `InvoiceShareToolbarItem.swift` | **Compliant** | None | Inherits toolbar link styling from `SharedUI` (`.appToolbarLinkStyle`). The logic value `0` is used in a `.reduce()` hash, not for layout. |
| `InvoicesDetailToolbar.swift` | **Compliant** | None | Utilizes token values throughout: `StyleGuide.Animations.durationMedium`, `StyleGuide.Dimensions.paddingSmall`, `ColorSystem.Status.warning`, `StyleGuide.Dimensions.unsavedIndicatorSize`, and `ColorSystem.Invoice.statusColor(for:)`. |
| `WritingToolsTextEditor.swift` | **Compliant** | None | Uses standard AppKit font sizes via `NSFont.systemFontSize` and delegates container sizing to the parent container layout. |

---

## 2. Gaps Found Outside Components (Package Scope)
While the `Components/` folder is fully compliant, a wider scan of the `Feature.Invoices` views module (parent directory `Sources/Feature_Invoices/Views/`) identified several token compliance gaps where hardcoded values, legacy asset colors, or direct `NSColor` references are used:

### A. Layout / Spacing / Padding Gaps
1. **`InvoiceInspectorFormView.swift`**
   - **Line 199**: `.padding(.top, StyleGuide.Dimensions.paddingXSmall)` (Note: Previously utilized raw value `4`, which has been updated to the token `paddingXSmall`).
2. **`InvoicesView.swift`**
   - **Line 239**: `.padding(.trailing, 8)`
     - *Code*: `.padding(.trailing, 8)`
     - *Issue*: Raw literal `8` used for trailing padding.
   - **Line 247**: `.padding(.horizontal, 12)`
     - *Code*: `.padding(.horizontal, 12)`
     - *Issue*: Raw literal `12` used for horizontal padding.
   - **Line 248**: `.padding(.vertical, 6)`
     - *Code*: `.padding(.vertical, 6)`
     - *Issue*: Raw literal `6` used for vertical padding.
   - **Line 264**: `.padding(.horizontal, 12)`
     - *Code*: `.padding(.horizontal, 12)`
     - *Issue*: Raw literal `12` used for horizontal padding.

### B. Color Gaps
1. **`InvoiceEditor.swift`**
   - **Line 87**: `.background(Color(NSColor.controlBackgroundColor))`
     - *Code*: `.background(Color(NSColor.controlBackgroundColor))`
     - *Issue*: Direct dependency on AppKit/NSColor system background instead of dynamic package tokens.
2. **`InvoicesContentToolbar.swift`**
   - **Line 72**: `.foregroundStyle(Color("Primary", bundle: .sharedUI))`
     - *Code*: `.foregroundStyle(Color("Primary", bundle: .sharedUI))`
     - *Issue*: Direct invocation of named asset `"Primary"` instead of using the unified semantic `ColorSystem`.
3. **`InvoicesView.swift`**
   - **Line 212, 215, 229, 245, 262, 279**: `Color.white` and `Color("White", bundle: .sharedUI)`
     - *Issue*: References to generic/hardcoded white assets rather than unified tokens.
   - **Line 232**: `.background(Color("Gray20", bundle: .sharedUI))` (Note: Refactored in some views to `StyleGuide.Colors.secondary`, but check consistency).
   - **Line 248**: `.background(Color("Red70", bundle: .sharedUI))`
     - *Code*: `.background(Color("Red70", bundle: .sharedUI))`
     - *Issue*: Named legacy hex/red color catalog item used directly in UI rendering.
   - **Line 265, 282**: `.background(Color("Blue70", bundle: .sharedUI))`
     - *Code*: `.background(Color("Blue70", bundle: .sharedUI))`
     - *Issue*: Named legacy hex/blue color catalog item used directly in UI rendering.

---

## 3. Recommended Fix Strategy
For all views in the package to align with the unified styling architecture, the following migration mappings are recommended:

### Layout Mappings
- **Raw Literal `12`** &rarr; `StyleGuide.Dimensions.paddingMediumLarge`
- **Raw Literal `8`** &rarr; `StyleGuide.Dimensions.paddingMedium`
- **Raw Literal `6`** &rarr; `StyleGuide.Dimensions.paddingSmall`
- **Raw Literal `4`** &rarr; `StyleGuide.Dimensions.paddingXSmall`

### Color Mappings
- **`Color("White", bundle: .sharedUI)`** &rarr; `ColorSystem.Neutral.white`
- **`Color("Gray20", bundle: .sharedUI)`** &rarr; `ColorSystem.Neutral.gray300` (or `StyleGuide.Colors.secondary`)
- **`Color("Red70", bundle: .sharedUI)`** &rarr; `ColorSystem.Status.error`
- **`Color("Blue70", bundle: .sharedUI)`** &rarr; `ColorSystem.Primary.blue`
- **`Color(NSColor.controlBackgroundColor)`** &rarr; `PanelShellTokens.panelSecondaryBackground`
- **`Color("Primary", bundle: .sharedUI)`** &rarr; `ColorSystem.Colors.primary` (or `ColorSystem.Primary.blue`)
