# Handoff Report: DocumentGridLayoutMath Sizing Modes & Math Analysis

## 1. Observation

### File Paths and Signatures
The core math layout functions are defined in the file `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/DocumentGridLayoutMath.swift`.

#### 1. Column Width Resolution Function
Line 28:
```swift
    static func resolvedColumnWidths(
        columnConfigs: [ColumnWidthConfig],
        contentColumnWidths: [Int: CGFloat],
        totalWidth: CGFloat,
        defaultAutoColumnWidth: CGFloat = DocumentGridLayoutMath.defaultAutoColumnWidth
    ) -> [CGFloat]
```

#### 2. Clamping and Shrinking Functions
Line 80:
```swift
    static func clampColumnWidths(
        _ widths: [CGFloat],
        targetWidth: CGFloat,
        flexibleIndices: [Int],
        autoSizedIndices: [Int]
    ) -> [CGFloat]
```
Line 99:
```swift
    static func shrinkWidths(
        _ widths: inout [CGFloat],
        for indices: [Int],
        excessWidth: inout CGFloat
    )
```

#### 3. Row Height Resolution Function
Line 198:
```swift
    static func resolvedRowHeights(
        data: [[DocumentTableItem]],
        style: ComponentStyle,
        columnWidths: [CGFloat]
    ) -> [CGFloat]
```

#### 4. Text Measurement Function
Line 129:
```swift
    static func measureTextSize(
        _ attributedString: NSAttributedString,
        width: CGFloat,
        lineLimit: Int?
    ) -> CGSize
```

#### 5. Configuration Entities
The configurations are defined in:
- `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/DocumentGridLayout+Types.swift`:
  ```swift
  public struct ColumnWidthConfig: Equatable {
      public let isFlexible: Bool
      public let fixedWidth: CGFloat?
      public let isAutoSized: Bool
      ...
  }
  ```
- `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Models/Domain/InvoiceComponentStyle+Axis.swift`:
  ```swift
  public enum TableSizingMode: String, Codable, CaseIterable, Sendable {
      case flexible = "Flexible"
      case fit = "Fit"
      case fixed = "Fixed"
  }
  ```

---

## 2. Logic Chain

### A. Column Width Calculations Step-by-Step
We analyzed how `resolvedColumnWidths` evaluates column widths under the three sizing modes:

1. **Initial Pass Allocation**:
   - For **Fixed** columns (`config.fixedWidth != nil` and not auto-sized), width is allocated as exactly `fixedWidth`. The allocated amount is subtracted from `remainingWidth`.
   - For **Fit (AutoSized)** columns (`config.isAutoSized == true`), the layout queries the content-measured widths (`contentColumnWidths`).
     - If the measured width is greater than $0$, it uses `measuredWidth = contentColumnWidths[index]`.
     - Otherwise, it falls back to `defaultAutoColumnWidth` ($20$).
     - The column's width is set to `max(measuredWidth, config.fixedWidth ?? 0)`.
     - This allocated width is subtracted from `remainingWidth`.
   - For **Flexible** columns (`config.isFlexible == true`), indices are tracked in `flexibleIndices` and deferred for the second pass.

2. **Flexible Columns Pass**:
   - If `flexibleIndices` is not empty, the remaining width (`remainingWidth`) is divided equally among them:
     $$\text{perColumnWidth} = \frac{\max(\text{remainingWidth}, 0)}{\text{flexibleIndices.count}}$$
   - For each flexible index, its width is resolved to:
     $$\text{width} = \max(\text{perColumnWidth}, \text{measuredWidth}, \text{minimumWidth})$$
     where `measuredWidth` is `contentColumnWidths[index]` (defaults to $0$) and `minimumWidth` is `config.fixedWidth` (defaults to $0$).

3. **Clamp & Excess Width Reduction (Proportional Shrinking)**:
   If the sum of widths exceeds the `totalWidth`, `clampColumnWidths` resolves the excess width $E = \sum w_i - \text{totalWidth}$ by applying `shrinkWidths` in three hierarchical priority phases:
   - **Phase A**: Shrink flexible columns.
   - **Phase B**: Shrink Fit (AutoSized) columns.
   - **Phase C**: Shrink all columns (acting as a hard limit fallback, affecting Fixed columns too).
   
   The proportional shrink formula applied to a subset of column indices $I$ with total width $W_I = \sum_{j \in I} w_j$:
   - Let $S = \min(E, W_I)$ be the shrink amount.
   - Let the scaling factor be $F = \max\left(\frac{W_I - S}{W_I}, 0\right)$.
   - For each column $i \in I$, updated width is:
     $$w_i' = w_i \times F$$
   - The remaining excess width is updated: $E' = E - S$.

### B. Row Height Calculations Step-by-Step
We analyzed how `resolvedRowHeights` determines heights under the modes:

1. **Fixed Row Sizing**:
   If the row's configuration satisfies `isFlexible == false`, `isAutoSized == false`, and its default size is greater than $0$, the row height is immediately resolved to the constant configured size:
   $$\text{height} = \text{size}$$

2. **Fit / AutoSized / Flexible Row Sizing**:
   For each cell in the row that has non-transparent content:
   - Available layout width for cell content is computed by subtracting cell paddings from the resolved column width:
     $$\text{cellWidth} = \max(0, \text{columnWidths}[columnIndex] - \text{padding} \times 2)$$
   - The text's typographic bounds are measured via CoreText `measureTextSize` within the constrained `cellWidth` and the cell's `lineLimit`.
   - The computed cell height is:
     $$\text{cellHeight} = \text{measuredHeight} + \text{padding} \times 2$$
   - The resolved row height is the maximum height across all cell items in that row, floor-capped by the row configuration's size:
     $$\text{rowHeight} = \max(\max_{j \in \text{cells}} (\text{cellHeight}_j), \text{rowConfig.size})$$

---

## 3. Caveats
- **Line Wrapping**: The CoreText measurement logic in `measureTextSize` relies on `CTFramesetterSuggestFrameSizeWithConstraints`. If `lineLimit` is defined, it sums `ascent + descent + leading` for lines up to the limit. If leading is negative or omitted in the font description, line separation estimation is purely typographic.
- **Span Columns**: `widthForColumns` calculates spans, but cells that span multiple columns are not accounted for inside the `measureColumnContentWidths` loop, which assumes single column mapping (`item.columnIndex`).

---

## 4. Conclusion
`DocumentGridLayoutMath` defines clean mathematical methods for table axis layouts:
- **Columns**: Fixed columns occupy their specified size; Fit (AutoSized) columns occupy their text width or default fallback ($20$); Flexible columns share the remaining area. In cases of overflow, widths are proportionally scaled down in order of priority: Flexible columns first, followed by AutoSized columns, and lastly Fixed columns.
- **Rows**: Fixed rows occupy their explicit size. Dynamic/Flexible/Fit rows are calculated using CoreText measurements of cell contents wrapped to their column widths, with the row configuration size acting as a minimum floor.

---

## 5. Verification Method

### Test Runner Command
The mathematical operations can be validated by running unit tests under the package directory `Packages/Feature.InvoiceTemplateEditor`:
```bash
swift test
```
Specifically, tests verifying these formulas and modes are located in:
- `Packages/Feature.InvoiceTemplateEditor/Tests/Feature_InvoiceTemplateEditorTests/DocumentGridHeightReliabilityTests.swift`
- `Packages/Feature.InvoiceTemplateEditor/Tests/Feature_InvoiceTemplateEditorTests/DocumentGridExportLayoutTests.swift`
