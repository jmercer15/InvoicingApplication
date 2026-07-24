# DocumentGridLayoutMath Sizing & Layout Math Analysis

This analysis explores the math, constraints, and priorities of `DocumentGridLayoutMath` for calculating grid column widths and row heights in `InvoicingApplication`.

---

## Part 1: Layout Math Core Logic

The column width resolution logic in `DocumentGridLayoutMath.resolvedColumnWidths(...)` operates as a multi-stage allocation and clamping pipeline.

### 1. Stage 1: Initial Allocation (Fixed and Fit Columns)
The algorithm iterates through each column config:
*   **Fit (Auto-Sized)**:
    *   Gets its measured width from `contentColumnWidths[index]` (defaulting to `defaultAutoColumnWidth = 20` if missing or $\le 0$).
    *   Is clamped to `max(measuredWidth, config.fixedWidth ?? 0)`.
    *   This width is immediately subtracted from `remainingWidth`.
*   **Fixed**:
    *   Takes `fixedWidth` directly.
    *   This width is immediately subtracted from `remainingWidth`.
*   **Flexible**:
    *   Deferred to Stage 2. Its index is added to `flexibleIndices`.

### 2. Stage 2: Distributing Remaining Width to Flexible Columns
If there are any flexible columns:
*   `distributableWidth = max(remainingWidth, 0)`.
*   `perColumnWidth = distributableWidth / flexibleIndices.count`.
*   Each flexible column receives `widths[index] = max(perColumnWidth, measuredWidth, minimumWidth)`.
    *   *Note:* If a flexible column has a measured content width or minimum width that exceeds `perColumnWidth`, it takes the larger value, which can cause the sum of widths to exceed `availableWidth`.

### 3. Stage 3: Clamping/Shrinking (Proportional Reduction by Priority)
If the sum of resolved column widths exceeds the target width, `clampColumnWidths` shrinks columns proportionally using `shrinkWidths` across three priority passes:
1.  **Pass 1**: Shrink **flexible** columns only.
2.  **Pass 2**: Shrink **auto-sized (fit)** columns only.
3.  **Pass 3**: Shrink **all** columns (including fixed ones) to fit the space.

#### Proportional Shrinking Formula
For a set of indices $I$:
$$\text{totalWidth} = \sum_{i \in I} \text{widths}[i]$$
$$\text{shrinkAmount} = \min(\text{excessWidth}, \text{totalWidth})$$
$$\text{shrinkFactor} = \frac{\text{totalWidth} - \text{shrinkAmount}}{\text{totalWidth}}$$
$$\text{widths}[i] \leftarrow \text{widths}[i] \times \text{shrinkFactor}$$
$$\text{excessWidth} \leftarrow \text{excessWidth} - \text{shrinkAmount}$$

---

## Part 2: Layout Math Test Specification

### Scenario 1: All Flexible Columns
All columns configured as `.flexible()`. Excess space is split equally unless measured content widths exceed the base share.

#### Case 1a: Equal Distribution (No content widths)
*   **Inputs**:
    *   `containerWidth = 300`
    *   `columnConfigs = [.flexible(), .flexible(), .flexible()]`
    *   `contentColumnWidths = [:]`
*   **Trace**:
    1.  `remainingWidth = 300`. `flexibleIndices = [0, 1, 2]`.
    2.  `distributableWidth = 300`. `perColumnWidth = 300 / 3 = 100`.
    3.  `widths = [100, 100, 100]`.
    4.  `excessWidth = 300 - 300 = 0`. No shrinking.
*   **Expected Column Widths**: `[100.0, 100.0, 100.0]`

#### Case 1b: Non-Equal Distribution (Varying content widths)
*   **Inputs**:
    *   `containerWidth = 300`
    *   `columnConfigs = [.flexible(), .flexible(), .flexible()]`
    *   `contentColumnWidths = [0: 120, 1: 50, 2: 80]`
*   **Trace**:
    1.  `remainingWidth = 300`. `flexibleIndices = [0, 1, 2]`.
    2.  `distributableWidth = 300`. `perColumnWidth = 100`.
    3.  Initial widths:
        *   Column 0: `max(100, 120, 0) = 120`
        *   Column 1: `max(100, 50, 0) = 100`
        *   Column 2: `max(100, 80, 0) = 100`
        *   Sum = `320`.
    4.  Clamping: `excessWidth = 320 - 300 = 20`.
    5.  Pass 1 (Flexible Columns): `totalWidth = 320`. `shrinkAmount = 20`. `shrinkFactor = (320 - 20) / 320 = 0.9375`.
        *   Column 0: `120 * 0.9375 = 112.5`
        *   Column 1: `100 * 0.9375 = 93.75`
        *   Column 2: `100 * 0.9375 = 93.75`
*   **Expected Column Widths**: `[112.5, 93.75, 93.75]`

---

### Scenario 2: All Fixed Columns
All columns configured as `.fixed(width)`.

#### Case 2a: Total Width Matches Container
*   **Inputs**:
    *   `containerWidth = 300`
    *   `columnConfigs = [.fixed(100), .fixed(100), .fixed(100)]`
    *   `contentColumnWidths = [:]`
*   **Trace**:
    1.  `remainingWidth = 300 - 100 - 100 - 100 = 0`.
    2.  Initial widths: `[100, 100, 100]`.
    3.  `excessWidth = 0`. No clamping needed.
*   **Expected Column Widths**: `[100.0, 100.0, 100.0]`

#### Case 2b: Total Width Exceeds Container (Clamping/Shrinking)
*   **Inputs**:
    *   `containerWidth = 300`
    *   `columnConfigs = [.fixed(150), .fixed(100), .fixed(150)]` (total fixed = 400)
    *   `contentColumnWidths = [:]`
*   **Trace**:
    1.  Initial widths: `[150, 100, 150]`. `remainingWidth = 300 - 400 = -100`.
    2.  Clamping: `excessWidth = 400 - 300 = 100`.
    3.  Pass 1 (Flexible): `flexibleIndices` empty -> skip.
    4.  Pass 2 (AutoSized): `autoSizedIndices` empty -> skip.
    5.  Pass 3 (All Indices): `totalWidth = 400`. `shrinkAmount = 100`. `shrinkFactor = (400 - 100) / 400 = 0.75`.
        *   Column 0: `150 * 0.75 = 112.5`
        *   Column 1: `100 * 0.75 = 75.0`
        *   Column 2: `150 * 0.75 = 112.5`
*   **Expected Column Widths**: `[112.5, 75.0, 112.5]`

#### Case 2c: Total Width Less Than Container (No Stretching)
*   **Inputs**:
    *   `containerWidth = 300`
    *   `columnConfigs = [.fixed(50), .fixed(100), .fixed(50)]` (total fixed = 200)
    *   `contentColumnWidths = [:]`
*   **Trace**:
    1.  Initial widths: `[50, 100, 50]`.
    2.  `excessWidth = 200 - 300 = -100 <= 0`. No clamping.
*   **Expected Column Widths**: `[50.0, 100.0, 50.0]`

---

### Scenario 3: All Fit (AutoSized) Columns
All columns configured as `.autoSized()`.

#### Case 3a: Within Container Space
*   **Inputs**:
    *   `containerWidth = 300`
    *   `columnConfigs = [.autoSized(), .autoSized(), .autoSized()]`
    *   `contentColumnWidths = [0: 40, 1: 60, 2: 80]` (total measured = 180)
*   **Trace**:
    1.  Initial widths: `[40, 60, 80]`.
    2.  `excessWidth = 180 - 300 = -120 <= 0`. No clamping.
*   **Expected Column Widths**: `[40.0, 60.0, 80.0]`

#### Case 3b: Exceeds Container Space (Clamping/Shrinking)
*   **Inputs**:
    *   `containerWidth = 300`
    *   `columnConfigs = [.autoSized(), .autoSized(), .autoSized()]`
    *   `contentColumnWidths = [0: 100, 1: 150, 2: 150]` (total measured = 400)
*   **Trace**:
    1.  Initial widths: `[100, 150, 150]`.
    2.  Clamping: `excessWidth = 400 - 300 = 100`.
    3.  Pass 1 (Flexible): `flexibleIndices` empty -> skip.
    4.  Pass 2 (AutoSized): `autoSizedIndices = [0, 1, 2]`. `totalWidth = 400`. `shrinkAmount = 100`. `shrinkFactor = (400 - 100) / 400 = 0.75`.
        *   Column 0: `100 * 0.75 = 75.0`
        *   Column 1: `150 * 0.75 = 112.5`
        *   Column 2: `150 * 0.75 = 112.5`
*   **Expected Column Widths**: `[75.0, 112.5, 112.5]`

#### Case 3c: Missing Content Widths (Fallback to Default)
*   **Inputs**:
    *   `containerWidth = 300`
    *   `columnConfigs = [.autoSized(), .autoSized(), .autoSized()]`
    *   `contentColumnWidths = [0: 40]`
    *   `defaultAutoColumnWidth = 20`
*   **Trace**:
    1.  Column 0: measured = 40.
    2.  Column 1: missing -> defaults to `20`.
    3.  Column 2: missing -> defaults to `20`.
    4.  Initial widths: `[40, 20, 20]`. Sum = 80.
    5.  `excessWidth = 80 - 300 = -220 <= 0`. No clamping.
*   **Expected Column Widths**: `[40.0, 20.0, 20.0]`

---

### Scenario 4: Mixed Combinations (1 Fixed, 1 Fit, 1 Flexible)

#### Case 4a: Positive Remaining Space
*   **Inputs**:
    *   `containerWidth = 300`
    *   `columnConfigs = [.fixed(100), .autoSized(), .flexible()]` (0: fixed, 1: fit, 2: flexible)
    *   `contentColumnWidths = [1: 50, 2: 40]`
*   **Trace**:
    1.  Loop Stage 1:
        *   Column 0 (Fixed): `widths[0] = 100`. `remainingWidth = 200`.
        *   Column 1 (Fit): `widths[1] = 50`. `remainingWidth = 150`.
        *   Column 2 (Flexible): added to `flexibleIndices = [2]`.
    2.  Loop Stage 2:
        *   `distributableWidth = max(150, 0) = 150`.
        *   `perColumnWidth = 150 / 1 = 150`.
        *   Column 2: `max(150, 40, 0) = 150`.
    3.  Initial widths: `[100, 50, 150]`. Sum = 300.
    4.  `excessWidth = 0`. No clamping.
*   **Expected Column Widths**: `[100.0, 50.0, 150.0]`

#### Case 4b: Negative/Zero Remaining Space (Clamping Flexible and Fit)
*   **Inputs**:
    *   `containerWidth = 300`
    *   `columnConfigs = [.fixed(150), .autoSized(), .flexible()]` (0: fixed, 1: fit, 2: flexible)
    *   `contentColumnWidths = [1: 200, 2: 50]`
*   **Trace**:
    1.  Stage 1:
        *   Column 0 (Fixed): `widths[0] = 150`. `remainingWidth = 150`.
        *   Column 1 (Fit): `widths[1] = 200`. `remainingWidth = -50`.
    2.  Stage 2:
        *   `distributableWidth = max(-50, 0) = 0`.
        *   `perColumnWidth = 0`.
        *   Column 2: `max(0, 50, 0) = 50`.
    3.  Initial widths: `[150, 200, 50]`. Sum = 400.
    4.  Clamping: `excessWidth = 400 - 300 = 100`.
    5.  Pass 1 (Flexible Columns, index 2): `totalWidth = 50`. `shrinkAmount = min(100, 50) = 50`. `shrinkFactor = 0`.
        *   Column 2: `50 * 0 = 0`.
        *   `excessWidth` becomes `100 - 50 = 50`.
    6.  Pass 2 (AutoSized Columns, index 1): `totalWidth = 200`. `shrinkAmount = min(50, 200) = 50`. `shrinkFactor = (200 - 50) / 200 = 0.75`.
        *   Column 1: `200 * 0.75 = 150`.
        *   `excessWidth` becomes `50 - 50 = 0`.
    7.  Pass 3: `excessWidth = 0` -> skip.
*   **Expected Column Widths**: `[150.0, 150.0, 0.0]`

#### Case 4c: Fixed Alone Exceeds Space (Shrinking All Columns)
*   **Inputs**:
    *   `containerWidth = 300`
    *   `columnConfigs = [.fixed(400), .autoSized(), .flexible()]`
    *   `contentColumnWidths = [1: 50, 2: 50]`
*   **Trace**:
    1.  Stage 1:
        *   Column 0: `widths[0] = 400`. `remainingWidth = -100`.
        *   Column 1: `widths[1] = 50`. `remainingWidth = -150`.
    2.  Stage 2:
        *   Column 2: `max(0, 50, 0) = 50`.
    3.  Initial widths: `[400, 50, 50]`. Sum = 500.
    4.  Clamping: `excessWidth = 200`.
    5.  Pass 1 (Flexible): Column 2 shrunk to `0`. `excessWidth` becomes `150`.
    6.  Pass 2 (AutoSized): Column 1 shrunk to `0`. `excessWidth` becomes `100`.
    7.  Pass 3 (All): `totalWidth = 400 + 0 + 0 = 400`. `shrinkAmount = min(100, 400) = 100`. `shrinkFactor = (400 - 100) / 400 = 0.75`.
        *   Column 0: `400 * 0.75 = 300`.
        *   Column 1: `0 * 0.75 = 0`.
        *   Column 2: `0 * 0.75 = 0`.
*   **Expected Column Widths**: `[300.0, 0.0, 0.0]`

---

### Scenario 5: Edge Cases

#### Case 5a: Zero/Negative Available Width
*   **Inputs**:
    *   `containerWidth = 0` (or `containerWidth = -50`)
    *   `columnConfigs = [.fixed(100), .autoSized(), .flexible()]`
    *   `contentColumnWidths = [1: 50, 2: 50]`
*   **Trace**:
    1.  `availableWidth = max(0, 0) = 0` (or `max(-50, 0) = 0`).
    2.  Inside `clampColumnWidths`: `guard targetWidth > 0 else { return Array(repeating: 0, count: widths.count) }`
    3.  `targetWidth = 0`, returns `[0, 0, 0]`.
*   **Expected Column Widths**: `[0.0, 0.0, 0.0]`

#### Case 5b: Zero Column Count
*   **Inputs**:
    *   `containerWidth = 300`
    *   `columnConfigs = []`
    *   `contentColumnWidths = [:]`
*   **Trace**:
    1.  `guard columnCount > 0 else { return [] }`
*   **Expected Column Widths**: `[]`

#### Case 5c: Fit Columns Larger Than Space
*   *Note: This is equivalent to Case 3b, where auto-sized columns are shrunk proportionally.*

---

## Part 3: Expected Heights Calculations

Expected grid heights are calculated using:
*   `resolvedRowHeights(data, style, columnWidths)`
*   `heightFromRowHeights(rowHeights, borderAppearance)`

### 1. Border Height Calculation Formula (`totalHorizontalBorderHeight`)
*   If `rowCount > 0`:
    *   If `showHeaderBorders = true`: `+borderWidth`
    *   If `showRowBorders = true`: `+(rowCount - 1) * borderWidth`
    *   If `showRowBorders = true` (at the bottom): `+borderWidth`
*   Total vertical border additions = `borderHeight + borderWidth`

### 2. Height Test Scenario 1 (All Toggles On)
*   **Inputs**:
    *   `rowHeights = [30.0, 40.0]` (Header row, Data row)
    *   `borderAppearance.width = 2.0`
    *   `borderAppearance.showHeaderBorders = true`
    *   `borderAppearance.showRowBorders = true`
*   **Trace**:
    1.  `totalRowHeight = 30 + 40 = 70`.
    2.  `borderHeight`:
        *   Row 0: `showHeaderBorders = true` -> `+2`
        *   Row 1: `showRowBorders = true` -> `+2`
        *   Bottom: `showRowBorders = true` -> `+2`
        *   Total `borderHeight = 6`.
    3.  `totalHeight = totalRowHeight + borderHeight + borderAppearance.width = 70 + 6 + 2 = 78`.
*   **Expected Height**: `78.0`

### 3. Height Test Scenario 2 (Header Toggled Off)
*   **Inputs**:
    *   `rowHeights = [30.0, 40.0]`
    *   `borderAppearance.width = 2.0`
    *   `borderAppearance.showHeaderBorders = false`
    *   `borderAppearance.showRowBorders = true`
*   **Trace**:
    1.  `totalRowHeight = 70`.
    2.  `borderHeight`:
        *   Row 0: `showHeaderBorders = false` -> `+0`
        *   Row 1: `showRowBorders = true` -> `+2`
        *   Bottom: `showRowBorders = true` -> `+2`
        *   Total `borderHeight = 4`.
    3.  `totalHeight = totalRowHeight + borderHeight + borderAppearance.width = 70 + 4 + 2 = 76`.
*   **Expected Height**: `76.0`

### 4. Height Test Scenario 3 (All Borders Toggled Off)
*   **Inputs**:
    *   `rowHeights = [30.0, 40.0]`
    *   `borderAppearance.width = 2.0`
    *   `borderAppearance.showHeaderBorders = false`
    *   `borderAppearance.showRowBorders = false`
*   **Trace**:
    1.  `totalRowHeight = 70`.
    2.  `borderHeight`:
        *   Row 0: `+0`
        *   Row 1: `+0`
        *   Bottom: `+0`
        *   Total `borderHeight = 0`.
    3.  `totalHeight = totalRowHeight + borderHeight + borderAppearance.width = 70 + 0 + 2 = 72`.
*   **Expected Height**: `72.0`
