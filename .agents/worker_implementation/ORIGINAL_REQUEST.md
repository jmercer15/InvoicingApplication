## 2026-06-30T04:00:47Z
Your role is Sizing Fix Developer.
Your working directory is /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_implementation/.
Your parent is orchestrator_shrink_sizing (ID: 8e568e22-0bdd-407d-8203-48c08720e563).
Your task is to fix the layout bug where DocumentGrid components expand past combined dimensions under all-shrink sizing.

Follow these steps exactly:
1. Modify `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Support/LeafComponentFrameSizing.swift`:
   In `intrinsicHorizontalSize(for:)`, add a check at the very beginning of the function:
   ```swift
   if component.usesTableProperties, component.usesContentDrivenColumnWidths, let minWidth = component.minIntrinsicWidth, minWidth > 0 {
       return minWidth
   }
   ```
2. Modify `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/DocumentGridComponent.swift`:
   In `appliedFrameWidth`, insert a check at the very beginning of the getter:
   ```swift
   if currentComponent.usesContentDrivenColumnWidths {
       let intrinsicWidth = resolvedGridLayoutWidth()
       if intrinsicWidth > 0 {
           if let leafWidth = leafContainerSize?.width, leafWidth > 0 {
               return min(intrinsicWidth, leafWidth)
           }
           return intrinsicWidth
       }
   }
   ```
3. Modify `Packages/Feature.InvoiceTemplateEditor/Tests/Feature_InvoiceTemplateEditorTests/DocumentGridLayoutMathTests.swift`:
   Add the following unit test method:
   ```swift
   func testAllShrinkAxesProduceIntrinsicLayoutEqualToCellDimensionsSum() {
       var style = ComponentStyle()
       style.tableCellPadding = 5.0
       
       // 2 Columns, both AutoSized (.fit)
       style.updateTableSizingMode(for: .column, at: 0, sizingMode: .fit)
       style.updateTableSizingMode(for: .column, at: 1, sizingMode: .fit)
       
       // 2 Rows, both AutoSized (.fit)
       style.updateTableSizingMode(for: .row, at: 0, sizingMode: .fit)
       style.updateTableSizingMode(for: .row, at: 1, sizingMode: .fit)
       
       let data: [[DocumentTableItem]] = [
           [
               DocumentTableItem(content: "Col0Row0", rowIndex: 0, columnIndex: 0),
               DocumentTableItem(content: "Col1Row0", rowIndex: 0, columnIndex: 1)
           ],
           [
               DocumentTableItem(content: "Col0Row1", rowIndex: 1, columnIndex: 0),
               DocumentTableItem(content: "Col1Row1", rowIndex: 1, columnIndex: 1)
           ]
       ]
       
       // Measure columns
       let columnCount = 2
       let measuredWidths = DocumentGridLayoutMath.measureColumnContentWidths(
           data: data,
           style: style,
           columnCount: columnCount
       )
       
       // Verify resolved column widths are exactly the intrinsic content widths
       let resolvedWidths = DocumentGridLayoutMath.resolvedColumnWidths(
           columnConfigs: [.autoSized(), .autoSized()],
           contentColumnWidths: measuredWidths,
           totalWidth: 9999.0
       )
       
       let expectedCol0Width = measuredWidths[0] ?? 20.0
       let expectedCol1Width = measuredWidths[1] ?? 20.0
       XCTAssertEqual(resolvedWidths, [expectedCol0Width, expectedCol1Width])
       
       // Verify resolved row heights are exactly the intrinsic heights
       let resolvedHeights = DocumentGridLayoutMath.resolvedRowHeights(
           data: data,
           style: style,
           columnWidths: resolvedWidths
       )
       XCTAssertEqual(resolvedHeights.count, 2)
       XCTAssertGreaterThan(resolvedHeights[0], 0)
       XCTAssertGreaterThan(resolvedHeights[1], 0)
   }
   ```
4. Build the scheme "InvoicingApplication" for platform macOS and verify that it compiles successfully.
5. Run the unit tests via `swift test --package-path Packages/Feature.InvoiceTemplateEditor` and confirm all 187 tests pass cleanly.
6. Write your handoff report to `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_implementation/handoff.md` and report back.
