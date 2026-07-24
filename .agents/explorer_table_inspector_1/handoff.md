# Handoff Report — explorer_table_inspector_1

## 1. Observation

We directly observed and verified the following files and code blocks:

* **Global Table-Level Properties**: In `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/ComponentPropertyEditor+Table.swift:145-250`, the typography block features:
  * A picker for "Selection" (Column/Row) mapping to `typographyTabSelection[component.id]`.
  * Controls for global variables: `currentComponent.style.fontFamily` (line 178), `currentComponent.style.fontSize` (line 193), `currentComponent.style.fontWeight` (line 203), `currentComponent.style.lineSpacing` (line 221), and `currentComponent.style.letterSpacing` (line 231).
  * An index-specific control for `lineLimit` (lines 237-248):
    ```swift
    InspectorControl.stepper("lineLimit", icon: "fluent-ic_fluent_text_align_left_20_regular",
                            tooltip: "Line Limit", value: Binding(
                                get: { Double(isHorizontal ? columnConfig.lineLimit : rowConfig.lineLimit) },
                                set: { value in
                                    if isHorizontal {
                                        document.updateAxisLineLimit(for: component.id, axis: .column, index: selectedIndex, lineLimit: Int(value))
                                    } else {
                                        document.updateAxisLineLimit(for: component.id, axis: .row, index: selectedIndex, lineLimit: Int(value))
                                    }
                                }
                            ), range: 1...10, step: 1, suffix: "")
    ```
* **Borders and Shadows in Appearance Section**: In `ComponentPropertyEditor+Table.swift:53-101`, `tableAppearanceContent` groups "Colors" (line 57), "Borders" (line 84), and calls `shadowControls(for: component)` (line 100) all under the `.tableFill` inspector section.
* **Hidden Model Properties**: In `Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Models/Domain/InvoiceComponentStyle.swift:56-67`, the model defines several layout/grid variables which are not used in `ComponentPropertyEditor+Table.swift`:
  * `showHeaderBorder: Bool`
  * `tableHeaderBorderWidth: CGFloat`
  * `tableHeaderBorderColor: String`
  * `showRowBorders: Bool`
  * `tableRowBorderWidth: CGFloat`
  * `tableRowBorderColor: String`
  * `showCellBorders: Bool`
* **Lack of Footer Storage**: In `InvoiceComponentStyle.swift`, there are no fields containing the word `footer`.

---

## 2. Logic Chain

1. **Decoupling Row/Column Settings from Global Settings**: Since the `fontFamily`, `fontSize`, `fontWeight`, `lineSpacing`, and `letterSpacing` controls inside `tableTypographyContent` modify the table styling globally (affecting the entire table component), placing a column/row picker directly above them implies to the user that these font settings are index-specific. Since only `lineLimit` is index-specific, moving `lineLimit` into the dedicated Column/Row inspector views (`tableColumnsContent`, `tableRowsContent`, and their element-level equivalents) allows the global Typography section to be cleaned up, removing the column/row picker entirely and making the controls unambiguous.
2. **Improving Scroll View Heights**: Splitting the "Appearance" section (which contains Colors, Borders, and Shadow) into separate collapsible sections (`.tableFill`, `.tableBorders`, and `.tableShadow`) directly reduces the expanded height of any single accordion block, resolving scrolling clutter.
3. **Enhancing Design Flexibility**: Exposing the 7 hidden model properties for row borders, header separators, and grid lines directly gives users full control over table borders without altering the SwiftData model/schema.
4. **Providing Footer Roadmap**: Footers can be supported in the future by adding footer style variables to `ComponentStyle` and exposing them within the proposed structure.

---

## 3. Caveats

* We did not compile the code as this is a read-only explorer subtask. However, all proposed SwiftUI code snippet bindings were verified to map directly to existing variables inside `ComponentStyle` and methods inside `InvoiceDocument` (e.g., `updateAxisLineLimit`).
* `tableRowBorderColor` does not have a computed `Color` property (`tableRowBorderColorSwiftUI`) in `ComponentStyle`. Therefore, we designed a custom binding directly converting the hex string `tableRowBorderColor` to `Color` and writing the hex value back using `document.updateComponentStyle`.

---

## 4. Conclusion

The current table property inspector suffers from minor UX layout issues (very tall sections, confusing column/row selector in the global typography panel) and has functional disparities (defines, but does not expose, grid border configurations). 

By splitting the inspector into 8 focused sections, relocating the line limit controls to the row/column sub-panels, and exposing the underlying border model variables, we can make the property editor significantly more intuitive and feature-rich.

---

## 5. Verification Method

To verify these changes after they are implemented by an implementer:
1. Open the Invoicing Application workspace.
2. Select a Table component.
3. Verify the inspector renders the following separate accordions: "Structure", "Colors & Appearance", "Borders", "Shadow", "Typography", "Columns", "Rows", and "Section Title".
4. Expand "Typography" and verify there is no Row/Column selector picker. Verify changing Font Family/Size updates the entire table.
5. Expand "Columns" and choose "Column 1". Adjust "Line Limit" and verify it restricts the column content without affecting the global typography.
6. Verify "Borders" accordion displays Outer Borders, Header Separators, Row Separators, and Inner Grid lines. Toggle and color them, and confirm changes render on the canvas.
7. Run the project tests to ensure no regressions:
   `swift test --package-path Packages/Feature.InvoiceTemplateEditor`
