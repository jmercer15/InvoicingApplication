## 2026-06-23T23:50:53Z
Identity: teamwork_preview_worker
Working Directory: /Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/worker_table_inspector
Parent Conversation ID: 894ee8a2-e257-411f-8c55-291d61d4d198

Mission:
Implement the Table and Table-Cell Inspector UX improvements based on the design blueprint in `/Users/user/Developer/InvoicingApplication/InvoicingApplication/.agents/orchestrator_table_inspector/synthesis.md`.

Scope of Modifications:
1. Model Layer:
   - Add `public var padding: CGFloat?` to `CellStyle` in `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Models/Domain/InvoiceComponentStyle+Axis.swift`. Add it to the initializer parameter list with default `nil` and set it.
   - Update `gridCellTextView` in `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/DocumentGridComponent+Styling.swift` to resolve padding override:
     `let resolvedPadding = cellOverride?.padding ?? (isHeader ? currentComponent.style.tableHeaderPadding : currentComponent.style.tableCellPadding)`
     Use `.padding(resolvedPadding)`.

2. View Layer:
   - In `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Components/DocumentGrid/AlignmentGridPicker.swift`:
     - Standardize token usage: remove AppKit `NSColor` references. Map to `Color.secondaryText` (or `StyleGuide.Colors.textSecondary`), `PanelShellTokens.panelSecondaryBackground`, `ColorSystem.Primary.blue` and standard color system tokens.
     - Embed selection count inside pickers or textfields instead of using hardcoded trailing offsets that clip on narrow layouts.
     - Refactor `AlignmentButton` to use a native SwiftUI `Button` with style `.buttonStyle(.plain)` so it is keyboard focusable and readable by VoiceOver. Add accessibility traits (isSelected).
     - Wrap the alignment grid in `InspectorGridCell` to align labels with other inspector controls.
     - Fix the center arrow down icon typo mapping for `(.trailing, .bottom)` to return `"fluent-ic_fluent_arrow_down_right_20_regular"`.
   - In `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/ComponentPropertyEditor.swift`:
     - Enable the new table accordion sections `.tableBorders` and `.tableShadow` in `makeDescriptor` for Category `table`.
   - In `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/ComponentPropertyEditor+Table.swift`:
     - Refactor `tableSectionDescriptors` to split table inspector into the 8 specialized accordion sections: Structure, Colors & Fills, Borders, Shadow, Typography, Rows, Columns, Section Title.
     - Remove selection-dependent columns/rows from Typography; make Typography global. Expose `lineLimit` in Row/Column sections instead.
     - Implement the borders accordion, exposing header borders, row separators, cell borders, and outer borders. Use computed `Binding<Color>` for row/header border colors to interface with hex strings correctly.
   - In `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/TableElementPropertyEditor.swift`:
     - Refactor `TableElementPropertyEditor` to consolidate cell selection details into "Text & Styling" and "Cell Layout & Sizing" sections.
     - Move "Reset Cell Styles" action to a toolbar button or top gear action instead of a full accordion section.
   - In `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/TableElementPropertyEditor+SelectionSection.swift`:
     - Update the Cell selection editor details: replace raw text inputs for rowHeight and colWidth with segmented pickers ("Flexible", "Auto-Size", "Fixed Width/Height") and points steppers (visible only in Fixed mode).
     - Implement the 3x3 visual alignment grid picker (`AlignmentGridPicker`).
     - Add the cell-specific padding override toggle and stepper.
   - In `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/TableElementPropertyEditor+RowColumnSections.swift`:
     - In Row and Column details views, disable and dim the dependent layout controls rather than hiding them dynamically, keeping vertical layout height stable and avoiding layout jitter.
     - Expose the Row/Column `lineLimit` settings.

3. Accessibility:
   - Ensure all text fields and steppers in modified inspector controls carry explicit accessibility labels.
   - Add `.accessibilityHidden(true)` to decorative/status icons.

Verification:
- Compile clean.
- Run tests: `swift test --package-path Packages/Feature.InvoiceTemplateEditor` and `bash scripts/refactor-verify.sh`.
- Ensure all tests pass.
