# Test Quality & Coverage Challenge: Layout Math

## 1. Executive Summary
This analysis evaluates `DocumentGridLayoutMathTests.swift` against the functional requirements of the document grid layout math system. While the existing test suite successfully covers basic column sizing configurations, layout math reconciliation, and row height constraints, significant gaps remain in testing multi-type proportional shrinks, edge/nan bounds, fixed row height behavior under overflow, text wrapping with line limits, and the entirety of vertical/horizontal border line generation (especially regarding transparency logic).

---

## 2. Requirement-by-Requirement Coverage Analysis

### 2.1. All Flexible Columns
* **Current Coverage:**
  - `testAllFlexibleColumnsNoContentWidth`: Verifies uniform distribution when no content width is present.
  - `testAllFlexibleColumnsWithContentWidths`: Verifies proportional distribution when content widths are specified.
  - `testAllFlexibleColumnsShrink`: Verifies proportional shrinking under constraints.
* **Assessment:** Good basic coverage.
* **Gaps:**
  - **Single Flexible Column:** No test verifying a single flexible column taking 100% of remaining width.
  - **Zero / Negative Container Width:** Behavior of flexible columns when total width is zero or negative is not explicitly tested (handled in edge cases with mixed configurations, but not isolated).

### 2.2. All Fixed Columns
* **Current Coverage:**
  - `testAllFixedColumnsTotalWidthFits`: Verifies behavior when sum < totalWidth.
  - `testAllFixedColumnsShrink`: Verifies behavior when sum > totalWidth.
* **Assessment:** Covers basic fitting and shrinking.
* **Gaps:**
  - **Content Width Independence:** No test verifies that fixed columns *ignore* content widths. If a fixed column is set to 100 and its measured content width is 200, it must remain 100.
  - **Zero / Negative Configured Width:** No test for fixed columns configured with 0 or negative width.

### 2.3. All Fit (Auto-Sized) Columns
* **Current Coverage:**
  - `testAllFitColumnsNormal`: Verifies sizing to content widths.
  - `testAllFitColumnsWithFallback`: Verifies fallback to `defaultAutoColumnWidth` (20.0pt) when content widths are 0 or missing.
  - `testAllFitColumnsShrink`: Verifies proportional shrinking.
* **Assessment:** Basic auto-sizing and fallback mechanisms are covered.
* **Gaps:**
  - **Global Fallback:** No test verifies that when `contentColumnWidths` is completely empty `[:]`, all auto-sized columns resolve to `defaultAutoColumnWidth`.
  - **Imbalanced Proportional Shrink:** No test verifying how multiple auto-sized columns shrink when one is very large and another is at/near the fallback minimum.

### 2.4. Mixed Sizing Combinations & Interactions
* **Current Coverage:**
  - `testMixedSizingConfigsNormal`: One fixed, one auto, one flexible.
  - `testMixedSizingConfigsFlexibleShrinks`: Flexible column shrinks to accommodate fixed and auto.
  - `testMixedSizingConfigsFlexibleToZeroAndAutoShrinks`: Flexible shrinks to 0, then auto-sized shrinks.
  - `testEdgeCasesComplexShrinkPriority`: Fixed + Auto + Flexible with tiny container (80pt). Flexible and Auto shrink to 0, Fixed shrinks to 80.
* **Assessment:** The priority cascade (Flexible -> Auto -> Fixed) is well-tested.
* **Gaps:**
  - **Intra-Category Proportional Shrinking:** No test with multiple columns of the *same* category shrinking in a mixed layout (e.g., 2 flexible columns shrinking proportionally, or 2 auto-sized columns shrinking proportionally, while fixed columns remain untouched).
  - **Flexible Excess Distribution:** No test verifying distribution of remaining width when there are multiple flexible columns with differing content widths (e.g., how the `perColumnWidth` average interacts with larger content widths).

### 2.5. Edge Cases
* **Current Coverage:**
  - `testEdgeCasesZeroWidth`: Verifies totalWidth = 0 returns all zeros.
  - `testEdgeCasesEmptyConfigs`: Empty configs return empty array.
  - `testEdgeCasesAllFixedShrink`: Proportional fixed shrink.
  - `testEdgeCasesComplexShrinkPriority`: Clamping behavior under extreme constraint.
* **Assessment:** Basic edge cases are well handled.
* **Gaps:**
  - **Negative Widths:** Negative container width is not tested (should clamp to 0).
  - **NaN / Infinity Inputs:** No tests for `CGFloat.nan` or `CGFloat.infinity` in `contentColumnWidths` or `totalWidth`.
  - **Extremely Constrained Space:** Testing behavior of multiple columns in a 1pt container (verifying they all shrink to 0 or positive fractions without division by zero or NaN).

### 2.6. Row/Border Layout Logic
* **Current Coverage:**
  - `testBorderHeightCalculations`: Verifies basic height summation with header and row borders active.
  - `testRowHeightsFloorConstraint`: Verifies row heights are floored by the configured minimum row size.
  - `testRowHeightsContentOverflow`: Verifies row heights wrap and expand.
* **Assessment:** Covers basic vertical calculation.
* **Gaps (Critical):**
  - **Untested `verticalBorderLines` Function:** The entire vertical border lines generation function (`DocumentGridLayoutMath.verticalBorderLines`) is completely untested.
  - **Transparency / Hidden Content Logic:** The logic that prevents drawing borders for transparent rows or columns (`rowHasVisibleContent`, `isRowAboveContentEmpty`, `columnHasVisibleContent`) is completely untested.
  - **Fixed Row Height Sizing Mode:** No test verifies that if `rowConfig.sizingMode = .fixed`, the row height remains fixed at `rowConfig.size` even if content height wraps and overflows.
  - **Line Limit Constraints:** Text measurement testing does not verify how `lineLimit` constraints affect height (e.g., comparing `lineLimit = nil` (multiline) vs `lineLimit = 1` (truncated) vs `lineLimit = 2`).
  - **Varying Border Appearances:** Only one combination of `showHeaderBorders` and `showRowBorders` is tested. The combinatorial space for border toggling is untested.

---

## 3. Combinatorial Space Coverage Verification

The mathematical grid system has a large combinatorial space:
`[Sizing Mode Combo] × [Constraint Combo] × [Border Combo] × [Content Transparency]`

The test suite does not cover this space thoroughly. Specifically:
1. **Sizing Mode Interactions:**
   - Evaluated: `[Fixed, Auto, Flexible]`
   - Missing: Proportional behaviors of `[Flexible, Flexible]` and `[Auto, Auto]` under mixed constraints.
2. **Constraint Combinations:**
   - Evaluated: Fitting, moderate shrink, extreme shrink.
   - Missing: Negative bounds, NaN/infinity bounds.
3. **Border Combinations:**
   - Evaluated: `[showHeaderBorders: true, showRowBorders: true]`
   - Missing: `[showHeaderBorders: false, showRowBorders: true]`, `[showHeaderBorders: true, showRowBorders: false]`, `[showHeaderBorders: false, showRowBorders: false]`, and cell borders toggled.
4. **Content Transparency:**
   - Evaluated: All visible.
   - Missing: Empty rows, empty columns, and alternating empty cells.

---

## 4. Recommended Test Additions (Code Snippets)

The following test cases should be added to `DocumentGridLayoutMathTests.swift` to achieve complete coverage:

```swift
// MARK: - Recommended Additions for DocumentGridLayoutMathTests

// 1. Verify that fixed columns ignore content widths
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

// 2. Verify proportional shrinking within category in mixed layouts
func testMixedConfigsProportionalCategoryShrink() {
    // 1 fixed (100), 2 autoSized (100, 200), total = 250
    let configs: [ColumnWidthConfig] = [.fixed(100.0), .autoSized(), .autoSized()]
    let contentWidths: [Int: CGFloat] = [1: 100.0, 2: 200.0]
    let widths = DocumentGridLayoutMath.resolvedColumnWidths(
        columnConfigs: configs,
        contentColumnWidths: contentWidths,
        totalWidth: 250.0
    )
    // Fixed stays at 100. Auto-sized must shrink from total of 300 to 150.
    // Shrink factor = 150 / 300 = 0.5.
    // Resolved autoSized widths: 100 * 0.5 = 50, 200 * 0.5 = 100.
    XCTAssertEqual(widths, [100.0, 50.0, 100.0], "AutoSized columns must shrink proportionally relative to each other")
}

// 3. Verify text wrapping with lineLimit constraints
func testMeasureTextWithLineLimits() {
    let longText = "Line 1\nLine 2\nLine 3\nLine 4"
    let style = ComponentStyle()
    
    let text1 = style.cellTextNSAttributedString(for: longText, isHeader: false)
    
    // Capped at 1 line
    let height1 = DocumentGridLayoutMath.measureTextSize(text1, width: 200.0, lineLimit: 1).height
    // Capped at 2 lines
    let height2 = DocumentGridLayoutMath.measureTextSize(text1, width: 200.0, lineLimit: 2).height
    // Unlimited lines
    let heightUnlimited = DocumentGridLayoutMath.measureTextSize(text1, width: 200.0, lineLimit: nil).height
    
    XCTAssertLessThan(height1, height2)
    XCTAssertLessThan(height2, heightUnlimited)
}

// 4. Verify fixed row height sizing mode under overflow
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

// 5. Verify vertical border lines generation
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
    
    // Test with cell borders ON
    let appearanceWithCells = TableBorderAppearance(width: 1.0, showCellBorders: true)
    let linesWithCells = DocumentGridLayoutMath.verticalBorderLines(
        geometry: geometry,
        data: data,
        borderAppearance: appearanceWithCells
    )
    // Expect 3 borders: leading of col 0 (x=0), inner (x=100), trailing of col 1 (x=199)
    XCTAssertEqual(linesWithCells.count, 3)
    
    // Test with cell borders OFF
    let appearanceNoCells = TableBorderAppearance(width: 1.0, showCellBorders: false)
    let linesNoCells = DocumentGridLayoutMath.verticalBorderLines(
        geometry: geometry,
        data: data,
        borderAppearance: appearanceNoCells
    )
    // Expect 2 borders: leading of col 0 (x=0), trailing of col 1 (x=199)
    XCTAssertEqual(linesNoCells.count, 2)
}

// 6. Verify border elimination logic for transparent content
func testBordersWithTransparentRowsAndColumns() {
    // Row 1 is transparent, Column 1 is transparent
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
    
    // Horizontal lines check:
    // Row 0 has content -> top border (header border) is drawn.
    // Row 1 is transparent -> row border between Row 0 and Row 1 is drawn (since row above has content).
    // Bottom row (Row 1) is empty -> bottom border is NOT drawn.
    XCTAssertEqual(horizontalLines.count, 2)
    
    // Vertical lines check:
    // Column 0 has content -> leading border drawn (x=0).
    // Column 1 is transparent -> trailing border NOT drawn (x=199) and inner border NOT drawn (x=100) since column 1 lacks content.
    XCTAssertEqual(verticalLines.count, 1)
    XCTAssertEqual(verticalLines[0].rect.origin.x, geometry.columnOrigins[0])
}
```
