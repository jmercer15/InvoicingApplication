# Audit Report: Design Token Compliance & Layout Issues in `Feature.Invoices`

This report summarizes the compliance audit of `Packages/Feature.Invoices` for design tokens (colors, fonts, padding, spacing, dimensions) and panel shell structures.

---

## 1. Observation

A forensic scan of SwiftUI views under `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/` was conducted to find raw literals, hardcoded colors, standard fonts, and panel layout issues. Below is the list of exact files, line numbers, and verbatim violations.

### A. Hardcoded Color and Asset Name Violations
- **`InvoicesView.swift`**:
  - `Line 212`: `Color("White", bundle: .sharedUI)`
  - `Line 216`: `Color("White", bundle: .sharedUI)`
  - `Line 230`: `Color("White", bundle: .sharedUI)`
  - `Line 233`: `Color("Gray20", bundle: .sharedUI)` (should use token or `StyleGuide.Colors.secondary`)
  - `Line 246`: `Color("White", bundle: .sharedUI)`
  - `Line 249`: `Color("Red70", bundle: .sharedUI)` (should use `ColorSystem.Status.error`)
  - `Line 263`: `Color("White", bundle: .sharedUI)`
  - `Line 266`: `Color("Blue70", bundle: .sharedUI)` (should use `ColorSystem.Primary.blue` or `StyleGuide.Colors.primary`)
  - `Line 280`: `Color("White", bundle: .sharedUI)`
  - `Line 283`: `Color("Blue70", bundle: .sharedUI)`
- **`InvoiceEditor.swift`**:
  - `Line 87`: `.background(Color(NSColor.controlBackgroundColor))` (bypasses ColorSystem / StyleGuide tokens)
- **`InvoiceLineItemsSection.swift`**:
  - `Line 113`: `Color.accentColor` (should map to tokenized primary color)
  - `Line 115`: `Color.accentColor`

### B. Standard and Hardcoded Font Violations
- **`InvoiceFilterPopoverContent.swift`**:
  - `Line 54`: `.font(.headline)`
  - `Line 68`: `.font(.subheadline.weight(.medium))`
  - `Line 75`: `.font(.caption)`
  - `Line 102`: `.font(.subheadline.weight(.medium))`
  - `Line 110`: `.font(.caption)`
  - `Line 149`: `.font(.subheadline.weight(.medium))`
  - `Line 157`: `.font(.caption)`
  - `Line 167`: `.font(.callout)`
  - `Line 179`: `.font(.callout)`
  - `Line 192`: `.font(.subheadline.weight(.medium))`
  - `Line 199`: `.font(.caption)`
  - `Line 207`: `.font(.caption)`
- **`InvoiceInspectorFormView.swift`**:
  - `Line 192`: `.font(.headline)`
  - `Line 195`: `.font(.title3)`
  - `Line 233`: `.font(.caption)`
  - `Line 384`: `.font(.headline)`
- **`InvoiceLineItemsSection.swift`**:
  - `Line 59`: `.font(.caption)`
  - `Line 132`: `.font(.headline)`
  - `Line 141`: `.font(.caption)`
  - `Line 190`: `.font(.caption)`
  - `Line 203`: `.font(.caption)`
  - `Line 218`: `.font(.headline)`
  - `Line 222`: `.font(.caption)`
  - `Line 231`: `.font(.caption)`
  - `Line 240`: `.font(.caption)`
  - `Line 258`: `.font(.headline)`
- **`InvoiceEditor.swift`**:
  - `Line 84`: `.font(.headline)`
- **`InvoicesView.swift`**:
  - `Line 213`: `.font(.subheadline)`
  - `Line 217`: `.font(.caption)`

### C. Raw Numeric Spacing & Margin/Padding Violations
- **`InvoicesView.swift`**:
  - `Line 210`: `spacing: 2` in `VStack`
  - `Line 239`: `.padding(.trailing, 8)`
  - `Lines 247, 264, 281`: `.padding(.horizontal, 12)`
  - `Lines 248, 265, 282`: `.padding(.vertical, 6)`
- **`InvoiceInspectorFormView.swift`**:
  - `Line 199`: `.padding(.top, 4)`
  - `Line 239`: `spacing: 2` in `HStack`
  - `Line 263`: `spacing: 2` in `HStack`
  - `Line 378`: `spacing: 6` in `HStack`
- **`InvoiceLineItemsSection.swift`**:
  - `Line 40`: `.padding()` (uses default native spacing instead of tokens)
  - `Line 46`: `Grid(horizontalSpacing: 4, verticalSpacing: 10)`
  - `Line 126`: `spacing: 6` in `HStack`
  - `Line 184`: `spacing: 8` in `HStack`
  - `Line 216`: `spacing: 16` in `VStack`
  - `Line 220`: `spacing: 8` in `VStack`
  - `Line 228`: `spacing: 12` in `HStack`
  - `Line 229`: `spacing: 8` in `VStack`
  - `Line 238`: `spacing: 8` in `VStack`
  - `Line 242`: `spacing: 4` in `HStack`
  - `Line 262`: `.padding()`
- **`InvoiceEditor.swift`**:
  - `Line 86`: `.padding()`

### D. Raw Frame Height / Width Violations
- **`InvoiceFilterPopoverContent.swift`**:
  - `Line 227`: `.frame(maxHeight: 120)`
- **`InvoiceInspectorFormView.swift`**:
  - `Line 212`: `.frame(minHeight: 60)`
  - `Line 218`: `.frame(minHeight: 60)`

---

## 2. Logic Chain

1. **Rule Base**: All visual design elements (spacing, margin, padding, colors, and typography) must be governed by `SharedUI` tokens (`StyleGuide.swift` and `ColorSystem.swift`).
2. **Analysis of Color Usage**: Raw asset names (e.g. `"White"`, `"Red70"`, `"Blue70"`) bypass the compiler check for theme tokens, causing visual regression vulnerabilities. They must be replaced with corresponding dynamic options like `ColorSystem.Neutral.white`, `ColorSystem.Status.error`, and `ColorSystem.Primary.blue`.
3. **Analysis of Typography**: Direct system font calls (like `.font(.headline)`, `.font(.caption)`) violate standard typography scaling rules. They must be replaced with the semantic token properties from `StyleGuide.Typography`.
4. **Analysis of Layout Spacing/Dimensions**: Arbitrary literals (like `2`, `4`, `6`, `8`, `12` for spacing, and `60` or `120` for heights) create alignment jitter and ignore display scaling constraints. They should utilize `StyleGuide.Dimensions` (e.g., `paddingXSmall`, `paddingSmall`, `paddingMedium`, etc.) and `@ScaledMetric` properties where responsive scaling is required.
5. **Structural Panel Check**: Outermost split navigation columns in `AppShell` (`WorkspaceSplitView.swift` lines 78 and 119) automatically adopt `.standardPanelShell(role:)`. Thus, no layout wrapper gaps exist in `Feature.Invoices`.

---

## 3. Caveats

- Canvas drawing and PDF rendering logic inside `InvoiceTemplateRendererView` / `A4InvoiceSheetView` recreate exact document geometry (standard A4 margins/ratios). This document-specific formatting is separate from application-level design token compliance, so canvas dimensions were not marked as violations.
- Direct system font setups inside the `NSViewRepresentable` text view (`WritingToolsTextEditor.swift`) are left intact, as they leverage AppKit native sizing to map to OS-level standard text field behaviors.

---

## 4. Conclusion

The `Packages/Feature.Invoices` module exhibits numerous design token violations (mainly raw font modifiers, custom asset color loading, and hardcoded layout dimensions). Outer panel shell layouts are already fully integrated at the AppShell level and do not require modification.

### Recommended Action Plan (Handoff to Implementer)
1. **Migrate Fonts**: Map all instances of `.font(.headline)`, `.font(.caption)`, etc. to semantic tokens under `StyleGuide.Typography` (such as `StyleGuide.Typography.itemTitle` or `StyleGuide.Typography.caption`).
2. **Refactor Colors**:
   - Swap out `Color("White")` for `ColorSystem.Neutral.white`.
   - Swap out `Color("Red70")` for `ColorSystem.Status.error`.
   - Swap out `Color("Blue70")` for `ColorSystem.Primary.blue` or `ColorSystem.Primary.lightBlue`.
   - Swap out `Color("Gray20")` for `StyleGuide.Colors.secondary`.
   - Swap `Color(NSColor.controlBackgroundColor)` for `PanelShellTokens.panelSecondaryBackground`.
   - Map `Color.accentColor` to `ColorSystem.Primary.blue`.
3. **Systematize Spacing and Frames**:
   - Replace literal padding values and `spacing:` declarations with tokens from `StyleGuide.Dimensions` (e.g. `spacing: StyleGuide.Dimensions.paddingSmall`).
   - Standardize text area minHeight frame values (e.g., map `60` and `120` to appropriate dimension tokens, or declare scaled dimensions).

---

## 5. Verification Method

To verify compilation and test behavior after the implementer applies the changes:
1. **Compilation Check**: Run compilation via the compiler:
   ```bash
   swift build -p Packages/Feature.Invoices
   ```
2. **Visual Inspection**:
   - Inspect popover controls and lists to ensure that spacing aligns with the standard grid.
   - Toggle macOS Dark Mode to verify that refactored colors dynamically shift.
