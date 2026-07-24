## 2026-06-28T13:19:23Z

Refactor the document grid component row/column sizing mode logic:

1. Define TableSizingMode enum:
   In Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Models/Domain/InvoiceComponentStyle+Axis.swift, define:
   ```swift
   public enum TableSizingMode: String, Codable, CaseIterable, Sendable {
       case flexible = "Flexible"
       case fit = "Fit"
       case fixed = "Fixed"
   }
   ```
   Add computed property `sizingMode` (of type `TableSizingMode`) to `TableAxisConfiguration`. It should get/set `isFlexible` and `isAutoSized` to map correctly to/from `TableSizingMode` cases.
   Replace `updateAxisIsFlexible` and `updateAxisAutoSizing` on `ComponentStyle` with:
   ```swift
   mutating func updateTableSizingMode(for axis: TableAxis, at index: Int, sizingMode: TableSizingMode) {
       var config = configuration(for: axis, at: index)
       config.sizingMode = sizingMode
       setConfiguration(config, for: axis, at: index)
   }
   ```

2. Update InvoiceDocument:
   In Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Models/Domain/InvoiceDocument.swift, remove `updateAxisIsFlexible` and `updateAxisAutoSizing`. Add:
   ```swift
   func updateTableSizingMode(for id: UUID, axis: ComponentStyle.TableAxis, index: Int, sizingMode: TableSizingMode, actionName: String = "Change Sizing Mode") {
       saveStateForUndo(actionName: actionName)
       updateComponent(id: id) { component in
           component.style.updateTableSizingMode(for: axis, at: index, sizingMode: sizingMode)
       }
   }
   ```

3. Update DefaultInvoiceTemplate:
   In Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Models/Domain/DefaultInvoiceTemplate.swift, update line 299 to use `style.updateTableSizingMode(for: .column, at: index, sizingMode: .flexible)`.

4. Update Views:
   - In Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/ComponentPropertyEditor+Helpers.swift: Remove `ColumnWidthMode` and `RowHeightMode` enums completely.
   - In Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/ComponentPropertyEditor+Table.swift: Replace pickers referencing `ColumnWidthMode` and `RowHeightMode` to use `TableSizingMode`. Use `document.updateTableSizingMode`.
   - In Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/TableElementPropertyEditor+RowColumnSections.swift: Remove `AxisSizingMode`. Bind pickers to `TableSizingMode` and use `document.updateTableSizingMode`.
   - In Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/TableElementPropertyEditor+SelectionSection.swift: Remove the local `SizingMode` enum. Update `selectedRowsHeightMode`, `selectedColsWidthMode`, `setRowsHeightMode`, and `setColsWidthMode` to use `TableSizingMode` and `updateTableSizingMode`. Bind selection pickers to `TableSizingMode`.

5. Update Tests:
   Update calls in tests to use `updateTableSizingMode` / `TableSizingMode`:
   - `DocumentGridHeightRegressionTests.swift`
   - `DocumentGridHeightReliabilityTests.swift`
   - `TableInspectorAdversarialTests.swift`

6. Compile and test:
   Run: `swift test --package-path Packages/Feature.InvoiceTemplateEditor`
   Ensure all tests compile cleanly and pass.
