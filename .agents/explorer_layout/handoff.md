# Layout Bug Investigation Handoff Report

## 1. Observation

### File 1: `LeafComponentFrameSizing.swift`
- **Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Support/LeafComponentFrameSizing.swift`
- **Line 81-89**:
```swift
    static func intrinsicVerticalSize(for component: InvoiceComponent) -> CGFloat? {
        if let idealHeight = component.idealSize?.height, idealHeight > 0 {
            return idealHeight
        }
        if let content = contentVerticalSize(for: component) {
            return content
        }
        return component.size.height > 0 ? component.size.height : nil
    }
```
- **Line 93-99**:
```swift
    static func contentVerticalSize(for component: InvoiceComponent) -> CGFloat? {
        guard component.usesTableProperties, component.usesContentDrivenRowHeights else { return nil }
        let rowCount = contentDrivenRowCount(for: component)
        guard rowCount > 0 else { return nil }
        let perRow = DocumentGridContentHeight.estimatedSingleLineAutoRowHeight(style: component.style)
        return perRow * CGFloat(rowCount)
    }
```
- **Observation Details**: `contentVerticalSize` falls back to `estimatedSingleLineAutoRowHeight * rowCount`. It completely omits section title height, section title bottom padding, horizontal row borders, and outer table borders.

### File 2: `InvoiceComponent.swift`
- **Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Models/Domain/InvoiceComponent.swift`
- **Line 182-198**:
```swift
        for config in configs {
            if config.isFlexible {
                // If any column is flexible, we can't determine a meaningful minimum width
                // that isn't "collapsed". It's better to fallback to the component's
                // current size (which might be manually set or default).
                return nil
            }
            
            if config.isAutoSized {
                minWidth += config.width // Use measured width (updated by view)
            } else {
                minWidth += config.width
            }
        }
        
        return minWidth > 0 ? minWidth : nil
```
- **Observation Details**: `minIntrinsicWidth` sums only individual column configurations (`config.width`). It completely omits `style.tableBorderWidth` when table borders are shown.

### File 3: `DocumentGridComponent+AnalyticHeight.swift`
- **Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/DocumentGridComponent+AnalyticHeight.swift`
- **Line 32-40**:
```swift
    var effectiveGridHeight: CGFloat {
        if measuredGridHeight > TemplateLayoutEngine.sizeEpsilon {
            return measuredGridHeight
        }
        if cachedAnalyticGridHeight > TemplateLayoutEngine.sizeEpsilon {
            return cachedAnalyticGridHeight
        }
        return analyticGridHeight
    }
```
- **Line 50-79**:
```swift
    func resolvedGridLayoutWidth(for data: [[DocumentTableItem]]? = nil) -> CGFloat {
        let gridData = data ?? activeGridData
        if hasFlexibleColumns {
            if gridWidth > TemplateLayoutEngine.sizeEpsilon {
                return gridWidth
            }
            if let leafWidth = leafContainerSize?.width, leafWidth > 0 {
                return leafWidth
            }
            return 0
        }

        let columnCount = gridData.first?.count ?? columnConfigurations.count
        guard columnCount > 0 else { return 0 }

        let measuredWidths = DocumentGridLayoutMath.measureColumnContentWidths(
            data: gridData,
            style: currentComponent.style,
            columnCount: columnCount
        )
        let configs = columnConfigurations.isEmpty
            ? Array(repeating: ColumnWidthConfig.flexible(), count: columnCount)
            : columnConfigurations
        let contentWidth = DocumentGridLayoutMath.resolvedColumnWidths(
            columnConfigs: configs,
            contentColumnWidths: measuredWidths,
            totalWidth: .greatestFiniteMagnitude
        ).reduce(0, +)
        return contentWidth + borderAppearance.width
    }
```
- **Observation Details**: `resolvedGridLayoutWidth` sums resolved column widths and adds outer border width (`borderAppearance.width`).

### File 4: `SectionSplit+Operations.swift`, `LinearSplitView.swift`, and `GridSplitView.swift`
- **Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Models/Domain/SectionSplit+Operations.swift`
- **Line 176-180**:
```swift
    func intrinsicSizeForChild(at index: Int, along axis: LayoutAxis, document: InvoiceDocument?) -> CGFloat? {
```
- **Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Canvas/LinearSplitView.swift`
- **Line 20-29**:
```swift
        // Calculate intrinsic sizes for shrink mode
        let intrinsicSizes: [Int: CGFloat] = {
            var sizes: [Int: CGFloat] = [:]
            let axis: SectionSplit.LayoutAxis = direction == .horizontal ? .horizontal : .vertical
            for index in 0..<split.splitCount {
                if let size = split.intrinsicSizeForChild(at: index, along: axis) {
                    sizes[index] = size
                }
            }
            return sizes
        }()
```
- **Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Canvas/GridSplitView.swift`
- **Line 24-38**:
```swift
        // Calculate intrinsic sizes for rows and columns
        let rowIntrinsicSizes: [Int: CGFloat] = {
            var sizes: [Int: CGFloat] = [:]
            for rowIndex in 0..<split.gridRows {
                var maxHeight: CGFloat = 0
                for columnIndex in 0..<split.gridColumns {
                    let cellIndex = split.cellIndex(row: rowIndex, column: columnIndex)
                    let height = split.intrinsicSizeForChild(at: cellIndex, along: .vertical) ?? 0
                    maxHeight = max(maxHeight, height)
                }
                if maxHeight > 0 {
                    sizes[rowIndex] = maxHeight
                }
            }
            return sizes
        }()
```
- **Observation Details**: Both `LinearSplitView` and `GridSplitView` calculate intrinsic sizes without passing the `document` parameter. They default to the stale components copied inside the `SectionSplit` tree, rather than using the live document registry.

---

## 2. Logic Chain

### Why `component.idealSize?.height` is nil on the first layout pass
1. `idealSize` is only populated after the view's layout pass runs, calculates heights, and calls `updateComponentIdealSize(height:)`.
2. Before the first layout pass completes, the view has not yet resolved preference keys (`GridIdealHeightPreferenceKey` and `SectionTitleHeightPreferenceKey`), leaving `idealSize` as `nil` on the document component model.

### Why `estimatedSingleLineAutoRowHeight × rowCount` is used as fallback, and why it causes under-allocation
1. On the first pass, `component.idealSize?.height` is `nil`, so `LeafComponentFrameSizing.intrinsicVerticalSize(for:)` falls back to `contentVerticalSize(for:)`.
2. `contentVerticalSize(for:)` uses `estimatedSingleLineAutoRowHeight(style:)` which estimates the height of a single line of text (`"Ag"`) and multiplies it by the row count.
3. This single-line estimate completely omits row borders, table border width, the section title string, and the section title bottom padding.
4. When any cell contains multi-line text (which wraps and takes more vertical space), the estimate is severely under-counted, allocating too little space for the component in the parent container.

### How `analyticGridHeight` or `effectiveGridHeight` can be calculated on the model level
1. `analyticGridHeight` requires the actual grid data. To calculate it synchronously, we can generate template placeholder data using `DocumentGridSectionDataBuilder.generateSectionData` with a default/placeholder context.
2. However, since the text wrapping height depends on layout width, a static calculation in `LeafComponentFrameSizing` (which lacks width bounds) cannot guarantee accuracy for wrapped multi-line text.
3. The correct SwiftUI layout loop is for `DocumentGridComponent` to measure its actual width, compute the analytic height, write it to `idealSize` in the document registry, and trigger a recalculation of parent splits.
4. For this recalculation loop to work, parent splits must read the updated `idealSize` from the document registry.

### How `minIntrinsicWidth` calculates the width and why the border width is missing
1. `minIntrinsicWidth` sums the column configurations (`config.width`) for all columns.
2. It does not add `style.tableBorderWidth` (outer grid borders), causing the parent container to under-allocate horizontal width by exactly the border width.

---

## 3. Caveats

- **Assumptions**: We assume that `InvoiceDocument` is available in the SwiftUI Environment for both `LinearSplitView` and `GridSplitView`, which it is as it's the root model for the editor canvas.
- **Alternative Interpretation**: One might think of calculating the full CoreText grid height statically inside `LeafComponentFrameSizing.contentVerticalSize`. However, this is suboptimal because it lacks the parent split's width bounds and data service access.

---

## 4. Conclusion

- **Bug 1 (Vertical layout undercount)** is caused by:
  1. The fallback `contentVerticalSize(for:)` ignoring borders, title text, and title padding.
  2. `LinearSplitView` and `GridSplitView` calling the non-document-aware `intrinsicSizeForChild(at:along:)`, which prevents them from reading the updated `idealSize` from the document registry after the view's layout pass updates it.
- **Bug 2 (Horizontal layout undercount)** is caused by:
  1. `minIntrinsicWidth` omitting the outer `tableBorderWidth`.

---

## 5. Verification Method

- **Files to Inspect**:
  - `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Support/LeafComponentFrameSizing.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Models/Domain/InvoiceComponent.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Canvas/LinearSplitView.swift`
  - `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Canvas/GridSplitView.swift`
- **Suggested Changes**:
  1. Update `LeafComponentFrameSizing.contentVerticalSize(for:)` to include total horizontal border height and section title height/padding.
  2. Update `InvoiceComponent.minIntrinsicWidth` to include `style.showTableBorders ? style.tableBorderWidth : 0`.
  3. Introduce `@Environment(InvoiceDocument.self) var document` in `LinearSplitView` and `GridSplitView` and pass it to `split.intrinsicSizeForChild(at:along:document:)`.
- **Test Command**:
  Execute `swift test --package-path Packages/Feature.InvoiceTemplateEditor/` to ensure no compile-time errors or layout pipeline failures.
