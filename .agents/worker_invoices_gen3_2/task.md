# Task: Feature.Invoices UI Token Standardization

Standardize colors, fonts, spacing/padding, and corner radii in the `Packages/Feature.Invoices` package views to fully use design tokens from `SharedUI`.

## Guidelines
- Avoid raw numeric literals for padding, corner-radius, or spacing. Use `StyleGuide.Dimensions` tokens.
- Avoid raw asset catalog color lookup strings (`Color("White", ...)`, `Color("Gray20", ...)`, `Color("Red70", ...)`, `Color("Blue70", ...)`, `Color("Primary", ...)`). Use `ColorSystem` or `StyleGuide.Colors`.
- Avoid raw system semantic font size/system font modifiers (`.font(.headline)`, `.font(.caption)`, `.font(.subheadline)`, etc.). Use `StyleGuide.Typography` tokens.
- Keep other code structure and layout unchanged.
- Compile and verify changes with `scripts/refactor-verify.sh`.

## Target Files and Line Items to Standardize

### 1. `InvoicesView.swift`
- Line 210: `VStack(alignment: .leading, spacing: 2)` -> Use `StyleGuide.Dimensions.paddingXXSmall` (2.0).
- Line 239 & 273: `.padding(.trailing, 8)` -> Use `StyleGuide.Dimensions.paddingMedium` (8.0).
- Line 247, 264 & 281: `.padding(.horizontal, 12)` -> Use `StyleGuide.Dimensions.paddingMediumLarge` (12.0).
- Line 248, 265 & 282: `.padding(.vertical, 6)` -> Use `StyleGuide.Dimensions.paddingSmall` (6.0).
- Color changes around lines 212, 216, 230, 233, 246, 249, 263, 266, 280, 283 (ensure they use standard `ColorSystem` or `StyleGuide.Colors` tokens).
- Font changes around lines 213, 217.

### 2. `InvoiceInspectorFormView.swift`
- Line 199: `.padding(.top, 4)` -> Use `StyleGuide.Dimensions.paddingXSmall` (4.0).
- Line 212 & 218: `.frame(minHeight: 60)` -> Use `StyleGuide.Dimensions.inspectorCurrencyFieldWidth` (60.0).
- Line 239 & 263: `HStack(spacing: 2)` -> Use `StyleGuide.Dimensions.paddingXXSmall` (2.0).
- Line 378: `HStack(spacing: 6)` -> Use `StyleGuide.Dimensions.paddingSmall` (6.0).
- Map raw colors (`.foregroundStyle(.primary)`, `.secondary`, `.tertiary`) to `StyleGuide.Colors` and `ColorSystem.Neutral` tokens.
- Map raw fonts (`.font(.headline)`, `.font(.title3)`, `.font(.caption)`) to `StyleGuide.Typography` tokens.

### 3. `InvoiceFilterPopoverContent.swift`
- Line 227: `.frame(maxHeight: 120)` -> Use `DetailSectionTokens.sortPickerWidth` (120.0).
- Line 250: `.padding(.vertical, StyleGuide.Dimensions.paddingSmall + 1)` -> Use `StyleGuide.Dimensions.unsavedIndicatorSize` (7.0).
- Map raw colors (`.foregroundStyle(.secondary)`, `.tertiary`, etc.) to standard color tokens.
- Map raw fonts (`.font(.headline)`, `.font(.subheadline.weight(...))`, `.font(.caption)`, `.font(.callout)`) to `StyleGuide.Typography` tokens.

### 4. `InvoiceLineItemsSection.swift`
- Line 46: `Grid(horizontalSpacing: 4, verticalSpacing: 10)` -> Use `StyleGuide.Dimensions.paddingXSmall` and `StyleGuide.Dimensions.paddingXMedium`.
- Line 126: `HStack(spacing: 6)` -> Use `StyleGuide.Dimensions.paddingSmall`.
- Line 184: `HStack(spacing: 8)` -> Use `StyleGuide.Dimensions.paddingMedium`.
- Line 216: `VStack(alignment: .leading, spacing: 16)` -> Use `StyleGuide.Dimensions.paddingLarge`.
- Line 220, 229 & 238: `VStack(alignment: .leading, spacing: 8)` -> Use `StyleGuide.Dimensions.paddingMedium`.
- Line 228: `HStack(spacing: 12)` -> Use `StyleGuide.Dimensions.paddingMediumLarge`.
- Line 242: `HStack(spacing: 4)` -> Use `StyleGuide.Dimensions.paddingXSmall`.
- Map raw colors and fonts to design tokens.

### 5. `InvoicesContentToolbar.swift`
- Line 72: `Color("Primary", bundle: .sharedUI)` -> Use `StyleGuide.Colors.primary`.

### 6. `InvoiceEditor.swift`
- Line 87: `Color(NSColor.controlBackgroundColor)` -> Use `StyleGuide.Colors.background`.
- Line 84: `.font(.headline)` -> Use `StyleGuide.Typography.itemTitle`.

### 7. `InvoicesDetailToolbar.swift`
- Line 198: `.font(.caption)` -> Use `StyleGuide.Typography.caption`.
