# Handoff Report: design token compliance and structural layout issues in `Packages/Feature.Invoices`

This report analyzes design token compliance and structural layout issues in `Packages/Feature.Invoices`. It outlines direct observations, logical analysis, caveats, recommendations for remediation, and a verification plan.

---

## 1. Observations

### A. Raw Numeric Padding/Spacing
Direct paddings and spacings use raw numbers or default values rather than the tokens defined in `StyleGuide.Dimensions` or `DetailSectionTokens`:
- **`InvoiceEditor.swift`**:
  - Line 86: `.padding()` (un-tokenized default spacing)
- **`InvoiceLineItemsSection.swift`**:
  - Line 40: `.padding()`
  - Line 262: `.padding()`
  - Line 46: `Grid(horizontalSpacing: 4, verticalSpacing: 10)` (raw `4` and `10` spacing)
  - Line 184: `HStack(spacing: 8)` (raw `8` spacing)
  - Line 220: `VStack(alignment: .leading, spacing: 8)` (raw `8` spacing)
  - Line 228: `HStack(spacing: 12)` (raw `12` spacing)
  - Line 229: `VStack(alignment: .leading, spacing: 8)` (raw `8` spacing)
  - Line 238: `VStack(alignment: .leading, spacing: 8)` (raw `8` spacing)
  - Line 242: `HStack(spacing: 4)` (raw `4` spacing)
- **`InvoiceInspectorFormView.swift`**:
  - Line 199: `.padding(.top, 4)` (raw `4` padding)
  - Line 239: `HStack(spacing: 2)` (raw `2` spacing)
  - Line 263: `HStack(spacing: 2)` (raw `2` spacing)
  - Line 378: `HStack(spacing: 6)` (raw `6` spacing)
- **`InvoicesView.swift`**:
  - Line 210: `VStack(alignment: .leading, spacing: 2)` (raw `2` spacing)
  - Line 219: `.padding(.leading)` (un-tokenized default padding)
  - Line 239: `.padding(.trailing, 8)` (raw `8` padding)
  - Line 247: `.padding(.horizontal, 12)` (raw `12` padding)
  - Line 248: `.padding(.vertical, 6)` (raw `6` padding)
  - Line 256: `.padding(.trailing)` (un-tokenized default padding)
  - Line 264: `.padding(.horizontal, 12)` (raw `12` padding)
  - Line 265: `.padding(.vertical, 6)` (raw `6` padding)
  - Line 273: `.padding(.trailing, 8)` (raw `8` padding)
  - Line 281: `.padding(.horizontal, 12)` (raw `12` padding)
  - Line 282: `.padding(.vertical, 6)` (raw `6` padding)
- **`InvoiceFilterPopoverContent.swift`**:
  - Line 250: `.padding(.vertical, StyleGuide.Dimensions.paddingSmall + 1)` (raw "+1" adjustment)

### B. Hardcoded Colors / Direct Asset Retrieval
The package resolves assets directly from the shared bundle or uses standard SwiftUI colors rather than traversing `ColorSystem` or `StyleGuide.Colors`:
- **`InvoicesView.swift`**:
  - Lines 212, 216, 230, 246, 263, 280: `Color("White", bundle: .sharedUI)` (direct asset name lookup)
  - Line 233: `Color("Gray20", bundle: .sharedUI)` (maps to `StyleGuide.Colors.secondary`)
  - Line 249: `Color("Red70", bundle: .sharedUI)` (should map to status error colors)
  - Lines 266, 283: `Color("Blue70", bundle: .sharedUI)` (should map to status info / primary blue)
- **`InvoicesContentToolbar.swift`**:
  - Line 72: `Color("Primary", bundle: .sharedUI)` (maps to `StyleGuide.Colors.primary`)
- **`InvoiceLineItemsSection.swift`**:
  - Lines 113, 117: `Color.accentColor` (should map to `ColorSystem.Primary.blue`)
- **`InvoiceFilterPopoverContent.swift`**:
  - Lines 252, 302: `Color.secondary` (raw secondary color)
  - Lines 256, 306: `Color.clear` (used as fallback border color instead of clear token or logic)

### C. Standard Fonts
Directly uses standard SwiftUI text styles rather than `StyleGuide.Typography` tokens:
- **`InvoicesDetailToolbar.swift`**:
  - Line 198: `.font(.caption)`
- **`InvoiceEditor.swift`**:
  - Line 84: `.font(.headline)`
- **`InvoiceFilterPopoverContent.swift`**:
  - Line 54: `.font(.headline)`
  - Lines 68, 102, 149, 192: `.font(.subheadline.weight(.medium))`
  - Lines 75, 110, 157, 199, 207: `.font(.caption)`
  - Lines 167, 179: `.font(.callout)`
- **`InvoiceInspectorFormView.swift`**:
  - Line 192: `.font(.headline)`
  - Line 195: `.font(.title3)`
  - Line 233: `.font(.caption)`
  - Line 384: `.font(.headline)`
- **`InvoiceLineItemsSection.swift`**:
  - Line 59: `.font(.caption)`
  - Line 132: `.font(.headline)`
  - Line 141: `.font(.caption)`
  - Lines 190, 203, 222, 231, 240: `.font(.caption)`
  - Lines 218, 258: `.font(.headline)`
- **`InvoicesView.swift`**:
  - Line 213: `.font(.subheadline)`
  - Line 217: `.font(.caption)`

### D. Raw Frame Dimensions
- **`InvoiceFilterPopoverContent.swift`**:
  - Line 227: `.frame(maxHeight: 120)` (raw 120 limit)
- **`InvoiceInspectorFormView.swift`**:
  - Line 212: `.frame(minHeight: 60)` (raw 60 limits for notes editors)
  - Line 218: `.frame(minHeight: 60)` (raw 60 limits for notes editors)

### E. Missing Panel Shells or Reusable Components
- **Detail & Content Column Shell Placement**: Neither `InvoicesDetailColumn` nor `InvoicesContentColumn` explicitly enforce `.standardPanelShell(role:)` inside their own codebases. (They rely on their parent container `WorkspaceSplitView` to wrap them, but other feature columns, like `ClientDetailView`, explicitly declare `.standardPanelShell(role: .detailPanel)` at their own roots for robust isolation).
- **Secondary Presentation Formats**: The global inspector mode (`presentation == .inspectorForm`) inside `InvoicesDetailColumn` does not wrap form items in standard panels or content paddings, using a standard `.formStyle(.grouped)` directly.
- **Custom Section Headers**:
  - `InvoiceInspectorFormView.swift` (Line 377) implements a custom `sectionHeader(_:icon:)` view builder instead of reusing `DetailSectionHeader` from `SharedUI`.
  - `InvoiceLineItemsSection.swift` (Line 124) replicates this custom section header.
- **Form Rows**: Standard inputs and displays inside `InvoiceEditorFormContent` are rendered using standard SwiftUI Pickers and `DatePicker`s without using the unified `StandardFormRow` layout available in `SharedUI`.

---

## 2. Logic Chain

1. **Rule Mapping**: Design system compliance rules in `Packages/SharedUI` (e.g. `StyleGuide.swift`, `Theme/ColorSystem.swift`, `Layout/PanelShellModifiers.swift`) mandate that features avoid raw constants and reuse standard UI wrappers.
2. **Identification**: Comparing the design token definitions (like `StyleGuide.Dimensions.paddingSmall` or `StyleGuide.Typography.caption`) against local View code revealed that `.font()`, `.padding()`, and `spacing:` declarations bypass these tokens.
3. **Implications**: Bypassing token systems prevents proper adaptation during UI scaling (like dynamic type adjustments) or theme shifts (like high contrast modes), creating layout drifts.
4. **Structural Issues**: The presence of duplicate view builders for section headers (`sectionHeader(_:icon:)`) proves that layout modules are being constructed locally instead of utilizing the `DetailSectionHeader` utility.

---

## 3. Caveats

- We did not audit the `PDFKit` templates rendered in `InvoiceTemplateRendererView` as those are bound by A4 layout limits and the templating compiler rather than the app's macOS Chrome/UI shell system.
- Some frame constraints (like popover widths or percentage fields) are declared using `StyleGuide` dimensions (e.g. `StyleGuide.Dimensions.filterPopoverWidth`), which is correct. Only completely raw literals are flagged in this report.

---

## 4. Conclusion & Recommendation Plan

`Packages/Feature.Invoices` requires a style and layout compliance pass.

### Recommended Implementation Steps:
1. **Refactor Fonts & Colors**:
   - Map `.font(.caption)` to `StyleGuide.Typography.itemSubtitle` or `StyleGuide.Typography.caption` (depending on weight).
   - Map `.font(.headline)` to `StyleGuide.Typography.itemTitle`.
   - Replace `Color("White", bundle: .sharedUI)` with `Color.white` or `ColorSystem.Neutral.white` depending on whether it needs to be transparent/dynamic or pure white in overlays.
   - Replace `"Red70"` with `ColorSystem.Status.error` and `"Blue70"` with `ColorSystem.Primary.blue`.
2. **Refactor Padding/Spacing**:
   - Replace `HStack(spacing: 8)` with `HStack(spacing: StyleGuide.Dimensions.paddingMedium)`.
   - Replace `HStack(spacing: 6)` with `HStack(spacing: StyleGuide.Dimensions.paddingSmall)`.
   - Replace raw values like `.padding(.horizontal, 12)` with `StyleGuide.Dimensions.paddingMedium` (or map to nearest dynamic token).
3. **Rebuild Section Headers**:
   - Migrate custom section headers in `InvoiceInspectorFormView` and `InvoiceLineItemsSection` to utilize the `DetailSectionHeader` reusable component.
4. **Enforce Shells**:
   - Attach `.standardPanelShell(role: .detailPanel)` explicitly in `InvoicesDetailColumn` at the root view level.

---

## 5. Verification Method

To verify these issues independent of this analysis, developers can run the following shell searches in the repository workspace:

1. **To verify standard font usage**:
   ```bash
   grep -rn "\.font(\." Packages/Feature.Invoices/Sources/Feature_Invoices/Views/
   ```
2. **To verify hardcoded color assets**:
   ```bash
   grep -rn "Color(\"" Packages/Feature.Invoices/Sources/Feature_Invoices/Views/
   ```
3. **To run the full suite of compliance/compilation tests**:
   ```bash
   swift test --package-path Packages/Feature.Invoices
   ```
   *Any compilation failures or layout shifts introduced during compliance adjustments will be caught here.*
