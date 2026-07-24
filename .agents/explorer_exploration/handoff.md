# Handoff Report: Table/Grid Sizing and Rendering Models

## 1. Observation

Direct observations made in the codebase:
1. **AxisSizingMode**: Located in `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/TableElementPropertyEditor+RowColumnSections.swift` at lines 6–10:
   ```swift
   private enum AxisSizingMode: String, CaseIterable {
       case flexible = "Flexible"
       case fit = "Fit"
       case fixed = "Fixed"
   }
   ```
2. **ColumnWidthMode & RowHeightMode**: Located in `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/ComponentPropertyEditor+Helpers.swift` at lines 86–96:
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
3. **TableAxisConfiguration**: Defined in `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Models/Domain/InvoiceComponentStyle+Axis.swift` starting at line 11:
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
   }
   ```
4. **ComponentStyle**: Defined in `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Models/Domain/InvoiceComponentStyle.swift` starting at line 6:
   ```swift
   public struct ComponentStyle: Codable, Hashable, Sendable {
       ...
       public var columnConfigurations: [Int: TableAxisConfiguration] = [:]
       public var rowConfigurations: [Int: TableAxisConfiguration] = [:]
       ...
   }
   ```
5. **InvoiceDocument**: Defined in `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Models/Domain/InvoiceDocument.swift` starting at line 16:
   ```swift
   public final class InvoiceDocument: @unchecked Sendable {
       ...
   }
   ```
   Mutations for axis config are defined from line 327 onward:
   ```swift
   func updateAxisSize(for id: UUID, axis: ComponentStyle.TableAxis, index: Int, size: CGFloat, actionName: String = "Resize Table Column/Row")
   func updateAxisIsFlexible(for id: UUID, axis: ComponentStyle.TableAxis, index: Int, isFlexible: Bool, actionName: String = "Change Column/Row Flexibility")
   func updateAxisAutoSizing(for id: UUID, axis: ComponentStyle.TableAxis, index: Int, isAutoSized: Bool, actionName: String = "Toggle Auto-Sizing")
   ```
6. **Views**: Sizing pickers and steppers exist in:
   * `TableElementPropertyEditor+RowColumnSections.swift` (segmented pickers for `AxisSizingMode`, steppers for points).
   * `ComponentPropertyEditor+Table.swift` (pickers for `ColumnWidthMode`/`RowHeightMode`, steppers for dimensions).
7. **Layout and Rendering Math**:
   * `DocumentGridLayoutMath` (located in `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/DocumentGridLayoutMath.swift`) contains `resolvedColumnWidths` (resolves flexible/fit/fixed columns) and `resolvedRowHeights` (resolves row heights using CoreText `measureTextSize` and typographic bounds measurements).
   * `DocumentGridContentHeight` (located in `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/DocumentGridLayout+Preferences.swift`) provides `reconciledGridHeight` to reconcile canvas measurements against `layoutMathHeight` to prevent layout collapse.
   * `ExportService+DocumentGridRendering.swift` (located in `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Utilities/ExportService+DocumentGridRendering.swift`) relies on `DocumentGridLayoutMath.resolvedColumnWidths` and `resolvedRowHeights` to compute coordinates for rendering table structures to the PDF context.

---

## 2. Logic Chain

1. **Enum Duplication**: Enums `AxisSizingMode`, `ColumnWidthMode`, and `RowHeightMode` are syntactically and semantically identical, but defined in separate scope contexts (one in inspector sections, others in helper files) to power different picker interfaces.
2. **Model Sizing State**: Under the hood, table columns and rows do not store these enums directly. Instead, `TableAxisConfiguration` maintains boolean states: `isFlexible` and `isAutoSized` to determine sizing modes (e.g. flexible vs fit vs fixed).
3. **Synchronization**: The segmented pickers and drop-downs map their selected enum values (`flexible`, `fit/autoSize`, `fixed`) to document mutations. For example, selecting `.flexible` sets `isFlexible = true` and `isAutoSized = false` on `TableAxisConfiguration` via `InvoiceDocument` style update commands.
4. **Calculations Alignment**: The live template editor canvas (SwiftUI `DocumentGridView`) and the PDF rendering pipeline (`ExportService`) both consume the same `DocumentGridLayoutMath` functions (`resolvedColumnWidths`, `resolvedRowHeights`). By sharing this module, rendering dimensions are consistent during export.
5. **Reconciliation and Testing**: SwiftUI layout is subject to multiple passes that can trigger height collapse. The preference system uses the CoreText calculation from `DocumentGridLayoutMath` as an authoritative height floor. This mechanism is validated by test files `DocumentGridHeightRegressionTests.swift` and `TableInspectorAdversarialTests.swift`.

---

## 3. Caveats

1. The investigation did not cover the integration of CloudKit sync or data persistence mechanisms, nor did it examine actual database migrations of `InvoiceDocument`.
2. Assumed that CoreText rendering math is correct since tests pass.
3. Did not investigate layout behaviour on devices other than macOS.

---

## 4. Conclusion

The `InvoicingApplication` codebase is ready for unified refactoring. The duplicate enums (`AxisSizingMode`, `ColumnWidthMode`, `RowHeightMode`) should be replaced by a single, unified `TableSizingMode` enum bound directly to `TableAxisConfiguration` properties. The rendering pipeline and the SwiftUI view context are safely decoupled from direct UI bindings and rely on `DocumentGridLayoutMath` for sizing computations.

---

## 5. Verification Method

To verify the findings independently:
1. View the exact definitions and references in the codebase:
   * Check `TableElementPropertyEditor+RowColumnSections.swift` for `AxisSizingMode`.
   * Check `ComponentPropertyEditor+Helpers.swift` for `ColumnWidthMode` and `RowHeightMode`.
   * Check `DocumentGridLayoutMath.swift` to inspect `resolvedColumnWidths` and `resolvedRowHeights`.
2. Run the test targets:
   ```bash
   swift test --package-path Packages/Feature.InvoiceTemplateEditor
   ```
   All test cases in `DocumentGridHeightRegressionTests`, `DocumentGridHeightReliabilityTests`, `DocumentGridHeightWiringTests`, and `TableInspectorAdversarialTests` must pass successfully.
