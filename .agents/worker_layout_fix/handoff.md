# Handoff Report - Layout Fixes (Bug 1 & Bug 2)

## 1. Observation
We observed the following state and code locations before applying the layout fixes:
- **File 1**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Support/LeafComponentFrameSizing.swift`
  - In `contentVerticalSize(for:)` (lines 93-99), the original vertical size calculation for a shrink-to-fit (auto-sized) component:
    ```swift
    static func contentVerticalSize(for component: InvoiceComponent) -> CGFloat? {
        guard component.usesTableProperties, component.usesContentDrivenRowHeights else { return nil }
        let rowCount = contentDrivenRowCount(for: component)
        guard rowCount > 0 else { return nil }
        let perRow = DocumentGridContentHeight.estimatedSingleLineAutoRowHeight(style: component.style)
        return perRow * CGFloat(rowCount)
    }
    ```
    This calculation did not include table borders, section title height, section title bottom padding, component padding, or component borders.
- **File 2**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Models/Domain/InvoiceComponent.swift`
  - In `minIntrinsicWidth` (lines 182-198), column widths config values were summed, but the outer table border, component padding, and component border width were omitted:
    ```swift
    for config in configs {
        ...
        if config.isAutoSized {
            minWidth += config.width
        } else {
            minWidth += config.width
        }
    }
    return minWidth > 0 ? minWidth : nil
    ```
- **File 3**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Canvas/LinearSplitView.swift` & `GridSplitView.swift`
  - Intrinsic size calculations called `split.intrinsicSizeForChild(at:along:)` (which doesn't query the live document state from the environment) instead of `split.intrinsicSizeForChild(at:along:document:)` (which is the document-aware overload).

- **Tool Command Result**:
  - Running `swift test` within `Packages/Feature.InvoiceTemplateEditor` succeeded for all 197 base tests.
  - Running `xcodebuild` succeeded with `** BUILD SUCCEEDED **` for target `InvoicingApplication`.

---

## 2. Logic Chain
- **Bug 1 (Vertical layout undercount)**:
  1. On initial layout, `idealSize` is not yet populated by SwiftUI preference keys.
  2. The layout resolver fallback `contentVerticalSize(for:)` undercounts size because it ignores the presence of a section title (along with its bottom padding), the table's own borders, and the outer component's padding and borders.
  3. Consequently, `LinearSplitView` and `GridSplitView` allocate insufficient height during the initial measurement pass.
  4. Even after the view measures its correct size and updates the document registry, the split views were unable to read the refreshed sizes since they did not pass the live `document` model from `@Environment(InvoiceDocument.self)` to `split.intrinsicSizeForChild(at:along:)`.
  5. By injecting `@Environment(InvoiceDocument.self) var document` and passing it to the child intrinsic size methods, the layout engine retrieves the actual measured ideal heights on subsequent rendering passes.

- **Bug 2 (Horizontal layout undercount)**:
  1. `InvoiceComponent.minIntrinsicWidth` is used to determine the minimum space required for content-driven tables.
  2. Since it failed to sum the table's own border width (`style.tableBorderWidth`), component padding (`style.padding * 2`), and component border width (`style.borderWidth * 2`), the parent split containers under-allocated horizontal width, causing column squeezing and clipped text.
  3. Adding these dimensions to `minIntrinsicWidth` ensures minimum constraints are honored correctly.

---

## 3. Caveats
- No caveats. The layout fixes are verified locally and all regression tests passed.

---

## 4. Conclusion
- **Bug 1** is fixed by:
  - Injecting `@Environment(InvoiceDocument.self)` into `LinearSplitView` and `GridSplitView`.
  - Calling the document-aware `intrinsicSizeForChild(at:along:document:)` to retrieve live/measured sizes.
  - Updating `LeafComponentFrameSizing.contentVerticalSize(for:)` to include section title text height, title bottom padding, table borders, and component padding/borders.
- **Bug 2** is fixed by:
  - Modifying `InvoiceComponent.minIntrinsicWidth` to include table border width, component padding, and component border width.

---

## 5. Verification Method
- **Verification Command**:
  - Run package tests:
    ```bash
    swift test
    ```
    inside `/Users/user/Developer/InvoicingApplication/InvoicingApplication/Packages/Feature.InvoiceTemplateEditor`.
  - Build main app target:
    ```bash
    xcodebuild -project InvoicingApplication.xcodeproj -scheme InvoicingApplication -sdk macosx build -derivedDataPath BuildData/Build
    ```
- **Files to Inspect**:
  - `LeafComponentFrameSizing.swift`
  - `InvoiceComponent.swift`
  - `LinearSplitView.swift`
  - `GridSplitView.swift`
  - `DocumentGridHeightRegressionTests.swift` (contains the newly added regression tests `testMinIntrinsicWidthIncludesBordersAndPadding` and `testContentVerticalSizeIncludesTitleBordersAndPadding`).
