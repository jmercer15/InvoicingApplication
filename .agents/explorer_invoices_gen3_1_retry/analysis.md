# Token Compliance Gap Analysis — Feature.Invoices

Analysis of token compliance gaps in the `Feature.Invoices` package at `Packages/Feature.Invoices`. Inspecting files under `Sources/Feature_Invoices/Views/` to locate raw numeric literals for padding, corner-radius, spacing, or local custom/hardcoded colors.

## Summary of Findings
- **4 files** highlighted in request investigated: `InvoiceEditor.swift`, `InvoiceFilterPopoverContent.swift`, `InvoiceInspectorFormView.swift`, `InvoiceLineItemsSection.swift`.
- **2 additional files** in `Sources/Feature_Invoices/Views/` found containing compliance gaps: `InvoicesContentToolbar.swift`, `InvoicesView.swift`.
- Core gaps include: usage of standard system colors (e.g., `Color.white`, `NSColor.controlBackgroundColor`), raw animation durations, raw asset name color lookups, and raw dimension literals for text area heights and border line widths.

---

## Findings by File

### 1. `InvoiceEditor.swift`
- **Location**: Line 87
- **Raw Code**: `.background(Color(NSColor.controlBackgroundColor))`
- **Issue**: Direct lookup of system `NSColor.controlBackgroundColor` bypasses design tokens.
- **Recommended Mapping**: Map to `PanelShellTokens.panelSecondaryBackground` or `ColorSystem.Neutral.gray50`.

### 2. `InvoiceFilterPopoverContent.swift`
- **Location**: Line 227
- **Raw Code**: `.frame(maxHeight: 120)`
- **Issue**: Raw numeric literal height constraint for the client selection scroll view.
- **Recommended Mapping**: Map to a defined layout token or local layout constant (e.g., `StyleGuide.Dimensions.paddingEmptyState * 3` or similar height token if created).
- **Location**: Lines 256, 306
- **Raw Code**: `lineWidth: 1`
- **Issue**: Raw numeric literal for stroke borders.
- **Recommended Mapping**: Map to `StyleGuide.Dimensions.calendarDividerWidth` (0.5), or define a standard border width token, or use `StyleGuide.Dimensions.hairlineWidth * 2` (1.0).

### 3. `InvoiceInspectorFormView.swift` (InvoiceEditorFormContent)
- **Location**: Lines 212, 218
- **Raw Code**: `.frame(minHeight: 60)` (twice)
- **Issue**: Raw numeric literal height limit for note-taking text editors.
- **Recommended Mapping**: Create and use a text area minimum height token: `StyleGuide.Dimensions.textAreaMinHeight` or use a multiple of existing padding tokens (e.g., `StyleGuide.Dimensions.paddingLarge * 3.75`).

### 4. `InvoiceLineItemsSection.swift`
- **Location**: Line 117
- **Raw Code**: `StrokeStyle(lineWidth: 1, ...)`
- **Issue**: Raw border width `1` on the "Add Line Item" button.
- **Recommended Mapping**: Replace with a custom multiplier of `StyleGuide.Dimensions.hairlineWidth * 2` or map to a standard border width token.

### 5. `InvoicesContentToolbar.swift`
- **Location**: Line 72
- **Raw Code**: `Color("Primary", bundle: .sharedUI)`
- **Issue**: Raw asset name color lookup bypassing compiler-checked `ColorSystem` or `StyleGuide.Colors`.
- **Recommended Mapping**: Replace with `ColorSystem.Primary.blue` or `StyleGuide.Colors.primary`.

### 6. `InvoicesView.swift`
- **Location**: Line 171
- **Raw Code**: `withAnimation(.easeOut(duration: 0.2))`
- **Issue**: Raw animation duration of `0.2` seconds.
- **Recommended Mapping**: Replace with `StyleGuide.Animations.durationMedium` or use standard transition `PanelShellTokens.shellTransition`.
- **Location**: Lines 212, 215, 229, 245, 262, 279
- **Raw Code**: `Color.white` and `Color.white.opacity(0.8)`
- **Issue**: Direct usage of standard system `.white` and raw opacity literals.
- **Recommended Mapping**: Replace with `ColorSystem.Neutral.white` and use `StyleGuide.Opacity.strong` for opacity levels.

---

## Fix Strategy Recommendations

| Raw Styling Element | Current Code Reference | Target Design Token | File & Line |
| :--- | :--- | :--- | :--- |
| **System Background Color** | `NSColor.controlBackgroundColor` | `PanelShellTokens.panelSecondaryBackground` | `InvoiceEditor.swift:87` |
| **Asset Color Lookup** | `Color("Primary", bundle: .sharedUI)` | `ColorSystem.Primary.blue` or `StyleGuide.Colors.primary` | `InvoicesContentToolbar.swift:72` |
| **Standard White Color** | `Color.white` | `ColorSystem.Neutral.white` | `InvoicesView.swift` (multiple) |
| **Raw Opacity** | `Color.white.opacity(0.8)` | `ColorSystem.Neutral.white.opacity(0.8)` or semantic token | `InvoicesView.swift:215` |
| **Raw Height constraint** | `.frame(maxHeight: 120)` | Introduce new token or use layout constant | `InvoiceFilterPopoverContent.swift:227` |
| **Raw Height constraint** | `.frame(minHeight: 60)` | Introduce `StyleGuide.Dimensions.textAreaMinHeight` | `InvoiceInspectorFormView.swift:212,218` |
| **Raw Animation Duration** | `duration: 0.2` | `StyleGuide.Animations.durationMedium` | `InvoicesView.swift:171` |
| **Raw Border Width** | `lineWidth: 1` | Define `StyleGuide.Dimensions.borderWidth` or use `hairlineWidth * 2` | `InvoiceFilterPopoverContent.swift:256,306`, `InvoiceLineItemsSection.swift:117` |
