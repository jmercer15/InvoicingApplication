# Codebase Investigation Report: Table/Grid Sizing and Rendering

This report details the investigation of the `InvoicingApplication` codebase to locate key sizing enums, models, inspector views, rendering calculations, and tests related to table and grid sizing.

---

## 1. Sizing Mode Enums

The codebase currently contains multiple enums representing sizing modes across inspector UI helpers and views.

### AxisSizingMode
* **File Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/TableElementPropertyEditor+RowColumnSections.swift`
* **Definition**:
```swift
private enum AxisSizingMode: String, CaseIterable {
    case flexible = "Flexible"
    case fit = "Fit"
    case fixed = "Fixed"
}
```
* **Role**: Sizing mode picker binding in row and column sections of `TableElementPropertyEditor`. It maps `.flexible` to `isFlexible`, `.fit` to `isAutoSized`, and `.fixed` to neither.

### ColumnWidthMode & RowHeightMode
* **File Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/ComponentPropertyEditor+Helpers.swift`
* **Definition**:
```swift
enum ColumnWidthMode: String, CaseIterable {
    case flexible = "Flexible"
    case autoSize = "Fit"
    case fixed = "Fixed"
}

enum RowHeightMode: String, CaseIterable {
    case flexible = "Flexible"
    case autoSize = "Fit"
    case fixed = "Fixed"
}
```
* **Role**: Bindings for width/height mode pickers within `ComponentPropertyEditor+Table.swift` for configuring columns and rows inside the general component property editor panels.

---

## 2. Key Sizing Structures & Classes

### TableAxisConfiguration (within ComponentStyle)
* **File Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Models/Domain/InvoiceComponentStyle+Axis.swift`
* **Definition**:
```swift
public struct TableAxisConfiguration: Codable, Hashable, Sendable {
    public var size: CGFloat = 100
    public var isFlexible: Bool = true
    public var isAutoSized: Bool = false
    public var alignment: TextAlignment = .leading
    public var verticalAlignmentOption: VerticalAlignmentOption = .center
    public var headerAlignment: TextAlignment = .center
    public var headerVerticalAlignmentOption: VerticalAlignmentOption = .center
    public var lineLimit: Int = 1
    ...
    // Compatibility computed properties
    public var width: CGFloat {
        get { size }
        set { size = newValue }
    }
    public var height: CGFloat {
        get { size }
        set { size = newValue }
    }
}
```
* **Description**: Model containing sizing properties for table/grid lines. Under the hood, size defaults to 100 for columns and 50 for rows. The flags `isFlexible` and `isAutoSized` determine if columns adjust dynamically. It includes custom decoders/encoders to preserve backward compatibility for old `width` and `height` keys.

### ComponentStyle
* **File Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Models/Domain/InvoiceComponentStyle.swift`
* **Description**: Contains styling and layout configurations for components, including:
  ```swift
  public var columnConfigurations: [Int: TableAxisConfiguration] = [:]
  public var rowConfigurations: [Int: TableAxisConfiguration] = [:]
  ```
  It has helper functions (defined in `InvoiceComponentStyle+Axis.swift`) to manipulate configurations:
  * `updateAxisSize(for:at:size:)`
  * `updateAxisIsFlexible(for:at:isFlexible:)`
  * `updateAxisAutoSizing(for:at:isAutoSized:)`
  * `initializeColumnConfigurations(for:)` / `initializeRowConfigurations(for:)`

### InvoiceDocument
* **File Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Models/Domain/InvoiceDocument.swift`
* **Description**: Authoritative document context managing the state, undo/redo registry, and template serialization. Sizing mutation APIs on `InvoiceDocument` include:
  ```swift
  func updateAxisSize(for id: UUID, axis: ComponentStyle.TableAxis, index: Int, size: CGFloat, actionName: String)
  func updateAxisIsFlexible(for id: UUID, axis: ComponentStyle.TableAxis, index: Int, isFlexible: Bool, actionName: String)
  func updateAxisAutoSizing(for id: UUID, axis: ComponentStyle.TableAxis, index: Int, isAutoSized: Bool, actionName: String)
  ```
  Each calls `saveStateForUndo` and then mutates style on the respective component by invoking the `ComponentStyle` extensions.

---

## 3. Sizing Inspector Views

The inspector views bind their UI pickers and steppers to configuration states via the `InvoiceDocument` APIs.

### Row & Column Sizing Sections in TableElementPropertyEditor
* **File Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/TableElementPropertyEditor+RowColumnSections.swift`
* **Key Views**:
  * `RowInspectorSectionView`: Features a segmented `Picker` bound to `AxisSizingMode` and an `InspectorStepper` bound to row `height` (enabled/visible only when height mode is `.fixed`).
  * `ColumnInspectorSectionView`: Features a segmented `Picker` bound to `AxisSizingMode` and an `InspectorStepper` bound to column `width` (disabled when mode is flexible/fit).

### Component Sizing Sections in ComponentPropertyEditor
* **File Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/ComponentPropertyEditor+Table.swift`
* **Key Sections**:
  * `tableColumnsContent(for:)`: Displays pickers for `ColumnWidthMode` and steppers for width points.
  * `tableRowsContent(for:)`: Displays pickers for `RowHeightMode` and steppers for height points.

---

## 4. Layout and Rendering Math

Authoritative sizing logic operates over a unified math helper rather than SwiftUI's layout pipeline.

### DocumentGridLayoutMath
* **File Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/DocumentGridLayoutMath.swift`
* **Algorithms**:
  * **Column Width Resolution** (`resolvedColumnWidths`):
    * If `isAutoSized` is true, width matches measured content width (`contentColumnWidths` derived via CoreText measurements) or fallback default (20 pt).
    * If fixed width exists, uses fixed value.
    * Leftover available width is evenly divided among `.flexible` columns.
    * If total width exceeds bounds, `clampColumnWidths` shrinks widths proportionally (shrinking flexible columns first, then auto-sized columns, then fixed columns).
  * **Row Height Resolution** (`resolvedRowHeights`):
    * If a row configuration is fixed (`isFlexible == false`, `isAutoSized == false`, size > 0), uses fixed height.
    * Otherwise, measures the CoreText heights of cells wrapping within the computed column widths. The row height is set to `max(maxCellHeight, rowConfig.size)`.
  * **CoreText Measurement** (`measureTextSize(_:width:lineLimit:)`):
    * Uses `CTFramesetterSuggestFrameSizeWithConstraints` to measure text size.
    * If `lineLimit` is specified, uses typographic bounds via `CTLineGetTypographicBounds` of lines up to the limit to determine height.

### DocumentGridContentHeight
* **File Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/DocumentGridLayout+Preferences.swift`
* **Algorithms**:
  * `reconciledGridHeight`: SwiftUI views report heights via `GeometryReader` preference keys. To prevent render-loop oscillations (collapsing or expanding to infinity), this function reconciles heights by prioritizing the CoreText-based `layoutMathHeight` from `DocumentGridLayoutMath` as the authoritative source of truth.
  ```swift
  static func reconciledGridHeight(
      cellMeasuredHeight: CGFloat,
      renderedHeight: CGFloat,
      layoutMathHeight: CGFloat = 0
  ) -> CGFloat {
      if layoutMathHeight > 0 {
          return layoutMathHeight
      }
      return max(cellMeasuredHeight, renderedHeight)
  }
  ```

### PDF/Export Sizing Integration
* **File Path**: `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Utilities/ExportService+DocumentGridRendering.swift`
* **Integration**: When exporting to PDF, `ExportService` calls `DocumentGridLayoutMath.resolvedColumnWidths` and `DocumentGridLayoutMath.resolvedRowHeights` to compute coordinates. This ensures that the generated PDF table dimensions precisely match the authoring editor grid canvas.

---

## 5. Sizing and Height Tests

Several test suites verify table height calculation and prevent sizing regressions:

1. **`DocumentGridHeightRegressionTests.swift`**:
   * Tests that table heights do not collapse to zero by asserting that the authoritative `layoutMathHeight` floor is used.
   * Verifies that the single-line row height estimate is font-size-aware rather than using a hardcoded `22pt` limit.
   * Asserts that `appliedFrameHeight` doesn't stretch tables to fill the entire leaf container when sizing mode is set to `.expand`.

2. **`DocumentGridHeightReliabilityTests.swift`**:
   * Evaluates text wrap limits, ensuring stable rendering when layout widths are restricted.

3. **`DocumentGridHeightWiringTests.swift`**:
   * Validates alignment of SwiftUI canvas rendering height and Core Graphics PDF exporting height calculations.

4. **`TableInspectorAdversarialTests.swift`**:
   * Verifies multi-row and multi-column selection mutations, boundary conditions (such as setting negative index configuration values), and fallback states.
