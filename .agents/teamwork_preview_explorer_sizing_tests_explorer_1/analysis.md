# Analysis Report: DocumentGridLayoutMath Sizing Modes & Math Implementation

## 1. Overview
`DocumentGridLayoutMath` is a pure mathematical layout utility designed to calculate column widths, row heights, and layout geometry (cell frames, borders) for document-based tabular structures. It ensures exact parity between the interactive SwiftUI-based editor view (`DocumentGridView`) and the PDF/Core Graphics rendering pipeline.

---

## 2. Axis Sizing Modes & Mathematical Calculation

### A. Column Sizing Modes and Width Calculation
Column widths are computed via the `resolvedColumnWidths` function:
```swift
static func resolvedColumnWidths(
    columnConfigs: [ColumnWidthConfig],
    contentColumnWidths: [Int: CGFloat],
    totalWidth: CGFloat,
    defaultAutoColumnWidth: CGFloat = DocumentGridLayoutMath.defaultAutoColumnWidth
) -> [CGFloat]
```

#### 1. Column Sizing Modes Definition
- **Fixed Mode**: Defined by setting an explicit width (e.g., `.fixed(80)`). The config stores `fixedWidth` as a `CGFloat` (and `isFlexible = false`, `isAutoSized = false`).
- **Fit (AutoSized) Mode**: The width dynamically adjusts based on the measured content within the column. The config stores `isAutoSized = true`.
- **Flexible Mode**: The column grows to fill the remaining width. The config stores `isFlexible = true`.

#### 2. Allocation & Resolution Logic (Two-Pass Math)
The function allocates widths from the `totalWidth` (clamped to a minimum of `0` via `availableWidth = max(totalWidth, 0)`) in two distinct phases:

##### Pass 1: Fixed and Fit (AutoSized) Allocation
For each column index $i \in [0, N-1]$:
* **Fit (AutoSized)**:
  1. Retrieve content width: $W_{measured} = \text{contentColumnWidths}[i]$ (if nil or $\le 0$, fall back to `defaultAutoColumnWidth` which is $20.0$).
  2. The initial allocation is:
     $$w_i = \max(W_{measured}, \text{config}_i.\text{fixedWidth} \mathbin{?} 0)$$
  3. Deduct from remaining width: $W_{remaining} \leftarrow W_{remaining} - w_i$.
* **Fixed**:
  1. Allocate explicit width: $w_i = \text{config}_i.\text{fixedWidth}$.
  2. Deduct from remaining width: $W_{remaining} \leftarrow W_{remaining} - w_i$.
* **Flexible**:
  * Defer allocation. Track indices in `flexibleIndices`.

##### Pass 2: Distributing Remaining Width to Flexible Columns
If `flexibleIndices` is not empty:
1. Let $W_{distributable} = \max(W_{remaining}, 0)$.
2. Calculate width per flexible column:
   $$W_{per\_col} = \frac{W_{distributable}}{|\text{flexibleIndices}|}$$
3. For each $j \in \text{flexibleIndices}$, calculate:
   $$w_j = \max(W_{per\_col}, W_{measured, j}, \text{config}_j.\text{fixedWidth} \mathbin{?} 0)$$

#### 3. Proportional Clamping & Shrinking Logic
If the sum of resolved column widths $\sum w_i$ exceeds the `availableWidth`, the excess width $E = \sum w_i - \text{availableWidth}$ must be reduced.
This is performed in `clampColumnWidths` which calls the `shrinkWidths` function in three priority levels sequentially:
1. **Priority 1**: Shrink only `flexibleIndices`.
2. **Priority 2**: Shrink only `autoSizedIndices`.
3. **Priority 3**: Shrink all columns (Priority 3 serves as a hard safety clamp and affects Fixed columns if previous steps fail to resolve the overflow).

##### Proportional Shrink Math Formula
Let $I$ be the set of column indices selected for shrinking (e.g., flexible indices), and $W_I = \sum_{k \in I} w_k$ be their combined width.
1. The amount to shrink from this group is:
   $$S = \min(E, W_I)$$
2. If $W_I > 0$, the shrink scaling factor is:
   $$F = \max\left(\frac{W_I - S}{W_I}, 0\right)$$
3. Each column $k \in I$ is scaled:
   $$w_k \leftarrow w_k \times F$$
4. Update the remaining excess width:
   $$E \leftarrow E - S$$

---

### B. Row Sizing Modes and Height Calculation
Row heights are calculated via `resolvedRowHeights`:
```swift
static func resolvedRowHeights(
    data: [[DocumentTableItem]],
    style: ComponentStyle,
    columnWidths: [CGFloat]
) -> [CGFloat]
```

#### 1. Row Sizing Modes
- **Fixed Mode**: Defined by `rowConfig.isFlexible == false`, `rowConfig.isAutoSized == false`, and `rowConfig.size > 0`.
- **Fit / AutoSized / Flexible Mode**: Dynamic row height calculated based on content.

#### 2. Height Evaluation Logic
For each row $r$:
* **Fixed Row**: The height is set directly to the configured size:
  $$h_r = \text{rowConfig}_r.\text{size}$$
* **Fit / Dynamic Row**:
  For each non-transparent item/cell $c$ in column $c_{idx}$ in row $r$:
  1. Determine cell padding:
     $$\text{padding} = \text{cellOverride}_c.\text{padding} \mathbin{?} (\text{isHeader} \mathbin{?} \text{style}.\text{tableHeaderPadding} : \text{style}.\text{tableCellPadding})$$
  2. Compute constrained text container width:
     $$W_{cell} = \max(0, w_{c_{idx}} - \text{padding} \times 2)$$
  3. Measure the text bounds $H_{text}$ using CoreText with the width constraint $W_{cell}$ and the cell's `lineLimit`.
  4. Cell height:
     $$h_{cell} = H_{text} + \text{padding} \times 2$$
  5. The final row height is the maximum height among all cells in the row, floor-capped by the row configuration size:
     $$h_r = \max\left( \max_{c \in \text{row } r}(h_{cell, c}), \text{rowConfig}_r.\text{size} \right)$$

---

### C. Text Measurement Calculation
CoreText measurement logic in `measureTextSize`:
```swift
static func measureTextSize(
    _ attributedString: NSAttributedString,
    width: CGFloat,
    lineLimit: Int?
) -> CGSize
```
1. Compute the frame size constraint:
   $$W_{target} = \begin{cases} \text{width} & \text{if width is finite and } > 0 \\ \infty & \text{otherwise} \end{cases}$$
2. Call `CTFramesetterSuggestFrameSizeWithConstraints` for the full height.
3. If `lineLimit` is specified and $>0$:
   - Create a `CTFrame` within the bounding box.
   - For each line $l \in [0, \min(\text{lines.count}, \text{lineLimit}) - 1]$, query typographic bounds (ascent, descent, leading):
     $$H_{line} = \text{ascent} + \text{descent} + \text{leading}$$
   - Return the summed line heights:
     $$H_{total} = \sum H_{line}$$

---

### D. Grid Geometry and Borders Math
`makeGridGeometry` determines the spatial structure of the table:
```swift
static func makeGridGeometry(
    origin: CGPoint,
    width: CGFloat,
    columnWidths: [CGFloat],
    rowHeights: [CGFloat],
    borderAppearance: TableBorderAppearance
) -> GridGeometry
```
* **Overall Table Frame**:
  - Width: $W_{frame} = \max(0, \text{width} - \text{borderWidth})$
  - Border height: Calculated based on horizontal lines (header/row borders count).
  - Height: $H_{frame} = \sum h_r + H_{borders} + \text{borderWidth}$
  - Frame: `CGRect(x: origin.x + borderWidth/2, y: origin.y - H_frame + borderWidth/2, width: W_frame, height: H_frame - borderWidth)`
* **Origins**:
  - Columns layout sequentially from left to right: $x_{i+1} = x_i + w_i$.
  - Rows layout from top to bottom relative to coordinate space:
    $$y_i = y_{prev} - \text{borderWidth}_{row} - h_r$$

---

## 3. Recommended Unit-Testing Strategy

### A. Core Testing Areas & Objectives
To ensure mathematical correctness and regression safety, the test suite should target:
1. **Column Resolution Boundary Conditions**: Column allocation behavior at zero width, small limits, and large dimensions.
2. **Proportional Shrinking Precision**: Asserting that excess width reduction splits the burden proportionally.
3. **CoreText Typography Parity**: Verifying `measureTextSize` behavior under different padding values, line limits, and text wrap states.
4. **Layout under Empty states**: Testing layout behavior when `data` rows are empty or all cells are transparent.

### B. High-Value Test Cases

| Test Case | Input Parameters | Expected Verification / Logic |
|---|---|---|
| **Zero/Negative Width Clamp** | `totalWidth: -50.0`, configs with fixed/flexible mix | Returns array of `[0.0, 0.0, ...]` and does not crash or loop. |
| **Exact Proportional Shrinking** | `totalWidth: 100`, configs: `[.flexible(), .flexible()]` each requiring 100 via content widths | Verify both scale down exactly to `50.0` (factor of 0.5). |
| **Hierarchical Shrinking Order** | `totalWidth: 100`, configs: `[.fixed(60), .autoSized(), .flexible()]` where raw widths are 60, 40, 50 (sum = 150) | Flexible shrinks first to 0. Remaining excess (10) is taken from autoSized (goes from 40 to 30). Fixed stays 60. Final widths: `[60, 30, 0]`. |
| **Grid Geometry Calculation** | Origin: `(10, 100)`, width: `200`, columns: `[80, 120]`, rows: `[30, 40]`, borders: `1.0` | Verify frame dimensions, `columnOrigins` at `[10.5, 90.5]`, and rowOrigins matching spacing constraints. |
| **Multiline Wrap vs Single Line height** | Multi-line NSAttributedString, restricted column width | Assert row heights with lineLimit `nil`/`6` are taller than lineLimit `1`. |
| **Transparent Columns/Rows** | Row with all cell items marked `isTransparent = true` | Verify that border lines are not drawn for empty rows/columns (using `horizontalBorderLines` and `verticalBorderLines`). |

---

## 4. Retrospective & Synthesis

- **Consensus**: The logic splits sizing cleanly across column width pass-through allocations, a priority-based proportional shrinking scheme, and CoreText-based row-height wrapping calculations.
- **Safety Concern**: The CoreText measurement loops depend heavily on line bounds. If fonts return zero leading, layout heights could underestimate actual bounds. Tests should use standard fonts (like System, Helvetica) to verify calculations.
- **Gaps Covered**: Multi-column spanning cells (`columnSpan > 1`) do not contribute to `measureColumnContentWidths` dynamically. Test cases should verify that content widths for spanned columns are modeled correctly.
