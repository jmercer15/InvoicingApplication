# Handoff Report: DocumentGridLayoutMath Investigation & Analysis

## 1. Observation
- Located `DocumentGridLayoutMath` at `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/DocumentGridLayoutMath.swift`.
- Sizing modes (`flexible`, `fit` (auto-sized), `fixed`) are defined in `InvoiceComponentStyle+Axis.swift` and resolved through `ColumnWidthConfig` structures in `DocumentGridLayout+Types.swift`.
- Existing unit tests for layout math are located in `Packages/Feature.InvoiceTemplateEditor/Tests/Feature_InvoiceTemplateEditorTests/DocumentGridExportLayoutTests.swift` and `Packages/Feature.InvoiceTemplateEditor/Tests/Feature_InvoiceTemplateEditorTests/DocumentGridHeightReliabilityTests.swift`.

## 2. Logic Chain
- **Column Sizing Math**:
  - Allocated via `resolvedColumnWidths`.
  - Pass 1: Deducts Fixed and Fit (AutoSized) column content widths (using `contentColumnWidths`, fallback to 20) from total width.
  - Pass 2: Divides remaining width evenly among Flexible columns:
    $$W_{per\_col} = \frac{W_{remaining}}{|\text{flexibleIndices}|}$$
  - Clamping Pass: If sum of widths exceeds total width, `clampColumnWidths` uses `shrinkWidths` to scale down widths proportionally based on priority: (1) Flexible, (2) Auto-sized, (3) All columns (Fixed).
  - Scale factor formula for target subset $I$:
    $$F = \max\left(\frac{W_I - S}{W_I}, 0\right)$$
- **Row Sizing Math**:
  - Evaluated via `resolvedRowHeights`.
  - Fixed rows use configured size verbatim.
  - Dynamic (Fit/Flexible) rows measure cell CoreText bounds constrained to the cell width:
    $$W_{cell} = \max(0, W_{column} - \text{padding} \times 2)$$
  - Returns:
    $$h_r = \max\left( \max_{c}(h_{cell, c}), \text{rowConfig}_r.\text{size} \right)$$

## 3. Caveats
- Typographic bounding calculations assume line leading values from the font descriptor are greater than zero. If the font returns zero leading, line bounds might be underestimated.
- Multi-column span items do not contribute dynamically to `measureColumnContentWidths` inside the single-column loop mapping.

## 4. Conclusion
- A comprehensive mathematical analysis has been performed. Sizing modes and proportional shrinking scaling are mathematically detailed.
- An extensive unit-testing strategy covering edge cases (such as zero/negative total width, exact proportional shrinking, and line limit height wrapping) has been recommended.
- Full findings have been documented in `analysis.md` in the working directory.

## 5. Verification Method
- Validated existing test execution in the package:
  ```bash
  swift test
  ```
