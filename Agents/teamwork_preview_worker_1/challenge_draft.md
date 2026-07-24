# Mathematical Robustness Analysis: DocumentGridLayoutMath

This report evaluates the mathematical robustness, edge cases, and numerical limits of `DocumentGridLayoutMath.swift` and its associated unit tests.

---

## 1. Float Extremes

This section analyzes how the layout math handles `CGFloat.nan`, `CGFloat.infinity`, and negative values in inputs like `totalWidth`, `contentColumnWidths`, and `ColumnWidthConfig.fixedWidth`.

### A. NaN (Not-a-Number) Handling

1. **Total Width (`totalWidth`)**
   - **Path**: `DocumentGridLayoutMath.resolvedColumnWidths`
   - **Logic**: 
     - `availableWidth` is computed as `max(totalWidth, 0)`. If `totalWidth` is `NaN`, `max(CGFloat.nan, 0)` evaluates to `NaN` in Swift.
     - `remainingWidth` is initialized to `NaN`.
     - In `clampColumnWidths`, `targetWidth` (which is `availableWidth`, i.e., `NaN`) is guarded:
       ```swift
       guard targetWidth > 0 else { return Array(repeating: 0, count: widths.count) }
       ```
       Because all comparison operations with `NaN` (except `!=`) evaluate to `false`, `targetWidth > 0` returns `false`.
     - **Behavior**: The code safely returns `Array(repeating: 0, count: widths.count)`.

2. **Content Column Widths (`contentColumnWidths`)**
   - **Path**: `DocumentGridLayoutMath.resolvedColumnWidths` (auto-sized config processing)
   - **Logic**:
     ```swift
     let rawMeasuredWidth = contentColumnWidths[index] ?? 0
     let measuredWidth = rawMeasuredWidth > 0 ? rawMeasuredWidth : defaultAutoColumnWidth
     ```
     - If `contentColumnWidths[index]` is `NaN`, `rawMeasuredWidth > 0` is `false`.
     - **Behavior**: It safely falls back to `defaultAutoColumnWidth` (20.0), neutralizing the `NaN`.

3. **Fixed Configurations (`config.fixedWidth`)**
   - **Path**: `DocumentGridLayoutMath.resolvedColumnWidths`
   - **Logic**:
     - For auto-sized: `widths[index] = max(measuredWidth, config.fixedWidth ?? 0)`. If `config.fixedWidth` is `NaN`, `max` returns `NaN`.
     - For fixed width: 
       ```swift
       widths[index] = fixedWidth
       remainingWidth -= fixedWidth
       ```
       If `fixedWidth` is `NaN`, `widths[index]` becomes `NaN`, and `remainingWidth` becomes `NaN`.
     - In `clampColumnWidths`:
       `excessWidth = adjustedWidths.reduce(0, +) - targetWidth` evaluates to `NaN`.
       `guard excessWidth > 0` evaluates to `false`.
     - **Behavior**: The function returns `adjustedWidths` containing `NaN` values. This propagates `NaN` to column origins, geometry, and rendering, potentially causing visual corruption or rendering engine crashes.

---

### B. Infinity (`CGFloat.infinity`) Handling

1. **Total Width (`totalWidth`)**
   - **Path**: `resolvedColumnWidths`
   - **Logic**:
     - `availableWidth = max(infinity, 0) = infinity`.
     - If flexible columns exist, `perColumnWidth = infinity / flexibleIndices.count = infinity`.
     - `widths` for flexible columns become `infinity`.
     - In `clampColumnWidths`:
       - `excessWidth = sum(widths) - targetWidth` -> `infinity - infinity` -> `NaN`.
       - `guard excessWidth > 0` is `false`.
     - **Behavior**: Returns `widths` containing `infinity`. Propagation of `infinity` to frames and origins can trigger layout engine failures or canvas resizing loops.

2. **Content Column Widths (`contentColumnWidths`)**
   - **Logic**:
     - `rawMeasuredWidth > 0` is `true`. `measuredWidth` becomes `infinity`.
     - `widths[index]` becomes `infinity`.
     - `remainingWidth -= infinity` -> `-infinity` or `NaN`.
     - **Behavior**: Contaminates remaining columns, reducing their widths to negative/NaN values.

3. **Fixed Width Configurations (`config.fixedWidth`)**
   - **Logic**:
     - `widths[index]` becomes `infinity`.
     - `remainingWidth` becomes `-infinity`.
     - **Behavior**: Leads to a `NaN` excess width in clamping and propagates `infinity` columns.

---

### C. Negative Widths & Heights

1. **Total Width (`totalWidth`)**
   - **Behavior**: Correctly clamped to `0` via `max(totalWidth, 0)` at the entry point of `resolvedColumnWidths`.

2. **Content Column Widths (`contentColumnWidths`)**
   - **Logic**: `rawMeasuredWidth > 0` is `false` for negative numbers.
   - **Behavior**: Safely falls back to `defaultAutoColumnWidth`.

3. **Fixed Configurations (`config.fixedWidth`)**
   - **Logic**:
     - For auto-sized: `widths[index] = max(measuredWidth, config.fixedWidth ?? 0)`. Clamped to positive `measuredWidth`.
     - For fixed width: `widths[index] = fixedWidth` assigns the negative value directly.
     - **Behavior**: `remainingWidth` increases. In `clampColumnWidths`, negative widths bypass shrinking. The layout engine will output negative column widths, propagating down to invalid `CGRect` bounds.

---

## 2. Divide-by-Zero Risks

There are two division operations in `DocumentGridLayoutMath.swift`. Both are structurally protected from division-by-zero crashes:

### Division 1: Flexible Column Allocation
```swift
let perColumnWidth = distributableWidth / CGFloat(flexibleIndices.count)
```
- **Safety**: Guarded by `if !flexibleIndices.isEmpty`. The count is guaranteed to be $\ge 1$.
- **Risk**: None.

### Division 2: Shrink Factor Calculation
```swift
let shrinkFactor = max((totalWidth - shrinkAmount) / totalWidth, 0)
```
- **Safety**: Guarded by `guard totalWidth > 0 else { return }`.
- **Subnormal Numbers**: If `totalWidth` is positive but extremely small (e.g. `Double.leastNormalMagnitude` or `1e-308`), floating-point division is still valid. If `excessWidth >= totalWidth`, `shrinkAmount` is clamped to `totalWidth`, resulting in a numerator of `0`, and a `shrinkFactor` of `0.0`.
- **NaN Handling**: If `totalWidth` is `NaN`, `totalWidth > 0` evaluates to `false`. The function exits early, preventing division.
- **Infinity Handling**: If `totalWidth` is `infinity`, `infinity > 0` is `true`. `(infinity - excessWidth) / infinity` yields `infinity / infinity` which equals `NaN`. This propagates `NaN` but does not crash.

---

## 3. Column Shrinking Limits & Edge Cases

### A. Infinite Loops
- **Analysis**: The `shrinkWidths` and `clampColumnWidths` routines consist entirely of sequential logic and bounded `for-in` loops over pre-allocated arrays (`indices`).
- **Verdict**: **Zero risk** of infinite loops.

### B. Negative Scaling
- **Analysis**: `shrinkFactor` is wrapped in `max(..., 0)`.
- **Verdict**: Valid columns (widths $\ge 0$) will never scale to negative values. However, if a column width was already negative, scaling it by a positive factor maintains its negative sign.

### C. Overflow and Precision Limits
1. **Precision Residuals**: Subtracting `shrinkAmount` from `excessWidth` (`excessWidth -= shrinkAmount`) can leave a small positive/negative residual due to floating-point rounding errors. If the residual is negative, subsequent groups return early due to the `excessWidth > 0` guard. If positive, it may cause a minor over-shrink, which is harmless.
2. **Overflow to Infinity**: If the sum of column widths overflows to `infinity`, `shrinkFactor` becomes `NaN`, ruining layout stability.

---

## 4. Safety Recommendations

### A. Defensive Assertions and Guards (Code Changes)

We recommend adding the following guards to `DocumentGridLayoutMath.swift` to prevent extreme float propagation:

1. **Total Width Guard in `resolvedColumnWidths`**:
   ```swift
   guard totalWidth.isFinite, totalWidth > 0 else {
       return Array(repeating: 0, count: columnConfigs.count)
   }
   ```

2. **Column Configuration Sanitization**:
   Ensure `fixedWidth` is finite and non-negative:
   ```swift
   let fixedWidth = config.fixedWidth
   if let fixedWidth = fixedWidth {
       let safeWidth = fixedWidth.isFinite && fixedWidth >= 0 ? fixedWidth : 0
       widths[index] = safeWidth
       remainingWidth -= safeWidth
   }
   ```

3. **Total Width Guard in `shrinkWidths`**:
   Ensure `totalWidth` is finite before division:
   ```swift
   guard totalWidth.isFinite else {
       widths = Array(repeating: 0, count: widths.count)
       excessWidth = 0
       return
   }
   ```

---

### B. Additional Unit Test Cases

The following test cases should be added to `DocumentGridLayoutMathTests.swift` to guarantee robustness:

```swift
func testTotalWidthExtremes() {
    let configs: [ColumnWidthConfig] = [.fixed(100), .flexible()]
    
    // Test NaN total width
    let nanWidths = DocumentGridLayoutMath.resolvedColumnWidths(
        columnConfigs: configs,
        contentColumnWidths: [:],
        totalWidth: .nan
    )
    XCTAssertEqual(nanWidths, [0.0, 0.0])
    
    // Test negative total width
    let negativeWidths = DocumentGridLayoutMath.resolvedColumnWidths(
        columnConfigs: configs,
        contentColumnWidths: [:],
        totalWidth: -100.0
    )
    XCTAssertEqual(negativeWidths, [0.0, 0.0])
}

func testFixedWidthExtremes() {
    // NaN in fixed config width
    let configsWithNaN: [ColumnWidthConfig] = [.fixed(.nan), .fixed(100.0)]
    let resolvedNaN = DocumentGridLayoutMath.resolvedColumnWidths(
        columnConfigs: configsWithNaN,
        contentColumnWidths: [:],
        totalWidth: 300.0
    )
    // Safe implementation should not output NaN
    XCTAssertFalse(resolvedNaN.contains { $0.isNaN })
    
    // Negative fixed widths
    let configsWithNegative: [ColumnWidthConfig] = [.fixed(-50.0), .fixed(150.0)]
    let resolvedNegative = DocumentGridLayoutMath.resolvedColumnWidths(
        columnConfigs: configsWithNegative,
        contentColumnWidths: [:],
        totalWidth: 100.0
    )
    XCTAssertTrue(resolvedNegative.allSatisfy { $0 >= 0 })
}

func testContentWidthExtremes() {
    let configs: [ColumnWidthConfig] = [.autoSized(), .flexible()]
    
    // NaN measured content width
    let contentWidthsNaN: [Int: CGFloat] = [0: .nan]
    let resolvedNaN = DocumentGridLayoutMath.resolvedColumnWidths(
        columnConfigs: configs,
        contentColumnWidths: contentWidthsNaN,
        totalWidth: 100.0
    )
    XCTAssertEqual(resolvedNaN[0], 20.0) // Falls back to defaultAutoColumnWidth
    
    // Infinity measured content width
    let contentWidthsInf: [Int: CGFloat] = [0: .infinity]
    let resolvedInf = DocumentGridLayoutMath.resolvedColumnWidths(
        columnConfigs: configs,
        contentColumnWidths: contentWidthsInf,
        totalWidth: 100.0
    )
    XCTAssertFalse(resolvedInf.contains { $0.isNaN || $0.isInfinite })
}

func testShrinkSubnormalAndOverflow() {
    // Subnormal total width
    let subnormalConfigs: [ColumnWidthConfig] = [.fixed(1e-300), .fixed(1e-300)]
    let subnormalResolved = DocumentGridLayoutMath.resolvedColumnWidths(
        columnConfigs: subnormalConfigs,
        contentColumnWidths: [:],
        totalWidth: 0
    )
    XCTAssertEqual(subnormalResolved, [0.0, 0.0])
    
    // Sum of widths overflow
    let largeConfigs: [ColumnWidthConfig] = [.fixed(.greatestFiniteMagnitude), .fixed(.greatestFiniteMagnitude)]
    let overflowResolved = DocumentGridLayoutMath.resolvedColumnWidths(
        columnConfigs: largeConfigs,
        contentColumnWidths: [:],
        totalWidth: 500.0
    )
    XCTAssertFalse(overflowResolved.contains { $0.isNaN })
}
```
