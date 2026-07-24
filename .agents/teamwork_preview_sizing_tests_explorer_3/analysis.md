# Document Grid Layout Math Test Specification Analysis

## Summary of Findings
`DocumentGridLayoutMath` implements a multi-stage deterministic layout engine that resolves column widths and row heights for document grid tables. Column width resolution follows a priority-based shrink strategy (first shrinking flexible columns, then auto-sized/fit columns, and finally all columns) when initial widths exceed target container width.

---

## Code References

| Entity | File Path | Line Range | Description |
| :--- | :--- | :--- | :--- |
| `resolvedColumnWidths(...)` | `DocumentGridLayoutMath.swift` | 28–78 | Primary entry point for calculating final column widths based on configurations, content widths, and container bounds. |
| `clampColumnWidths(...)` | `DocumentGridLayoutMath.swift` | 80–97 | Clamping router that determines if the total width exceeds targets and coordinates the sequential shrinking phases. |
| `shrinkWidths(...)` | `DocumentGridLayoutMath.swift` | 99–120 | Scale-factor-based shrink function that proportionally reduces widths of specified column indices. |
| `resolvedRowHeights(...)` | `DocumentGridLayoutMath.swift` | 198–238 | Resolves row heights, enforcing configured size floors for flexible/auto rows, and content-height wrapping for text cells. |
| `totalHorizontalBorderHeight(...)` | `DocumentGridLayout+Preferences.swift` | 199–225 | Border height accumulation based on row counts, border widths, and layout visibility toggles. |
| `heightFromRowHeights(...)` | `DocumentGridLayout+Preferences.swift` | 183–197 | Combines row heights and accumulated borders to calculate complete layout math height. |

---

## Test Specification & Mathematical Tracing

### Part A: Column Sizing Scenarios (`resolvedColumnWidths`)

#### Case 1: All Flexible Columns (`TableSizingMode.flexible`)

*   **Scenario 1.1: Standard distribution with no content width**
    *   **Inputs**:
        *   `columnConfigs`: `[.flexible(), .flexible(), .flexible()]`
        *   `contentColumnWidths`: `[:]`
        *   `totalWidth`: `300.0`
    *   **Trace**:
        *   `remainingWidth` = `300.0`. `flexibleIndices` = `[0, 1, 2]`.
        *   `distributableWidth` = `max(300, 0)` = `300.0`.
        *   `perColumnWidth` = `300.0 / 3` = `100.0`.
        *   Initial Widths: `[100.0, 100.0, 100.0]`.
        *   Clamping: Total sum `300.0` matches target width `300.0`. `excessWidth` = `0.0`. No shrink.
    *   **Expected Output**: `[100.0, 100.0, 100.0]`

*   **Scenario 1.2: Flexible columns with partially larger content widths**
    *   **Inputs**:
        *   `columnConfigs`: `[.flexible(), .flexible(), .flexible()]`
        *   `contentColumnWidths`: `[0: 150.0, 1: 50.0, 2: 50.0]`
        *   `totalWidth`: `300.0`
    *   **Trace**:
        *   `remainingWidth` = `300.0`. `flexibleIndices` = `[0, 1, 2]`.
        *   `perColumnWidth` = `300.0 / 3` = `100.0`.
        *   Initial Widths:
            *   Col 0: `max(100.0, 150.0, 0)` = `150.0`
            *   Col 1: `max(100.0, 50.0, 0)` = `100.0`
            *   Col 2: `max(100.0, 50.0, 0)` = `100.0`
            *   Sum = `350.0`.
        *   Clamping: `excessWidth` = `350.0 - 300.0` = `50.0`.
            *   **Phase 1 Shrink** (on flexible columns `[0, 1, 2]`):
                *   `totalWidth` = `350.0`.
                *   `shrinkAmount` = `min(50.0, 350.0)` = `50.0`.
                *   `shrinkFactor` = `(350.0 - 50.0) / 350.0` = `300.0 / 350.0` = `6 / 7` (≈ `0.8571428571428571`).
                *   Col 0 = `150.0 * 6/7` ≈ `128.5714`
                *   Col 1 = `100.0 * 6/7` ≈ `85.7143`
                *   Col 2 = `100.0 * 6/7` ≈ `85.7143`
                *   `excessWidth` decreases by `50.0` to `0.0`.
    *   **Expected Output**: `[128.57142857142858, 85.71428571428571, 85.71428571428571]` (or exact fractional bounds `[900/7, 600/7, 600/7]`)

*   **Scenario 1.3: Flexible columns with large content width relative to space**
    *   **Inputs**:
        *   `columnConfigs`: `[.flexible(), .flexible()]`
        *   `contentColumnWidths`: `[0: 200.0, 1: 300.0]`
        *   `totalWidth`: `100.0`
    *   **Trace**:
        *   `remainingWidth` = `100.0`. `flexibleIndices` = `[0, 1]`.
        *   `perColumnWidth` = `100.0 / 2` = `50.0`.
        *   Initial Widths: Col 0 = `200.0`, Col 1 = `300.0`. Sum = `500.0`.
        *   Clamping: `excessWidth` = `500.0 - 100.0` = `400.0`.
            *   **Phase 1 Shrink** (flexible `[0, 1]`):
                *   `totalWidth` = `500.0`.
                *   `shrinkAmount` = `min(400.0, 500.0)` = `400.0`.
                *   `shrinkFactor` = `(500.0 - 400.0) / 500.0` = `0.2`.
                *   Col 0 = `200.0 * 0.2` = `40.0`
                *   Col 1 = `300.0 * 0.2` = `60.0`
                *   `excessWidth` decreases by `400.0` to `0.0`.
    *   **Expected Output**: `[40.0, 60.0]`

---

#### Case 2: All Fixed Columns (`TableSizingMode.fixed`)

*   **Scenario 2.1: Fixed sum is less than container width**
    *   **Inputs**:
        *   `columnConfigs`: `[.fixed(50.0), .fixed(100.0), .fixed(100.0)]`
        *   `contentColumnWidths`: `[:]`
        *   `totalWidth`: `300.0`
    *   **Trace**:
        *   Initial Widths: Col 0 = `50.0`, Col 1 = `100.0`, Col 2 = `100.0`. Sum = `250.0`.
        *   `remainingWidth` = `300.0 - 250.0` = `50.0`.
        *   Clamping: `excessWidth` = `250.0 - 300.0` = `-50.0`. No shrink.
    *   **Expected Output**: `[50.0, 100.0, 100.0]` (Note: Unused space is not distributed to fixed columns).

*   **Scenario 2.2: Fixed sum exceeds container width**
    *   **Inputs**:
        *   `columnConfigs`: `[.fixed(100.0), .fixed(150.0), .fixed(150.0)]`
        *   `contentColumnWidths`: `[:]`
        *   `totalWidth`: `300.0`
    *   **Trace**:
        *   Initial Widths: Col 0 = `100.0`, Col 1 = `150.0`, Col 2 = `150.0`. Sum = `400.0`.
        *   `remainingWidth` = `300.0 - 400.0` = `-100.0`.
        *   Clamping: `excessWidth` = `400.0 - 300.0` = `100.0`.
            *   **Phase 1 Shrink** (flexible `[]`): No change.
            *   **Phase 2 Shrink** (fit `[]`): No change.
            *   **Phase 3 Shrink** (all `[0, 1, 2]`):
                *   `totalWidth` = `400.0`.
                *   `shrinkAmount` = `min(100.0, 400.0)` = `100.0`.
                *   `shrinkFactor` = `(400.0 - 100.0) / 400.0` = `0.75`.
                *   Col 0 = `100.0 * 0.75` = `75.0`
                *   Col 1 = `150.0 * 0.75` = `112.5`
                *   Col 2 = `150.0 * 0.75` = `112.5`
                *   `excessWidth` decreases by `100.0` to `0.0`.
    *   **Expected Output**: `[75.0, 112.5, 112.5]`

---

#### Case 3: All Fit (Auto-Sized) Columns (`TableSizingMode.fit`)

*   **Scenario 3.1: Fit sum is less than container width**
    *   **Inputs**:
        *   `columnConfigs`: `[.autoSized(), .autoSized(), .autoSized()]`
        *   `contentColumnWidths`: `[0: 40.0, 1: 60.0, 2: 80.0]`
        *   `totalWidth`: `300.0`
    *   **Trace**:
        *   Initial Widths: Col 0 = `40.0`, Col 1 = `60.0`, Col 2 = `80.0`. Sum = `180.0`.
        *   `remainingWidth` = `300.0 - 180.0` = `120.0`.
        *   Clamping: `excessWidth` = `180.0 - 300.0` = `-120.0`. No shrink.
    *   **Expected Output**: `[40.0, 60.0, 80.0]`

*   **Scenario 3.2: Fit columns with missing or zero measured width**
    *   **Inputs**:
        *   `columnConfigs`: `[.autoSized(), .autoSized(), .autoSized()]`
        *   `contentColumnWidths`: `[0: 0.0, 1: 50.0]` (Index 2 has no key)
        *   `totalWidth`: `300.0`
        *   `defaultAutoColumnWidth`: `20.0`
    *   **Trace**:
        *   Col 0: `measuredWidth` <= 0, resolves to `defaultAutoColumnWidth` = `20.0`.
        *   Col 1: `measuredWidth` = `50.0`.
        *   Col 2: `measuredWidth` not present, resolves to `defaultAutoColumnWidth` = `20.0`.
        *   Initial Widths: Col 0 = `20.0`, Col 1 = `50.0`, Col 2 = `20.0`. Sum = `90.0`.
        *   Clamping: `excessWidth` = `90.0 - 300.0` = `-210.0`. No shrink.
    *   **Expected Output**: `[20.0, 50.0, 20.0]`

*   **Scenario 3.3: Fit sum exceeds container width**
    *   **Inputs**:
        *   `columnConfigs`: `[.autoSized(), .autoSized(), .autoSized()]`
        *   `contentColumnWidths`: `[0: 100.0, 1: 150.0, 2: 150.0]`
        *   `totalWidth`: `300.0`
    *   **Trace**:
        *   Initial Widths: Col 0 = `100.0`, Col 1 = `150.0`, Col 2 = `150.0`. Sum = `400.0`.
        *   Clamping: `excessWidth` = `400.0 - 300.0` = `100.0`.
            *   **Phase 1 Shrink** (flexible `[]`): No change.
            *   **Phase 2 Shrink** (fit `[0, 1, 2]`):
                *   `totalWidth` = `400.0`.
                *   `shrinkAmount` = `min(100.0, 400.0)` = `100.0`.
                *   `shrinkFactor` = `(400.0 - 100.0) / 400.0` = `0.75`.
                *   Col 0 = `100.0 * 0.75` = `75.0`
                *   Col 1 = `150.0 * 0.75` = `112.5`
                *   Col 2 = `150.0 * 0.75` = `112.5`
                *   `excessWidth` decreases by `100.0` to `0.0`.
    *   **Expected Output**: `[75.0, 112.5, 112.5]`

---

#### Case 4: Mixed Sizing Configurations

*   **Scenario 4.1: Mixed combination (1 Fixed, 1 Fit, 1 Flexible) satisfying container width**
    *   **Inputs**:
        *   `columnConfigs`: `[.fixed(100.0), .autoSized(), .flexible()]`
        *   `contentColumnWidths`: `[1: 50.0]`
        *   `totalWidth`: `300.0`
    *   **Trace**:
        *   Col 0 (fixed): Width = `100.0`. `remainingWidth` = `200.0`.
        *   Col 1 (fit): Width = `50.0`. `remainingWidth` = `150.0`.
        *   Col 2 (flexible): Added to `flexibleIndices` = `[2]`.
        *   Flexible distribution: `perColumnWidth` = `150.0 / 1` = `150.0`. Col 2 width = `max(150.0, 0, 0)` = `150.0`.
        *   Clamping: Sum = `100 + 50 + 150` = `300.0`. `excessWidth` = `0.0`. No shrink.
    *   **Expected Output**: `[100.0, 50.0, 150.0]`

*   **Scenario 4.2: Mixed combination causing flexible column to shrink**
    *   **Inputs**:
        *   `columnConfigs`: `[.fixed(150.0), .autoSized(), .flexible()]`
        *   `contentColumnWidths`: `[1: 100.0, 2: 80.0]`
        *   `totalWidth`: `300.0`
    *   **Trace**:
        *   Col 0 (fixed): Width = `150.0`. `remainingWidth` = `150.0`.
        *   Col 1 (fit): Width = `100.0`. `remainingWidth` = `50.0`.
        *   Col 2 (flexible): Added to `flexibleIndices` = `[2]`.
        *   Flexible distribution: `perColumnWidth` = `50.0 / 1` = `50.0`. Col 2 width = `max(50.0, 80.0, 0)` = `80.0`.
        *   Initial Widths: `[150.0, 100.0, 80.0]`. Sum = `330.0`.
        *   Clamping: `excessWidth` = `330.0 - 300.0` = `30.0`.
            *   **Phase 1 Shrink** (flexible `[2]`):
                *   `totalWidth` = `80.0`.
                *   `shrinkAmount` = `min(30.0, 80.0)` = `30.0`.
                *   `shrinkFactor` = `(80.0 - 30.0) / 80.0` = `5/8` = `0.625`.
                *   Col 2 = `80.0 * 0.625` = `50.0`.
                *   `excessWidth` decreases by `30.0` to `0.0`.
    *   **Expected Output**: `[150.0, 100.0, 50.0]`

*   **Scenario 4.3: Mixed combination causing both flexible and fit columns to shrink**
    *   **Inputs**:
        *   `columnConfigs`: `[.fixed(150.0), .autoSized(), .flexible()]`
        *   `contentColumnWidths`: `[1: 200.0, 2: 50.0]`
        *   `totalWidth`: `300.0`
    *   **Trace**:
        *   Col 0 (fixed): Width = `150.0`. `remainingWidth` = `150.0`.
        *   Col 1 (fit): Width = `200.0`. `remainingWidth` = `-50.0`.
        *   Col 2 (flexible): Added to `flexibleIndices` = `[2]`.
        *   Flexible distribution: `perColumnWidth` = `0.0`. Col 2 width = `max(0.0, 50.0, 0)` = `50.0`.
        *   Initial Widths: `[150.0, 200.0, 50.0]`. Sum = `400.0`.
        *   Clamping: `excessWidth` = `400.0 - 300.0` = `100.0`.
            *   **Phase 1 Shrink** (flexible `[2]`):
                *   `totalWidth` = `50.0`.
                *   `shrinkAmount` = `min(100.0, 50.0)` = `50.0`.
                *   `shrinkFactor` = `(50.0 - 50.0) / 50.0` = `0.0`.
                *   Col 2 = `50.0 * 0.0` = `0.0`.
                *   `excessWidth` decreases by `50.0` to `50.0`.
            *   **Phase 2 Shrink** (fit `[1]`):
                *   `totalWidth` = `200.0`.
                *   `shrinkAmount` = `min(50.0, 200.0)` = `50.0`.
                *   `shrinkFactor` = `(200.0 - 50.0) / 200.0` = `0.75`.
                *   Col 1 = `200.0 * 0.75` = `150.0`.
                *   `excessWidth` decreases by `50.0` to `0.0`.
    *   **Expected Output**: `[150.0, 150.0, 0.0]`

---

#### Case 5: Edge Cases & Shrink Priorities

*   **Scenario 5.1: Zero available width**
    *   **Inputs**:
        *   `columnConfigs`: `[.fixed(100.0), .autoSized(), .flexible()]`
        *   `contentColumnWidths`: `[1: 50.0]`
        *   `totalWidth`: `0`
    *   **Trace**:
        *   `availableWidth` = `0.0`.
        *   `targetWidth` <= 0 triggers the fallback guard inside `clampColumnWidths`.
    *   **Expected Output**: `[0.0, 0.0, 0.0]`

*   **Scenario 5.2: Zero column count**
    *   **Inputs**:
        *   `columnConfigs`: `[]`
        *   `contentColumnWidths`: `[:]`
        *   `totalWidth`: `300.0`
    *   **Trace**:
        *   `columnConfigs.count` = 0 triggers the guard `columnCount > 0 else { return [] }`.
    *   **Expected Output**: `[]`

*   **Scenario 5.3: Total fixed width exceeds container width (Fixed + Fixed)**
    *   **Inputs**:
        *   `columnConfigs`: `[.fixed(200.0), .fixed(200.0)]`
        *   `contentColumnWidths`: `[:]`
        *   `totalWidth`: `300.0`
    *   **Trace**:
        *   Initial Widths: Col 0 = `200.0`, Col 1 = `200.0`. Sum = `400.0`.
        *   Clamping: `excessWidth` = `400.0 - 300.0` = `100.0`.
            *   **Phase 1 Shrink** (flexible `[]`): No change.
            *   **Phase 2 Shrink** (fit `[]`): No change.
            *   **Phase 3 Shrink** (all `[0, 1]`):
                *   `totalWidth` = `400.0`.
                *   `shrinkAmount` = `min(100.0, 400.0)` = `100.0`.
                *   `shrinkFactor` = `(400.0 - 100.0) / 400.0` = `0.75`.
                *   Col 0 = `200.0 * 0.75` = `150.0`
                *   Col 1 = `200.0 * 0.75` = `150.0`
                *   `excessWidth` decreases by `100.0` to `0.0`.
    *   **Expected Output**: `[150.0, 150.0]`

*   **Scenario 5.4: Extremely constrained space causing shrink across all phases**
    *   **Inputs**:
        *   `columnConfigs`: `[.fixed(100.0), .autoSized(), .flexible()]`
        *   `contentColumnWidths`: `[1: 150.0, 2: 100.0]`
        *   `totalWidth`: `80.0`
    *   **Trace**:
        *   Col 0 (fixed): Width = `100.0`.
        *   Col 1 (fit): Width = `150.0`.
        *   Col 2 (flexible): Width = `max(0, 100.0, 0)` = `100.0`.
        *   Initial Widths: `[100.0, 150.0, 100.0]`. Sum = `350.0`.
        *   Clamping: `excessWidth` = `350.0 - 80.0` = `270.0`.
            *   **Phase 1 Shrink** (flexible `[2]`):
                *   `totalWidth` = `100.0`.
                *   `shrinkAmount` = `min(270.0, 100.0)` = `100.0`.
                *   `shrinkFactor` = `0.0`.
                *   Col 2 = `100.0 * 0.0` = `0.0`.
                *   `excessWidth` decreases by `100.0` to `170.0`.
            *   **Phase 2 Shrink** (fit `[1]`):
                *   `totalWidth` = `150.0`.
                *   `shrinkAmount` = `min(170.0, 150.0)` = `150.0`.
                *   `shrinkFactor` = `0.0`.
                *   Col 1 = `150.0 * 0.0` = `0.0`.
                *   `excessWidth` decreases by `150.0` to `20.0`.
            *   **Phase 3 Shrink** (all `[0, 1, 2]`):
                *   `totalWidth` = `100.0 + 0.0 + 0.0` = `100.0`.
                *   `shrinkAmount` = `min(20.0, 100.0)` = `20.0`.
                *   `shrinkFactor` = `(100.0 - 20.0) / 100.0` = `0.8`.
                *   Col 0 = `100.0 * 0.8` = `80.0`.
                *   Col 1 = `0.0 * 0.8` = `0.0`.
                *   Col 2 = `0.0 * 0.8` = `0.0`.
                *   `excessWidth` decreases by `20.0` to `0.0`.
    *   **Expected Output**: `[80.0, 0.0, 0.0]`

---

### Part B: Height & Border Sizing Scenarios

#### Case 6: Row Heights and Borders (`resolvedRowHeights` and `heightFromRowHeights`)

*   **Scenario 6.1: Border height calculations**
    *   **Inputs**:
        *   `rowHeights`: `[40.0, 30.0, 50.0]`
        *   `borderAppearance`: `TableBorderAppearance` with `width` = `2.0`, `showHeaderBorders` = `true`, `showRowBorders` = `true`
    *   **Trace**:
        *   `totalRowHeight` = `40.0 + 30.0 + 50.0` = `120.0`.
        *   `totalHorizontalBorderHeight` calculation:
            *   `rowIndex = 0`: `showHeaderBorders` is true -> `total` = `2.0`.
            *   `rowIndex = 1`: `showRowBorders` is true -> `total` = `4.0`.
            *   `rowIndex = 2`: `showRowBorders` is true -> `total` = `6.0`.
            *   End of loop: `showRowBorders` is true -> `total` = `8.0`.
        *   `borderHeight` = `8.0`.
        *   Total height returned by `heightFromRowHeights`: `totalRowHeight + borderHeight + borderWidth` = `120.0 + 8.0 + 2.0` = `130.0`.
    *   **Expected Output**: `130.0` (Grid frame height is `128.0`).

*   **Scenario 6.2: Row heights floor constraint**
    *   **Inputs**:
        *   `rowConfig[0].size`: `50.0`, `isFlexible` = `true`
        *   Measured text height of row 0 cell: `35.0`
        *   Cell padding: `5.0`
    *   **Trace**:
        *   `maxCellHeight` = `measuredHeight + padding * 2` = `35.0 + (5.0 * 2)` = `45.0`.
        *   Resolved row height: `max(maxCellHeight, rowConfig.size)` = `max(45.0, 50.0)` = `50.0`.
    *   **Expected Output**: Row height resolves to `50.0` (uses configuration floor size).

*   **Scenario 6.3: Row heights content overflow**
    *   **Inputs**:
        *   `rowConfig[0].size`: `50.0`, `isFlexible` = `true`
        *   Measured text height of row 0 cell: `60.0`
        *   Cell padding: `5.0`
    *   **Trace**:
        *   `maxCellHeight` = `measuredHeight + padding * 2` = `60.0 + (5.0 * 2)` = `70.0`.
        *   Resolved row height: `max(maxCellHeight, rowConfig.size)` = `max(70.0, 50.0)` = `70.0`.
    *   **Expected Output**: Row height resolves to `70.0` (exceeds floor size to fit text).
