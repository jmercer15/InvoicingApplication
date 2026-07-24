# Table Element Inspector - Cell-Level UX Analysis & Proposal

This report provides a detailed analysis of the current SwiftUI implementation of the table, row, column, and cell selection inspector inside `Feature_InvoiceTemplateEditor`. It highlights UX gaps and proposes concrete structural and interface enhancements for cell-level property editing.

---

## 1. Current State Analysis

The inspector UI uses a selection-driven scheme. When an element in a table (or `DocumentGrid`) is selected, `TableElementPropertyEditor` displays inspector sections based on `TableElementSelection`:
*   `cell(row, col)` / `cellRange(rows, cols)`: displays **Text**, **Appearance**, **Dimensions**, and **Actions** sections.
*   `row(row)`: displays **Row** (Dimensions) section.
*   `column(col)`: displays **Dimensions** and **Appearance** sections.
*   `sectionTitle`: displays **Section Title** and **Typography** sections.

### Identified UX Gaps & Inconsistencies

1.  **Inconsistent Dimension Inputs (Text vs. Steppers)**:
    *   In the **Row** and **Column** inspectors, sizes are controlled via toggles (`flexible`, `autoSize`) and a stepper (`InspectorControl.stepper(...)`).
    *   In the **Cell/CellRange** inspector, sizing is exposed as raw text fields (`rowHeight`, `colWidth`) requiring manual typing. Steppers are missing, which breaks input parity.
2.  **Destructive Silent Sizing Behaviors**:
    *   Editing `rowHeight` or `colWidth` in the Cell Inspector silently disables row/column flexibility (`isFlexible = false`) and auto-sizing (`isAutoSized = false`), converting them to fixed widths/heights without visual feedback or warnings.
3.  **Missing Layout Mode Controls in Cell Selection**:
    *   A user editing properties from a cell selection has no way to change the layout behavior (Flexible vs. Auto-Size vs. Fixed) of the containing row or column. They must change selection mode to Row or Column to do so.
4.  **Clunky Alignment Configuration**:
    *   Cell text and vertical alignments are configured via two separate drop-down pickers containing text options ("Mixed/Auto", "leading", etc.). This is visually heavy and slower than a unified visual matrix.
5.  **Buried and Bloated Actions**:
    *   The "Reset Cell Styles" action takes up a whole expandable accordion section ("Actions"), wasting vertical workspace.
6.  **No Cell-Level Padding Overrides**:
    *   Padding is applied table-wide (`tableCellPadding` and `tableHeaderPadding`). Individual cell formatting (e.g. summary highlight cells) cannot override this spacing.

---

## 2. Proposed UX & UI Refinements

To resolve these issues and make the cell-level configuration more intuitive, compact, and powerful, we propose the following refinements:

### A. Compact Visual Alignment (3x3 Grid Matrix)
Instead of dual dropdown pickers, merge horizontal and vertical text alignment into a single visual **3x3 Alignment Grid Picker** (modeled after the existing `AlignmentGridPicker` used in column settings).
*   **Behavior**:
    *   Shows a visual grid of 9 positions.
    *   Supports mixed states (e.g., no buttons selected if the selection range contains mixed alignments).
    *   Reduces vertical space from two rows to a single compact block.

### B. Unified Sizing & Sizing Mode Controls
Replace the raw text inputs in the Cell Dimensions section with structured, mode-aware controls:
1.  **Width/Height Sizing Modes**: Introduce a segmented picker or drop-down for sizing modes: **Flexible** (shares remaining space), **Auto-Size** (fits content), or **Fixed**.
2.  **Conditional Steppers**: Display value steppers (with points suffix, e.g., `pt`) only when the "Fixed" mode is selected.
3.  **Explicit Multi-Selection Context**: Label the controls clearly with the number of affected rows/columns (e.g., "Columns (x3) Width").

### C. Cell-Level Padding Override
Introduce individual cell padding overrides to support fine-tuned styling (e.g., highlighting total columns or making specific columns more compact).
1.  **Data Structure**: Add an optional `padding: CGFloat?` property to `ComponentStyle.CellStyle`.
2.  **UI Control**: Under "Layout & Spacing", add a conditional toggle: "Override Table Padding" and an accompanying stepper (0 to 48 pt, step: 2) when active.

### D. Smart Context-Aware Headers
*   **Header Cell Indicator**: If the selected cell resides in a header row/column, change the subtitle or headers to indicate "Table Header Cell Properties".
*   **Summary/Total Row Presets**: For cells in the bottom-most row, display shortcut style presets (e.g., "Style as Total Row") that automatically toggle bold text, borders, or backgrounds.

### E. Consolidation of Accordion Sections
Merge the four current sections (`Text`, `Appearance`, `Dimensions`, `Actions`) into two logical groups to fit the sidebar without scroll fatigue:
1.  **Text & Styling**: Visual alignment grid, font size stepper, weight/transform pickers, text and background colors.
2.  **Cell Layout & Sizing**: Sizing modes, row/column dimensions, padding overrides, and line limits.
3.  **Header Actions**: Relocate the "Reset Styles" action to a compact gear/action toolbar at the top of the inspector panel, removing the "Actions" accordion entirely.

---

## 3. Proposed Structural SwiftUI Code Modifications

The following mock implementations show how the views can be structured to support these UX changes while preserving existing bindings and document update paths.

### A. Visual Sizing Mode & Stepper for Cell Dimensions
Here is the proposed update for the `dimensionControls` ViewBuilder inside `TableSelectionSectionView` (in `TableElementPropertyEditor+SelectionSection.swift`):

```swift
@ViewBuilder
private var dimensionControls: some View {
    let affectsMultipleRows = rows.count > 1
    let affectsMultipleCols = columns.count > 1
    
    InspectorGroupBox(
        title: "Dimensions", 
        icon: "fluent-ic_fluent_ruler_20_regular"
    ) {
        VStack(alignment: .leading, spacing: 12) {
            // --- Column Sizing Mode ---
            VStack(alignment: .leading, spacing: 4) {
                Text(affectsMultipleCols ? "Columns Sizing Mode (\(columns.count))" : "Column Sizing Mode")
                    .font(InspectorTypography.label)
                    .foregroundColor(.secondary)
                
                Picker("", selection: Binding(
                    get: {
                        let config = component.style.columnConfiguration(for: columns.lowerBound)
                        if config.isAutoSized { return "auto" }
                        if config.isFlexible { return "flexible" }
                        return "fixed"
                    },
                    set: { newMode in
                        document.updateComponentStyle(for: component.id, actionName: "Change Column Sizing Mode") { style in
                            for col in columns {
                                switch newMode {
                                case "flexible":
                                    style.updateAxisIsFlexible(for: .column, at: col, isFlexible: true)
                                case "auto":
                                    style.updateAxisAutoSizing(for: .column, at: col, isAutoSized: true)
                                default: // fixed
                                    style.updateAxisIsFlexible(for: .column, at: col, isFlexible: false)
                                    style.updateAxisAutoSizing(for: .column, at: col, isAutoSized: false)
                                }
                            }
                        }
                    }
                )) {
                    Text("Flexible").tag("flexible")
                    Text("Auto-Size").tag("auto")
                    Text("Fixed Width").tag("fixed")
                }
                .pickerStyle(.segmented)
            }
            
            // --- Column Width Stepper (Only visible if Fixed) ---
            if isColumnModeFixed {
                InspectorControlGroup {
                    InspectorControl.stepper(
                        "colWidth", 
                        icon: "fluent-ic_fluent_arrow_autofit_width_20_regular",
                        tooltip: "Width", 
                        value: Binding(
                            get: {
                                let widths = columns.map { component.style.columnConfiguration(for: $0).width }
                                return Double(widths.first ?? 100)
                            },
                            set: { val in
                                document.updateComponentStyle(for: component.id, actionName: "Resize Columns") { style in
                                    for col in columns {
                                        style.updateAxisSize(for: .column, at: col, size: CGFloat(val))
                                    }
                                }
                            }
                        ),
                        range: 20...1000, 
                        step: 5, 
                        suffix: "pt"
                    )
                }
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // --- Row Sizing Mode ---
            VStack(alignment: .leading, spacing: 4) {
                Text(affectsMultipleRows ? "Rows Sizing Mode (\(rows.count))" : "Row Sizing Mode")
                    .font(InspectorTypography.label)
                    .foregroundColor(.secondary)
                
                Picker("", selection: Binding(
                    get: {
                        let config = component.style.rowConfiguration(for: rows.lowerBound)
                        if config.isAutoSized { return "auto" }
                        if config.isFlexible { return "flexible" }
                        return "fixed"
                    },
                    set: { newMode in
                        document.updateComponentStyle(for: component.id, actionName: "Change Row Sizing Mode") { style in
                            for row in rows {
                                switch newMode {
                                case "flexible":
                                    style.updateAxisIsFlexible(for: .row, at: row, isFlexible: true)
                                case "auto":
                                    style.updateAxisAutoSizing(for: .row, at: row, isAutoSized: true)
                                default: // fixed
                                    style.updateAxisIsFlexible(for: .row, at: row, isFlexible: false)
                                    style.updateAxisAutoSizing(for: .row, at: row, isAutoSized: false)
                                }
                            }
                        }
                    }
                )) {
                    Text("Flexible").tag("flexible")
                    Text("Auto-Size").tag("auto")
                    Text("Fixed Height").tag("fixed")
                }
                .pickerStyle(.segmented)
            }
            
            // --- Row Height Stepper (Only visible if Fixed) ---
            if isRowModeFixed {
                InspectorControlGroup {
                    InspectorControl.stepper(
                        "rowHeight", 
                        icon: "fluent-ic_fluent_arrow_autofit_height_20_regular",
                        tooltip: "Height", 
                        value: Binding(
                            get: {
                                let heights = rows.map { component.style.rowConfiguration(for: $0).height }
                                return Double(heights.first ?? 40)
                            },
                            set: { val in
                                document.updateComponentStyle(for: component.id, actionName: "Resize Rows") { style in
                                    for row in rows {
                                        style.updateAxisSize(for: .row, at: row, size: CGFloat(val))
                                    }
                                }
                            }
                        ),
                        range: 15...1000, 
                        step: 5, 
                        suffix: "pt"
                    )
                }
            }
        }
    }
}

// Helper computed properties to determine layout modes
private var isColumnModeFixed: Bool {
    let config = component.style.columnConfiguration(for: columns.lowerBound)
    return !config.isFlexible && !config.isAutoSized
}

private var isRowModeFixed: Bool {
    let config = component.style.rowConfiguration(for: rows.lowerBound)
    return !config.isFlexible && !config.isAutoSized
}
```

### B. Visual Alignment Grid Incorporation
Replacing text pickers with a visual 3x3 alignment matrix:

```swift
@ViewBuilder
private var textControls: some View {
    InspectorGroupBox(title: "Text & Alignment", icon: "fluent-ic_fluent_text_font_20_regular") {
        VStack(spacing: 12) {
            // Visual Alignment Matrix
            AlignmentGridPicker(
                label: "Cell Alignment",
                horizontalAlignment: Binding(
                    get: { currentStyle?.alignment ?? .leading },
                    set: { alignment in
                        updateStyle(actionName: "Change Text Alignment") {
                            $0.alignment = alignment
                        }
                    }
                ),
                verticalAlignment: Binding(
                    get: { currentStyle?.verticalAlignment ?? .center },
                    set: { vAlign in
                        updateStyle(actionName: "Change Vertical Alignment") {
                            $0.verticalAlignmentOption = VerticalAlignmentOption(verticalAlignment: vAlign)
                        }
                    }
                )
            )
            
            Divider()
                .padding(.vertical, 4)
            
            // Standard Text Formatting Controls
            InspectorGrid {
                InspectorControl.stepper(
                    "fontSize", 
                    icon: "fluent-ic_fluent_font_increase_20_regular",
                    tooltip: "Font Size", 
                    value: Binding(
                        get: { Double(currentStyle?.fontSize ?? component.style.fontSize) },
                        set: { updateStyle(actionName: "Change Font Size") { $0.fontSize = CGFloat($0) } }
                    ),
                    range: 6...72, 
                    step: 1, 
                    suffix: "pt"
                )
                
                InspectorControl.colorPicker(
                    "textColor", 
                    icon: "fluent-ic_fluent_text_color_20_regular",
                    tooltip: "Text Color", 
                    selection: Binding(
                        get: { Color(hex: currentStyle?.textColor ?? component.style.textColor) },
                        set: { updateStyle(actionName: "Change Text Color") { $0.textColor = $0.toHex() } }
                    )
                )
                
                InspectorControl.picker(
                    "fontWeight", 
                    icon: "fluent-ic_fluent_text_bold_20_regular",
                    tooltip: "Font Weight", 
                    selection: binding(for: \.fontWeight, actionName: "Change Font Weight")
                ) {
                    Text("Default").tag(Optional<String>.none)
                    Text("Regular").tag(Optional("regular"))
                    Text("Medium").tag(Optional("medium"))
                    Text("Bold").tag(Optional("bold"))
                }
            }
        }
    }
}
```

### C. Proposed Cell-Level Padding Overrides
Adding custom cell padding toggle and stepper controls to `TableSelectionSectionView` (under Appearance/Layout):

```swift
@ViewBuilder
private var layoutSpacingControls: some View {
    InspectorGroupBox(title: "Spacing & Layout", icon: "fluent-ic_fluent_padding_down_20_regular") {
        InspectorGrid {
            // Padding Override Toggle
            InspectorControl.toggle(
                "overridePadding", 
                icon: "fluent-ic_fluent_padding_top_20_regular",
                tooltip: "Override Padding",
                isOn: Binding(
                    get: { currentStyle?.padding != nil },
                    set: { isOverriding in
                        updateStyle(actionName: "Toggle Padding Override") {
                            $0.padding = isOverriding ? component.style.tableCellPadding : nil
                        }
                    }
                )
            )
            
            // Conditional Padding Stepper
            if let cellPadding = currentStyle?.padding {
                InspectorControl.stepper(
                    "cellPaddingOverride", 
                    icon: "fluent-ic_fluent_padding_down_20_regular",
                    tooltip: "Cell Padding", 
                    value: Binding(
                        get: { Double(cellPadding) },
                        set: { newVal in
                            updateStyle(actionName: "Change Cell Padding Override") {
                                $0.padding = CGFloat(newVal)
                            }
                        }
                    ),
                    range: 0...48, 
                    step: 2, 
                    suffix: "pt"
                )
            }
            
            // Line Limit Stepper
            InspectorControl.stepper(
                "lineLimit", 
                icon: "fluent-ic_fluent_line_style_20_regular",
                tooltip: "Line Limit", 
                value: Binding(
                    get: { Double(currentStyle?.lineLimit ?? 1) },
                    set: { newVal in
                        updateStyle(actionName: "Change Line Limit") {
                            $0.lineLimit = Int(newVal)
                        }
                    }
                ),
                range: 1...10, 
                step: 1, 
                suffix: " lines"
            )
        }
    }
}
```

---

## 4. Integration & Alignment with Existing Frameworks

1.  **Action Dispatching & Redo/Undo History**:
    All the proposed controls bind directly to `document.updateComponentStyle(for:actionName:update:)` or existing helper methods on `InvoiceDocument`. This guarantees complete compatibility with the app's action-undo manager and avoids breaking document-level state syncing.
2.  **Unified Styling Engines**:
    Since `DocumentGridComponent+Styling` already resolves cell styles using `currentComponent.style.cellStyle(row: row, col: col)` with fallback hierarchies (Cell Override -> Row/Col Defaults -> Table Defaults), adding cell-level padding overrides fits cleanly. The rendering layout can resolve the cell padding:
    ```swift
    let resolvedPadding = cellOverride?.padding ?? (isHeader ? style.tableHeaderPadding : style.tableCellPadding)
    ```
3.  **UI Consistency**:
    Aligning the cell-level dimension steppers and picker styles with the table-wide and column-wide builders simplifies the inspector controls system, allowing easier code sharing and a uniform visual interface for the user.
