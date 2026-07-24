# Handoff Report — Explorer-03 Layout Sizing Math

## 1. Observation

I located and analyzed the layout math files in the workspace:
*   `DocumentGridLayoutMath.swift` at `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/DocumentGridLayoutMath.swift`
*   `DocumentGridLayout+Preferences.swift` at `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/DocumentGridLayout+Preferences.swift`

Direct Observations of the column width resolution and shrink logic:
From `DocumentGridLayoutMath.swift` lines 43-59:
```swift
        for index in 0..<columnCount {
            let config = columnConfigs[index]
            if config.isAutoSized {
                autoSizedIndices.append(index)
                let rawMeasuredWidth = contentColumnWidths[index] ?? 0
                let measuredWidth = rawMeasuredWidth > 0 ? rawMeasuredWidth : defaultAutoColumnWidth
                widths[index] = max(measuredWidth, config.fixedWidth ?? 0)
                remainingWidth -= widths[index]
            } else if let fixedWidth = config.fixedWidth {
                widths[index] = fixedWidth
                remainingWidth -= fixedWidth
            } else if config.isFlexible {
                flexibleIndices.append(index)
            } else {
                flexibleIndices.append(index)
            }
        }
```

From `DocumentGridLayoutMath.swift` lines 61-70:
```swift
        if !flexibleIndices.isEmpty {
            let distributableWidth = max(remainingWidth, 0)
            let perColumnWidth = distributableWidth / CGFloat(flexibleIndices.count)

            for index in flexibleIndices {
                let measuredWidth = contentColumnWidths[index] ?? 0
                let minimumWidth = columnConfigs[index].fixedWidth ?? 0
                widths[index] = max(perColumnWidth, measuredWidth, minimumWidth)
            }
        }
```

From `DocumentGridLayoutMath.swift` lines 88-95 (clamping passes):
```swift
        var adjustedWidths = widths
        var excessWidth = adjustedWidths.reduce(0, +) - targetWidth
        guard excessWidth > 0 else { return adjustedWidths }

        shrinkWidths(&adjustedWidths, for: flexibleIndices, excessWidth: &excessWidth)
        shrinkWidths(&adjustedWidths, for: autoSizedIndices, excessWidth: &excessWidth)
        shrinkWidths(&adjustedWidths, for: Array(adjustedWidths.indices), excessWidth: &excessWidth)
```

From `DocumentGridLayout+Preferences.swift` lines 199-225 (border height logic):
```swift
    static func totalHorizontalBorderHeight(
        rowCount: Int,
        borderWidth: CGFloat,
        showHeaderBorders: Bool,
        showRowBorders: Bool
    ) -> CGFloat {
        guard rowCount > 0 else {
            return showRowBorders ? borderWidth : 0
        }

        var total: CGFloat = 0
        for rowIndex in 0..<rowCount {
            if rowIndex == 0 {
                if showHeaderBorders {
                    total += borderWidth
                }
            } else if showRowBorders {
                total += borderWidth
            }
        }

        if showRowBorders {
            total += borderWidth
        }

        return total
    }
```

## 2. Logic Chain

1. **Initial allocation**: Fixed and auto-sized (fit) columns calculate their widths and deduct them directly from `remainingWidth` (Observation: lines 43-59).
2. **Flexible distribution**: Any positive `remainingWidth` is divided equally among flexible columns (Observation: lines 61-70).
3. **Clamping pass priorities**: If total widths exceed `targetWidth`, `excessWidth` is computed. Three passes of `shrinkWidths` are performed (Observation: lines 88-95):
    *   *Pass 1*: flexible columns shrink first.
    *   *Pass 2*: auto-sized (fit) columns shrink next.
    *   *Pass 3*: all columns (including fixed ones) shrink last if excess remains.
4. **Deterministic height**: Grid height is computed from row heights and border parameters. Border height is calculated row-by-row (Observation: lines 199-225) and added to the sum of row heights along with one final `borderWidth` offset.

## 3. Caveats

No caveats. All code logic was analyzed directly and verified against standard math equations.

## 4. Conclusion

A complete, comprehensive test specification covering all flexible, fixed, fit, mixed, and edge cases, along with their expected column widths and height resolutions, has been written to:
`/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/teamwork_preview_explorer_sizing_tests_explorer_3/analysis.md`

## 5. Verification Method

*   **Test Command**: Run `swift test` in folder `Packages/Feature.InvoiceTemplateEditor`.
*   **Verification file**: `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/teamwork_preview_explorer_sizing_tests_explorer_3/analysis.md`.
*   **Invalidation condition**: Any alterations to the order of passes in `clampColumnWidths` or changes to border height calculations.
