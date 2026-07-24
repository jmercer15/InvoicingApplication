# Static Analysis of Layout Geometry and Sizing Calculations

This report provides a detailed static analysis of the layout components, space allocation formulas, and geometry calculations within the `Feature.InvoiceTemplateEditor` package.

---

## 1. Space Allocation, Sizing, and Alignment Calculations

### A. Sizing Modes and Sizing Calculations (`FlexibleSizeCalculator.swift`)
The layout system supports three child sizing modes defined in `SectionSplit.SizingMode`:
- `.fixed`: Takes a proportion of the available space based on a designated ratio.
- `.expand`: Takes an equal share of the remaining space left after `.shrink` and `.fixed` items are sized.
- `.shrink`: Takes its intrinsic content size (e.g., text height/width or a component size).

The primary calculations in `FlexibleSizeCalculator.calculateSizes` follow this logic:
1. **Shrink Item Allocation**:
   ```swift
   var remainingSize = totalSize
   for i in 0..<count {
       if i < sizingModes.count && sizingModes[i] == .shrink {
           let size = intrinsicSizes[i] ?? 50
           sizes[i] = size
           remainingSize -= size
       }
   }
   remainingSize = max(0, remainingSize)
   ```
2. **Fixed Item Allocation**:
   Fixed items receive a width/height proportional to their ratio relative to `flexibleSpace` (which is the `remainingSize` after subtracting shrink sizes):
   ```swift
   let size = ratio * flexibleSpace
   sizes[i] = size
   usedFixedSpace += size
   ```
3. **Expand Item Allocation**:
   If there are `.expand` items, they divide the leftover space equally:
   ```swift
   let remainingForExpand = max(0, flexibleSpace - usedFixedSpace)
   let sizePerExpand = remainingForExpand / CGFloat(expandCount)
   ```
4. **Unused Space Redistribution (No Expand Items)**:
   If no `.expand` items exist, unused space is redistributed to `.fixed` items based on their relative ratios:
   ```swift
   let remainingUnused = flexibleSpace - usedFixedSpace
   if remainingUnused > 0 {
       let extra = remainingUnused * (ratio / totalFixedRatio)
       sizes[i] += extra
   }
   ```
5. **Lower Bounds Clamp**:
   Finally, all sizes are clamped to at least zero:
   ```swift
   sizes[i] = max(0, sizes[i])
   ```

### B. Grid Sizing and Spacing calculations (`GridSplitView.swift` & `RatioBasedLayout.swift`)
In `GridSplitView` and `RatioBasedLayout`, available space is computed after subtracting padding and spacing:
- **Linear Split available size**:
  ```swift
  let availablePrimary = max(0, containerSize - (clampedPadding * 2) - totalSpacing)
  ```
- **Grid Split available size**:
  ```swift
  let availableWidth = max(0, containerSize.width - (padding * 2) - (spacing * CGFloat(max(0, split.gridColumns - 1))))
  let availableHeight = max(0, containerSize.height - (padding * 2) - (spacing * CGFloat(max(0, split.gridRows - 1))))
  ```

### C. Alignment Modes and Placement Calculations
Alignment is calculated in two main places:
- **Document Grid Alignment** (`DocumentGridLayout.swift`):
  Uses standard SwiftUI alignments and grid cell anchors based on `UnitPoint` mapping.
- **PDF Export Alignment** (`ExportService+SectionLayout.swift`):
  Aligns a component inside its final bounding box using PDF coordinate space (bottom-left origin, Y up):
  ```swift
  let finalX: CGFloat
  switch alignment.horizontal {
  case .leading: finalX = bounds.minX
  case .center: finalX = bounds.midX - finalSize.width / 2
  case .trailing: finalX = bounds.maxX - finalSize.width
  }
  
  let finalY: CGFloat
  switch alignment.vertical {
  case .top: finalY = bounds.maxY - finalSize.height // PDF: top is maxY
  case .center: finalY = bounds.midY - finalSize.height / 2
  case .bottom: finalY = bounds.minY // PDF: bottom is minY
  }
  ```

---

## 2. Geometry Safety and Risk Assessment

### A. Division by Zero Risks
1. **Expand Sizing Calculation**:
   ```swift
   let sizePerExpand = remainingForExpand / CGFloat(expandCount)
   ```
   *Safety Analysis*: Guarded by `if expandCount > 0` directly preceding it. Completely safe.
2. **Fixed Sizing Redistribution**:
   ```swift
   let extra = remainingUnused * (ratio / totalFixedRatio)
   ```
   *Safety Analysis*: Guarded by `if totalFixedRatio > 0` directly preceding it. Completely safe.
3. **Ratio Normalization** (`SectionSplit+RatioAndSplit.swift`):
   ```swift
   let total = splitRatios.reduce(0, +)
   if total > 0 {
       splitRatios = splitRatios.map { $0 / total }
   }
   ```
   *Safety Analysis*: Guarded by `if total > 0`. Completely safe.
4. **Grid Row / Column Index Conversion** (`SectionSplit+ComponentRegistry.swift`):
   ```swift
   func rowColumn(for cellIndex: Int) -> (row: Int, column: Int) {
       let row = cellIndex / gridColumns
       let column = cellIndex % gridColumns
       return (row: row, column: column)
   }
   ```
   *Safety Analysis*: **POTENTIAL RISK**. If `gridColumns` is `0`, this division will trigger a runtime crash.
   *Mitigation details*: While standard constructors and Decodable defaults enforce `gridColumns` default to `2` (e.g., `gridColumns = try container.decodeIfPresent(Int.self, forKey: .gridColumns) ?? 2`), there is no structural guard inside `rowColumn(for:)` to prevent division if the model somehow has `gridColumns = 0`. For maximum robustness, a guard `gridColumns > 0` should be used, returning `(0, 0)` on fallback.
5. **Resize Ratio Normalization** (`ResizeHelpers.swift`):
   ```swift
   let finalTotal = newCurrentRatio + newNextRatio
   let scaleFactor = totalRatio / finalTotal
   ```
   *Safety Analysis*: Guarded because both `newCurrentRatio` and `newNextRatio` are clamped to `max(minRatio, ...)` where `minRatio` defaults to `0.05`. Thus, `finalTotal >= 0.10`, preventing division by zero.

### B. Subtraction Without Bounds Checks (Negative Size Risks)
1. **Available Layout Dimension Subtractions**:
   - In `RatioBasedLayout.swift`:
     `let availablePrimary = max(0, ...)`
   - In `GridSplitView.swift`:
     `let availableWidth = max(0, ...)`
     `let availableHeight = max(0, ...)`
   - In `SplittableRectangleView.swift`:
     `let innerSize = CGSize(width: max(0, ...), height: max(0, ...))`
   - In `ExportService+SectionLayout.swift`:
     `let contentRect = CGRect(..., width: max(0, ...), height: max(0, ...))`
   *Safety Analysis*: These are all properly wrapped in `max(0, ...)` checks. Even if margins or spacing values exceed the container size, available dimensions will collapse to `0` instead of going negative. This is extremely robust.

---

## 3. Cyclic Layout and View-Update Feedback Loops

### A. `DocumentGridView` Cell Height Feedback Loop
The `DocumentGridView` measures cell heights using a preference key, updates a parent `@State` height, and constraints the wrapper frame with that height:
- Cell: `.background(DocumentGridCellHeightReporter(rowIndex: item.rowIndex))`
- View: `.onPreferenceChange(DocumentGridCellHeightPreferenceKey.self) { ... }`
- Wrapper Frame: `.frame(height: calculatedGridHeight > 0 ? calculatedGridHeight : nil)`

*Why a loop does NOT occur*:
1. The `Grid` containing the cells has `.fixedSize(horizontal: false, vertical: true)` applied.
2. `.fixedSize(vertical: true)` forces SwiftUI to lay out the Grid at its intrinsic height, ignoring any vertical constraints imposed by the parent wrapper's `.frame(height:)`.
3. Thus, changing `.frame(height: calculatedGridHeight)` on the wrapper does not change the layout inputs/constraints of the child cells, preventing their heights from changing and breaking any potential infinite layout/measurement cycle.
4. Additionally, height updates are gated by `if abs(totalHeight - calculatedGridHeight) > 0.5`, filtering out negligible floating-point layout changes.

---

## 4. Build and Test Validation Summary

- **Package Build**: Succeeded with zero compiler errors.
- **Package Tests**: 8 tests executed across `DefaultInvoiceTemplateTests` and `SectionSplitGridMutationTests`, with 0 failures.
