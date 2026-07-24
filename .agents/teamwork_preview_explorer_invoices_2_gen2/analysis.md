# UI Token and Component Standardization Compliance Audit - Packages/Feature.Invoices

## Executive Summary
This audit reports the UI token and component standardization compliance check for `Packages/Feature.Invoices` according to the guidelines in `PROJECT.md` and `ORIGINAL_REQUEST.md`. 
No instances of hardcoded numeric font size/system fonts (`.font(.system(size:...))`) or raw hex codes/RGB color components (`Color(red:...)`) were found. However, there are:
- **12 instances** of raw asset catalog colors (`Color("name", bundle: ...)` or `Color(NSColor...)`) that bypass the standard design system.
- **Over 28 instances** of system/semantic colors (`.secondary`, `.tertiary`, `Color.clear`, `Color.accentColor`) declared inline instead of via `ColorSystem` or `StyleGuide.Colors`.
- **26 instances** of standard SwiftUI system semantic fonts (`.headline`, `.subheadline`, `.caption`, `.title3`, `.callout`) that bypass the centralized `StyleGuide.Typography` tokens.

---

## 1. Compliance Gap: Raw / Asset Color Usage

The following files use raw AppKit/system colors or perform direct asset catalog color lookups bypassing `ColorSystem` or `StyleGuide.Colors`.

### Primary Visual Interface (InvoicesView & Toolbar)

#### `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesView.swift`
- **Line 70**: Raw background clear
  ```swift
  .background(Color.clear)
  ```
- **Line 212**: Raw foreground white
  ```swift
  .foregroundColor(Color("White", bundle: .sharedUI))
  ```
- **Line 216**: Raw foreground white with opacity
  ```swift
  .foregroundColor(Color("White", bundle: .sharedUI).opacity(0.8))
  ```
- **Line 230**: Raw foreground white
  ```swift
  .foregroundColor(Color("White", bundle: .sharedUI))
  ```
- **Line 233**: Raw background Gray20
  ```swift
  .background(Color("Gray20", bundle: .sharedUI))
  ```
- **Line 246**: Raw foreground white
  ```swift
  .foregroundColor(Color("White", bundle: .sharedUI))
  ```
- **Line 249**: Raw background Red70
  ```swift
  .background(Color("Red70", bundle: .sharedUI))
  ```
- **Line 263**: Raw foreground white
  ```swift
  .foregroundColor(Color("White", bundle: .sharedUI))
  ```
- **Line 266**: Raw background Blue70
  ```swift
  .background(Color("Blue70", bundle: .sharedUI))
  ```
- **Line 280**: Raw foreground white
  ```swift
  .foregroundColor(Color("White", bundle: .sharedUI))
  ```
- **Line 283**: Raw background Blue70
  ```swift
  .background(Color("Blue70", bundle: .sharedUI))
  ```
- **Line 297**: Raw background clear
  ```swift
  .background(.clear)
  ```

#### `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesContentToolbar.swift`
- **Line 72**: Raw color Primary lookup
  ```swift
  .foregroundStyle(Color("Primary", bundle: .sharedUI))
  ```

#### `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceEditor.swift`
- **Line 87**: Raw AppKit controlBackgroundColor lookup
  ```swift
  .background(Color(NSColor.controlBackgroundColor))
  ```

### System Color Usages (To Be Migrated to Design Tokens)

#### `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceFilterPopoverContent.swift`
- **Line 69**: `.foregroundStyle(.secondary)`
- **Line 103**: `.foregroundStyle(.secondary)`
- **Line 129**: `.foregroundStyle(.tertiary)`
- **Line 150**: `.foregroundStyle(.secondary)`
- **Line 166**: `.foregroundStyle(.secondary)`
- **Line 174**: `.foregroundStyle(.tertiary)`
- **Line 178**: `.foregroundStyle(.secondary)`
- **Line 193**: `.foregroundStyle(.secondary)`
- **Line 208**: `.foregroundStyle(.tertiary)`
- **Line 243**: `.foregroundStyle(isSelected ? statusColor : .secondary)`
- **Line 252**: `.background(isSelected ? statusColor.opacity(...) : Color.secondary.opacity(StyleGuide.Opacity.faint))`
- **Line 256**: `.strokeBorder(isSelected ? statusColor.opacity(...) : Color.clear, lineWidth: 1)`
- **Line 292**: `.foregroundStyle(isSelected ? ColorSystem.Primary.blue : .secondary)`
- **Line 302**: `.background(isSelected ? ColorSystem.Primary.blue.opacity(...) : Color.secondary.opacity(StyleGuide.Opacity.faint))`
- **Line 306**: `.strokeBorder(isSelected ? ColorSystem.Primary.blue.opacity(...) : Color.clear, lineWidth: 1)`

#### `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceInspectorFormView.swift`
- **Line 197**: `.foregroundStyle(.primary)`
- **Line 234**: `.foregroundStyle(.secondary)`
- **Line 256**: `Text("%").foregroundStyle(.tertiary)`
- **Line 264**: `Text("$").foregroundStyle(.tertiary)`
- **Line 385**: `.foregroundStyle(.primary)`

#### `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceLineItemsSection.swift`
- **Line 20**: `.foregroundStyle(.secondary)`
- **Line 56**: `Color.clear`
- **Line 60**: `.foregroundStyle(.tertiary)`
- **Line 68**: `item.itemDescription.isEmpty ? .secondary : .primary`
- **Line 76**: `.foregroundStyle(.secondary)`
- **Line 81**: `.foregroundStyle(.secondary)`
- **Line 113**: `.background(Color.accentColor.opacity(StyleGuide.Opacity.light))` (System accent)
- **Line 117**: `.strokeBorder(Color.accentColor.opacity(StyleGuide.Opacity.strong)...)` (System accent)
- **Line 133**: `.foregroundStyle(.primary)`
- **Line 142**: `.foregroundStyle(.secondary)`
- **Line 191**: `.foregroundStyle(.secondary)`
- **Line 204**: `.foregroundStyle(.secondary)`
- **Line 223**: `.foregroundStyle(.secondary)`
- **Line 232**: `.foregroundStyle(.secondary)`
- **Line 241**: `.foregroundStyle(.secondary)`
- **Line 243**: `Text("$").foregroundStyle(.tertiary)`
- **Line 255**: `.foregroundStyle(.secondary)`

---

## 2. Compliance Gap: Raw / System Font Usage

The following files use system semantic font modifiers (`.headline`, `.subheadline`, `.caption`, `.title3`, `.callout`) directly, bypassing semantic font definitions under `StyleGuide.Typography`.

#### `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceEditor.swift`
- **Line 84**: Direct `.headline` font
  ```swift
  .font(.headline)
  ```

#### `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoicesView.swift`
- **Line 213**: Direct `.subheadline` font
  ```swift
  .font(.subheadline)
  ```
- **Line 217**: Direct `.caption` font
  ```swift
  .font(.caption)
  ```

#### `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/Components/InvoicesDetailToolbar.swift`
- **Line 198**: Direct `.caption` font
  ```swift
  .font(.caption)
  ```

#### `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceFilterPopoverContent.swift`
- **Line 54**: `.font(.headline)`
- **Line 68**: `.font(.subheadline.weight(.medium))`
- **Line 75**: `.font(.caption)`
- **Line 102**: `.font(.subheadline.weight(.medium))`
- **Line 110**: `.font(.caption)`
- **Line 149**: `.font(.subheadline.weight(.medium))`
- **Line 157**: `.font(.caption)`
- **Line 167**: `.font(.callout)`
- **Line 179**: `.font(.callout)`
- **Line 192**: `.font(.subheadline.weight(.medium))`
- **Line 199**: `.font(.caption)`
- **Line 207**: `.font(.caption)`

#### `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceInspectorFormView.swift`
- **Line 192**: `.font(.headline)`
- **Line 195**: `.font(.title3)`
- **Line 233**: `.font(.caption)`
- **Line 384**: `.font(.headline)`

#### `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/InvoiceLineItemsSection.swift`
- **Line 59**: `.font(.caption)`
- **Line 132**: `.font(.headline)`
- **Line 141**: `.font(.caption)`
- **Line 190**: `.font(.caption)`
- **Line 203**: `.font(.caption)`
- **Line 218**: `.font(.headline)`
- **Line 222**: `.font(.caption)`
- **Line 231**: `.font(.caption)`
- **Line 240**: `.font(.caption)`
- **Line 258**: `.font(.headline)`

#### `Packages/Feature.Invoices/Sources/Feature_Invoices/Views/Components/WritingToolsTextEditor.swift` (AppKit Bridge)
- **Line 34**: Direct AppKit system font selection (needs mapping or verification)
  ```swift
  textView.font = .systemFont(ofSize: NSFont.systemFontSize)
  ```

---

## 3. Recommendation for Migration

1. **Map Asset Colors to Neutral/Theme Colors**:
   - `Color("White", ...)`, `Color("Gray20", ...)` -> `ColorSystem.Neutral.white`, `ColorSystem.Neutral.gray200` (or `StyleGuide.Colors.secondary`).
   - `Color("Red70", ...)` -> `ColorSystem.Status.error`.
   - `Color("Blue70", ...)` -> `ColorSystem.Primary.blue` or `ColorSystem.Primary.darkBlue`.
   - `Color("Primary", ...)` -> `StyleGuide.Colors.primary`.
   - `Color(NSColor.controlBackgroundColor)` -> Use system window background mapping, or map to a custom ColorSystem neutral background token.
2. **Apply Semantic Spacing/Color to Dividers and Borders**:
   - Swap `.foregroundStyle(.tertiary)` and similar system colors for designated neutral grayscale tokens (e.g. `ColorSystem.Neutral.gray300` or `StyleGuide.Colors.border`).
3. **Typography Standardisation**:
   - Replace standard `.font(.caption)`, `.font(.headline)`, and `.font(.subheadline)` with semantic tokens such as `StyleGuide.Typography.caption`, `StyleGuide.Typography.itemTitle` (`.headline`), and `StyleGuide.Typography.itemSubtitle` (`.subheadline`).
