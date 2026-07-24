# Document Grid Layout Math Sizing Analysis

## 1. Grid Sizing & Column Width Calculation Formulas

### Input Parameters
* `columnConfigs: [ColumnWidthConfig]`: Sizing configuration for each column (`.flexible()`, `.fixed(width)`, `.autoSized()`).
* `contentColumnWidths: [Int: CGFloat]`: Dictionary mapping column indices to their maximum measured content width.
* `totalWidth: CGFloat`: Maximum width allocated for the entire table.
* `defaultAutoColumnWidth: CGFloat` (default: `20.0`): Fallback width for auto-sized columns with empty/missing content.

### Sizing Logic & Formulas (`resolvedColumnWidths`)
1. **Initial bounds check:**
   $$\text{availableWidth} = \max(\text{totalWidth}, 0)$$
   If column count is 0, returns `[]`.
2. **First Pass (Auto-sized & Fixed Columns):**
   * **Auto-sized columns:**
     $$\text{measured} = \max(\text{contentColumnWidths}[\text{index}] \text{ or } \text{defaultAutoColumnWidth}, 0)$$
     $$\text{width} = \max(\text{measured}, \text{config.fixedWidth} \text{ or } 0)$$
     Subtracts resolved width from $\text{remainingWidth}$.
   * **Fixed columns:**
     $$\text{width} = \text{config.fixedWidth}$$
     Subtracts resolved width from $\text{remainingWidth}$.
3. **Second Pass (Flexible Columns):**
   * If flexible columns exist:
     $$\text{distributableWidth} = \max(\text{remainingWidth}, 0)$$
     $$\text{perColumnWidth} = \frac{\text{distributableWidth}}{\text{flexibleColumns.count}}$$
     * For each flexible column:
       $$\text{width} = \max(\text{perColumnWidth}, \text{contentColumnWidths}[\text{index}] \text{ or } 0, \text{config.fixedWidth} \text{ or } 0)$$
4. **Third Pass (Clamping & Shrinking via `clampColumnWidths`):**
   If total resolved width exceeds target width, the excess is calculated:
   $$\text{excessWidth} = \sum(\text{widths}) - \text{targetWidth}$$
   Excess width is reclaimed sequentially across targeted column sets:
   * **Pass 3a (Flexible Columns):** Shrink flexible columns proportionally.
   * **Pass 3b (Auto-sized Columns):** Shrink auto-sized columns proportionally.
   * **Pass 3c (All Columns):** Shrink all columns (including fixed) proportionally.
   
   Proportional shrink factor calculation for a targeted set of column indices:
   $$\text{totalWidth}_{\text{set}} = \sum_{i \in \text{set}} \text{widths}[i]$$
   $$\text{shrinkAmount} = \min(\text{excessWidth}, \text{totalWidth}_{\text{set}})$$
   $$\text{shrinkFactor} = \max\left(\frac{\text{totalWidth}_{\text{set}} - \text{shrinkAmount}}{\text{totalWidth}_{\text{set}}}, 0\right)$$
   For each index in the set:
   $$\text{widths}[i] = \text{widths}[i] \times \text{shrinkFactor}$$
   $$\text{excessWidth} = \text{excessWidth} - \text{shrinkAmount}$$

---

## 2. Text Measurement Formulas

* **Method:** `measureTextSize(_ attributedString: NSAttributedString, width: CGFloat, lineLimit: Int?) -> CGSize`
* **Unconstrained/Natural Measurement:**
  If `lineLimit` is `nil` or $\le 0$, queries `CTFramesetterSuggestFrameSizeWithConstraints` with constraints `CGSize(width: targetWidth, height: .greatestFiniteMagnitude)`.
  Final width and height are rounded up:
  $$\text{size} = (\lceil\text{width}\rceil, \lceil\text{height}\rceil)$$
* **Line-Limited Measurement:**
  If `lineLimit` is specified and $> 0$:
  * Renders lines into a `CTFrame` with target width constraint.
  * Extracts lines via `CTFrameGetLines`.
  * Computes sum of typographic bounds for the first $N = \min(\text{lines.count}, \text{lineLimit})$ lines:
    $$\text{height} = \sum_{j=0}^{N-1} (\text{ascent}_j + \text{descent}_j + \text{leading}_j)$$
  * Returns:
    $$\text{size} = (\lceil\text{suggestedWidth}\rceil, \lceil\text{height}\rceil)$$

---

## 3. Row Height Calculation

* **Input Parameters:**
  * `data: [[DocumentTableItem]]`: 2D array of grid cells.
  * `style: ComponentStyle`: Style options containing font style, table padding, etc.
  * `columnWidths: [CGFloat]`: Current resolved column widths.
* **Calculation Flow:**
  * For each row index `rowIndex`:
    * If `rowConfig.isFlexible == false`, `rowConfig.isAutoSized == false`, and `rowConfig.size > 0`:
      * Row height is locked directly to:
        $$\text{height} = \text{rowConfig.size}$$
        Cell contents are *not* measured.
    * Otherwise:
      * Loops through each non-transparent cell in the row:
        $$\text{cellWidth} = \max(0, \text{columnWidths}[\text{columnIndex}] - \text{padding} \times 2)$$
        * Measures text height $\text{measuredHeight}$ at $\text{cellWidth}$.
        $$\text{cellHeight} = \text{measuredHeight} + \text{padding} \times 2$$
        $$\text{maxCellHeight} = \max(\text{maxCellHeight}, \text{cellHeight})$$
      * The final resolved row height is:
        $$\text{rowHeights}[\text{rowIndex}] = \max(\text{maxCellHeight}, \text{rowConfig.size})$$
        (Note: the row configuration size acts as a minimum height floor).

---

## 4. Grid Geometry and Border Calculations

* **Horizontal Border Height Calculation (`totalHorizontalBorderHeight`):**
  * Top boundary border: $\text{borderWidth}$ (if `showHeaderBorders` is `true`).
  * Row divider borders: $\text{borderWidth}$ for each row index $> 0$ (if `showRowBorders` is `true`).
  * Bottom boundary border: $\text{borderWidth}$ (if `showRowBorders` is `true`).
* **Total Grid Height:**
  $$\text{totalHeight} = \sum(\text{rowHeights}) + \text{totalHorizontalBorderHeight} + \text{borderAppearance.width}$$
* **Layout Geometry coordinates (`makeGridGeometry`):**
  Uses Cartesian coordinates (Y-axis points up, standard in Core Graphics):
  * Grid frame rect:
    $$\text{frame} = \text{CGRect}\left(\text{origin.x} + \frac{\text{width}_{\text{border}}}{2}, \text{origin.y} - \text{totalHeight} + \frac{\text{width}_{\text{border}}}{2}, \text{width}_{\text{content}}, \text{totalHeight} - \text{width}_{\text{border}}\right)$$
  * Row Origins: Placed sequentially starting from `frame.maxY` and going down (subtracting row heights and border offsets):
    $$\text{rowOrigin}_i = \text{y} - \text{rowHeights}[i]$$

---

## 5. Constraints and Assumptions

1. **Cartesian Coordinate Space:** Sizing coordinates assume Y grows upwards. Placing a table at `origin` draws the grid *above* `origin.y` (expanding in negative Y coordinate direction).
2. **Cell Transparency Rules:**
   * Non-visible (`isTransparent`) cells are completely ignored during auto-width and row-height measurement.
   * If a row or column consists entirely of transparent cells, borders adjacent to or surrounding it are dynamically suppressed:
     * A horizontal border is suppressed if the row above it has only transparent items.
     * Vertical borders are suppressed if the column contains only transparent items.
3. **No Minimum Boundary for Shrinking:** If the constraint on `totalWidth` is extremely severe, column widths will shrink all the way down to `0.0`. Fixed-width columns are not protected against shrinking under severe constraints; they will shrink in Pass 3.
4. **CoreText / SwiftUI Separation:** Text height calculation is strictly computed via CoreText lines. It does not account for SwiftUI's extra rendering margins or baseline offsets.

---

## 6. Existing Tests and Assertions

### Column Width Resolutions
* `testAllFlexibleColumnsNoContentWidth`: Validates even division of available space.
* `testAllFlexibleColumnsWithContentWidths`: Validates flexible column expansion rules and proportional shrinking.
* `testAllFlexibleColumnsShrink`: Assures proportional scaling under tight width boundaries.
* `testAllFixedColumnsTotalWidthFits` & `testAllFixedColumnsShrink`: Confirms fixed columns fit correctly or shrink proportionally when constraint is tight.
* `testAllFitColumnsNormal` & `testAllFitColumnsWithFallback`: Verifies content-driven width expansion and fallback to `defaultAutoColumnWidth` (20.0).
* `testMixedSizingConfigsNormal`, `testMixedSizingConfigsFlexibleShrinks`, `testMixedSizingConfigsFlexibleToZeroAndAutoShrinks`: Asserts priority-based column shrinking (Flexible first, then Auto-sized, then Fixed).
* `testEdgeCasesZeroWidth` & `testEdgeCasesComplexShrinkPriority`: Confirms correct handling of zero widths and complex priority cascades.

### Heights and Borders
* `testBorderHeightCalculations`: Verifies calculation of overall table heights (combining rows and border lines).
* `testRowHeightsFloorConstraint`: Verifies that configured row heights act as a minimum height floor.
* `testRowHeightsContentOverflow`: Verifies that row heights expand dynamically to accommodate wrapping text.
