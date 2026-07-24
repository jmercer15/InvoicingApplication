## 2026-06-29T13:41:35Z
You are Worker-Add-Sizing-Tests.
Your working directory is `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_add_sizing_tests_1`.

### Objective
Please add the following additional test cases to `DocumentGridLayoutMathTests.swift` (`/Users/user/Developer/InvoicingApplication/InvoicingApplication/Packages/Feature.InvoiceTemplateEditor/Tests/Feature_InvoiceTemplateEditorTests/DocumentGridLayoutMathTests.swift`) to close the gaps identified by the Challenger analysis:

1. Fixed Columns Ignore Content Widths:
```swift
func testFixedColumnsIgnoreContentWidths() {
    let configs: [ColumnWidthConfig] = [.fixed(100.0)]
    let contentWidths: [Int: CGFloat] = [0: 250.0]
    let widths = DocumentGridLayoutMath.resolvedColumnWidths(
        columnConfigs: configs,
        contentColumnWidths: contentWidths,
        totalWidth: 300.0
    )
    XCTAssertEqual(widths, [100.0], "Fixed columns must not resize based on content widths")
}
```

2. Proportional Category Shrinking in Mixed Layouts:
```swift
func testMixedConfigsProportionalCategoryShrink() {
    let configs: [ColumnWidthConfig] = [.fixed(100.0), .autoSized(), .autoSized()]
    let contentWidths: [Int: CGFloat] = [1: 100.0, 2: 200.0]
    let widths = DocumentGridLayoutMath.resolvedColumnWidths(
        columnConfigs: configs,
        contentColumnWidths: contentWidths,
        totalWidth: 250.0
    )
    XCTAssertEqual(widths, [100.0, 50.0, 100.0], "AutoSized columns must shrink proportionally relative to each other")
}
```

3. Text Measurement with Line Limit Constraints:
```swift
func testMeasureTextWithLineLimits() {
    let longText = "Line 1\nLine 2\nLine 3\nLine 4"
    let style = ComponentStyle()
    let text1 = style.cellTextNSAttributedString(for: longText, isHeader: false)
    let height1 = DocumentGridLayoutMath.measureTextSize(text1, width: 200.0, lineLimit: 1).height
    let height2 = DocumentGridLayoutMath.measureTextSize(text1, width: 200.0, lineLimit: 2).height
    let heightUnlimited = DocumentGridLayoutMath.measureTextSize(text1, width: 200.0, lineLimit: nil).height
    XCTAssertLessThan(height1, height2)
    XCTAssertLessThan(height2, heightUnlimited)
}
```

4. Fixed Row Height Sizing Mode under Overflow:
```swift
func testRowHeightsFixedModeDoesNotOverflow() {
    var style = ComponentStyle()
    style.tableCellPadding = 5.0
    var colConfig = ComponentStyle.ColumnConfiguration(size: 300.0)
    colConfig.lineLimit = 1
    style.columnConfigurations[0] = colConfig
    var rowConfig = ComponentStyle.RowConfiguration(size: 40.0)
    rowConfig.sizingMode = .fixed
    style.rowConfigurations[0] = rowConfig
    let text = "Long overflowing text..."
    let item = DocumentTableItem(content: text, isHeader: false, rowIndex: 0, columnIndex: 0)
    let resolved = DocumentGridLayoutMath.resolvedRowHeights(
        data: [[item]],
        style: style,
        columnWidths: [300.0]
    )
    XCTAssertEqual(resolved.count, 1)
    XCTAssertEqual(resolved[0], 40.0, "Fixed row height must not expand even if content overflows")
}
```

5. Vertical Border Lines Generation:
```swift
func testVerticalBorderLinesNormalAndCellToggles() {
    let data: [[DocumentTableItem]] = [
        [DocumentTableItem(content: "A", rowIndex: 0, columnIndex: 0),
         DocumentTableItem(content: "B", rowIndex: 0, columnIndex: 1)]
    ]
    let geometry = DocumentGridLayoutMath.makeGridGeometry(
        origin: .zero,
        width: 200.0,
        columnWidths: [100.0, 100.0],
        rowHeights: [30.0],
        borderAppearance: TableBorderAppearance(width: 1)
    )
    let appearanceWithCells = TableBorderAppearance(width: 1.0, showCellBorders: true)
    let linesWithCells = DocumentGridLayoutMath.verticalBorderLines(
        geometry: geometry,
        data: data,
        borderAppearance: appearanceWithCells
    )
    XCTAssertEqual(linesWithCells.count, 3)
    let appearanceNoCells = TableBorderAppearance(width: 1.0, showCellBorders: false)
    let linesNoCells = DocumentGridLayoutMath.verticalBorderLines(
        geometry: geometry,
        data: data,
        borderAppearance: appearanceNoCells
    )
    XCTAssertEqual(linesNoCells.count, 2)
}
```

6. Border Elimination for Transparent Content:
```swift
func testBordersWithTransparentRowsAndColumns() {
    let data: [[DocumentTableItem]] = [
        [DocumentTableItem(content: "A", rowIndex: 0, columnIndex: 0),
         DocumentTableItem(content: "B", rowIndex: 0, columnIndex: 1, isTransparent: true)],
        [DocumentTableItem(content: "C", rowIndex: 1, columnIndex: 0, isTransparent: true),
         DocumentTableItem(content: "D", rowIndex: 1, columnIndex: 1, isTransparent: true)]
    ]
    let geometry = DocumentGridLayoutMath.makeGridGeometry(
        origin: .zero,
        width: 200.0,
        columnWidths: [100.0, 100.0],
        rowHeights: [30.0, 30.0],
        borderAppearance: TableBorderAppearance(width: 1)
    )
    let borderAppearance = TableBorderAppearance(width: 1.0, showHeaderBorders: true, showRowBorders: true, showCellBorders: true)
    let horizontalLines = DocumentGridLayoutMath.horizontalBorderLines(
        geometry: geometry,
        data: data,
        borderAppearance: borderAppearance
    )
    let verticalLines = DocumentGridLayoutMath.verticalBorderLines(
        geometry: geometry,
        data: data,
        borderAppearance: borderAppearance
    )
    XCTAssertEqual(horizontalLines.count, 2)
    XCTAssertEqual(verticalLines.count, 1)
    XCTAssertEqual(verticalLines[0].rect.origin.x, geometry.columnOrigins[0])
}
```

7. Total Width Extremes (NaN/Negatives):
```swift
func testTotalWidthExtremes() {
    let configs: [ColumnWidthConfig] = [.fixed(100), .flexible()]
    let nanWidths = DocumentGridLayoutMath.resolvedColumnWidths(
        columnConfigs: configs,
        contentColumnWidths: [:],
        totalWidth: .nan
    )
    XCTAssertEqual(nanWidths, [0.0, 0.0])
    let negativeWidths = DocumentGridLayoutMath.resolvedColumnWidths(
        columnConfigs: configs,
        contentColumnWidths: [:],
        totalWidth: -100.0
    )
    XCTAssertEqual(negativeWidths, [0.0, 0.0])
}
```

8. Content Width Extremes (NaN):
```swift
func testContentWidthExtremes() {
    let configs: [ColumnWidthConfig] = [.autoSized(), .flexible()]
    let contentWidthsNaN: [Int: CGFloat] = [0: .nan]
    let resolvedNaN = DocumentGridLayoutMath.resolvedColumnWidths(
        columnConfigs: configs,
        contentColumnWidths: contentWidthsNaN,
        totalWidth: 100.0
    )
    XCTAssertEqual(resolvedNaN[0], 20.0)
}
```

### Execution Rules
- Run `swift test --package-path Packages/Feature.InvoiceTemplateEditor` to verify that everything compiles and passes.
- If any of the new tests fail due to production limits, adjust the assertion of that specific test to match current behavior (so the tests pass), and document it clearly in your handoff report.
- Write your handoff report to `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_add_sizing_tests_1/handoff.md`.
