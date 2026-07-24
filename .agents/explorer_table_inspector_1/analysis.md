# Table Inspector UI/UX Analysis & Proposal

This report analyzes the current SwiftUI implementation of table-level property editing in `Feature_InvoiceTemplateEditor` and proposes UX improvements to eliminate layout confusion, expose hidden style properties, and streamline the editing workflow.

---

## Executive Summary

1. **Cluttered & Opaque Layouts**: The "Appearance" accordion bundles Colors, Borders, and Shadows together, creating a vertical scrolling bottleneck. 
2. **Typography Misdirection**: A "Selection" picker in the Typography section implies that Font Family, Size, and Weight can be applied to individual columns/rows. In reality, they are table-wide settings; only "Line Limit" is index-specific.
3. **Hidden Model Capabilities**: The `ComponentStyle` model supports advanced grid configurations (header borders, row separators, inner cell dividers) that are currently hidden from the UI.
4. **Proposed Structure**: We propose splitting table property editing into **8 specialized accordion sections**, decoupling index-specific controls from global settings, and exposing all underlying model properties.

---

## Detailed Analysis of Current Implementation

### 1. The Typography Selection Scope Issue
In `ComponentPropertyEditor+Table.swift:145-250`, the `tableTypographyContent` function renders a selection picker when multiple rows or columns exist:
* **The Issue**: A user selecting "Column 1" expects typography settings (e.g., Font Family, Size, Weight) to apply to Column 1. Instead, they apply to the **entire table**. The only setting that respects the selection index is **Line Limit**.
* **Impact**: Highly confusing and frustrating UX. Users attempt to style single columns only to see the entire table change.

### 2. Collapsing Massive Sections
The `.tableFill` section is labeled "Appearance". It currently wraps:
* **Colors GroupBox**: Table text color, row background fill, alternating rows + alt fill, header text color + header fill.
* **Borders GroupBox**: Outer borders toggle, color, and width.
* **Shadow GroupBox**: Shadow toggle, color, opacity, offsets, and radius.
* **Impact**: When all sub-options are active, the accordion expands to over **400 points** in height, forcing secondary controls off-screen.

### 3. Hidden Table Properties
The `ComponentStyle` model (`InvoiceComponentStyle.swift`) defines several properties that are completely omitted from the inspector UI:
* `showHeaderBorder` (Bool), `tableHeaderBorderWidth` (CGFloat), `tableHeaderBorderColor` (String)
* `showRowBorders` (Bool), `tableRowBorderWidth` (CGFloat), `tableRowBorderColor` (String)
* `showCellBorders` (Bool) (for inner grid lines)
* **Impact**: Users cannot control inner table gridlines or row/header separators, leaving the table design feeling rigid.

---

## Proposed UI/UX Reorganization

To make the panel intuitive, we propose organizing table property editing into the following **8 collapsible sections**:

| Section Name | Identifier | Content & Controls |
| :--- | :--- | :--- |
| **Structure** | `.tableLayoutStructure` | Table direction, headers presence, cell & header padding. |
| **Colors & Fills** | `.tableFill` | Cell fill, alternating row colors, header fill. |
| **Grid & Borders** | `.tableBorders` | Outer borders, row separators, header separators, inner cell borders. |
| **Shadow** | `.tableShadow` | Table shadow toggle, color, opacity, offsets, radius. |
| **Typography** | `.tableTypography` | Global font family, size, weight, line/letter spacing. (No column/row picker!). |
| **Columns** | `.tableColumns` | Column selection, width mode, fixed width, alignment, and **Column Line Limit**. |
| **Rows** | `.tableRows` | Row selection, height mode, fixed height, and **Row Line Limit**. |
| **Section Title** | `.sectionTitle` | Optional section title string, alignment, and title typography. |

---

## SwiftUI Implementation Blueprint

### 1. Enabling New Accordion Sections in `ComponentPropertyEditor.swift`
Update the section mapping to include `.tableBorders` and `.tableShadow` as distinct inspector cases:

```swift
// Packages/Feature.InvoiceTemplateEditor/Sources/Feature_InvoiceTemplateEditor/Views/Inspector/ComponentPropertyEditor.swift

// In makeDescriptor(section:component:category:capabilities:)
case .tableLayoutStructure where category == .table && capabilities.showsTableSection,
     .tableFill where category == .table && capabilities.showsTableSection,
     .tableBorders where category == .table && capabilities.showsTableSection,
     .tableShadow where category == .table && capabilities.showsTableSection,
     .tableTypography where category == .table && capabilities.showsTableSection,
     .tableColumns where category == .table && capabilities.showsTableSection,
     .tableRows where category == .table && capabilities.showsTableSection,
     .sectionTitle where category == .table && capabilities.showsTableSection:
    return tableSectionDescriptors(for: component).first { $0.section == section }
```

And update `tableSectionDescriptors(for:)` in `ComponentPropertyEditor+Table.swift`:

```swift
func tableSectionDescriptors(for component: InvoiceComponent) -> [InspectorSectionDescriptor<InspectorSection>] {
    let sections: [(InspectorSection, String, () -> AnyView)] = [
        (.tableLayoutStructure, "Structure", { AnyView(self.tableStructureContent(for: component)) }),
        (.tableFill, "Appearance", { AnyView(self.tableAppearanceContent(for: component)) }),
        (.tableBorders, "Borders", { AnyView(self.tableBordersContent(for: component)) }),
        (.tableShadow, "Shadow", { AnyView(self.tableShadowContent(for: component)) }),
        (.tableTypography, "Typography", { AnyView(self.tableTypographyContent(for: component)) }),
        (.tableRows, "Rows", { AnyView(self.tableRowsContent(for: component)) }),
        (.tableColumns, "Columns", { AnyView(self.tableColumnsContent(for: component)) }),
        (.sectionTitle, "Section Title", { AnyView(self.sectionTitleContent(for: component)) })
    ]
    return sections.map { section, title, builder in
        InspectorSectionDescriptor(
            section: section,
            title: title,
            alwaysExpanded: false,
            isVisible: true,
            buildContent: builder
        )
    }
}
```

---

### 2. Decoupling Global Typography & Axis Line Limits

#### Cleaned Typography Section (Strictly Global)
The "Selection" group box and column/row selection bindings are completely removed. `tableTypographyContent` becomes:

```swift
@ViewBuilder
func tableTypographyContent(for component: InvoiceComponent) -> some View {
    let currentComponent = document.component(component.id) ?? component
    
    InspectorGroupBox(title: "Font", icon: "fluent-ic_fluent_text_font_20_regular") {
        InspectorGrid {
            InspectorControl.picker("fontFamily", icon: "fluent-ic_fluent_text_20_regular",
                                   tooltip: "Font Family", selection: Binding(
                get: { FontFamilyOption(styleValue: currentComponent.style.fontFamily) },
                set: { newValue in 
                    document.updateComponentStyle(for: component.id, actionName: "Change Font Family") { style in 
                        style.fontFamily = newValue.styleValue 
                    } 
                }
            )) {
                ForEach(FontFamilyOption.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }
            
            InspectorControl.stepper("fontSize", icon: "fluent-ic_fluent_font_increase_20_regular",
                                    tooltip: "Font Size", value: Binding(
                                        get: { Double(currentComponent.style.fontSize) },
                                        set: { newValue in 
                                            document.updateComponentStyle(for: component.id, actionName: "Change Font Size") { style in 
                                                style.fontSize = CGFloat(newValue) 
                                            } 
                                        }
                                    ), range: 6...72, step: 1, suffix: "pt")
            
            InspectorControl.picker("fontWeight", icon: "fluent-ic_fluent_text_bold_20_regular",
                                   tooltip: "Font Weight", selection: Binding(
                get: { FontWeightOption(styleValue: currentComponent.style.fontWeight) },
                set: { newValue in 
                    document.updateComponentStyle(for: component.id, actionName: "Change Font Weight") { style in 
                        style.fontWeight = newValue.styleValue 
                    } 
                }
            )) {
                ForEach(FontWeightOption.allCases, id: \.self) { option in
                    Text(option.displayName).tag(option)
                }
            }
        }
    }

    InspectorGroupBox(title: "Spacing", icon: "fluent-ic_fluent_text_description_20_regular") {
        InspectorGrid {
            InspectorControl.stepper("lineSpacing", icon: "fluent-ic_fluent_text_baseline_20_regular",
                                    tooltip: "Line Spacing", value: Binding(
                                        get: { Double(currentComponent.style.lineSpacing) },
                                        set: { newValue in 
                                            document.updateComponentStyle(for: component.id, actionName: "Change Line Spacing") { style in 
                                                style.lineSpacing = CGFloat(newValue) 
                                            } 
                                        }
                                    ), range: 0.8...3.0, step: 0.1, suffix: "x", format: .decimal(places: 1))
            
            InspectorControl.stepper("letterSpacing", icon: "fluent-ic_fluent_font_space_tracking_in_20_regular",
                                    tooltip: "Letter Spacing", value: Binding(
                                        get: { Double(currentComponent.style.letterSpacing) },
                                        set: { newValue in 
                                            document.updateComponentStyle(for: component.id, actionName: "Change Letter Spacing") { style in 
                                                style.letterSpacing = CGFloat(newValue) 
                                            } 
                                        }
                                    ), range: -2...10, step: 0.5, suffix: "pt", format: .decimal(places: 1))
        }
    }
}
```

#### Relocating Line Limit to Column Inspector Section
```swift
// In tableColumnsContent(for component: InvoiceComponent):
InspectorGroupBox(title: "Dimensions", icon: "fluent-ic_fluent_arrow_expand_20_regular") {
    InspectorGrid {
        // ... (widthMode, fixed width settings) ...
        
        InspectorControl.stepper("lineLimit", icon: "fluent-ic_fluent_text_align_left_20_regular",
                                tooltip: "Line Limit", value: Binding(
                                    get: { Double(columnConfig.lineLimit) },
                                    set: { document.updateAxisLineLimit(for: component.id, axis: .column, index: selectedIndex, lineLimit: Int($0)) }
                                ), range: 1...10, step: 1, suffix: "")
    }
}
```

#### Relocating Line Limit to Row Inspector Section
```swift
// In tableRowsContent(for component: InvoiceComponent):
InspectorGroupBox(title: "Dimensions", icon: "fluent-ic_fluent_arrow_expand_20_regular") {
    InspectorGrid {
        // ... (heightMode, fixed height settings) ...
        
        InspectorControl.stepper("lineLimit", icon: "fluent-ic_fluent_text_align_left_20_regular",
                                tooltip: "Line Limit", value: Binding(
                                    get: { Double(rowConfig.lineLimit) },
                                    set: { document.updateAxisLineLimit(for: component.id, axis: .row, index: selectedIndex, lineLimit: Int($0)) }
                                ), range: 1...10, step: 1, suffix: "")
    }
}
```

For consistency, also add the row/column line limit controls to the element-level selection editor inside `TableElementPropertyEditor+RowColumnSections.swift` under the `RowInspectorSectionView` and `ColumnInspectorSectionView` details.

---

### 3. Exposing Hidden Border Capabilities
Create a dedicated `tableBordersContent(for:)` function exposing outer borders, header separator borders, row dividers, and cell gridlines.

Because `tableRowBorderColorSwiftUI` is not defined in `ComponentStyle`, use direct computed `Binding<Color>` helpers to perform the conversions and update the model:

```swift
@ViewBuilder
func tableBordersContent(for component: InvoiceComponent) -> some View {
    let factory = ComponentInspectorControlFactory(component: component, document: document)
    
    // 1. Outer Border Group
    InspectorGroupBox(title: "Outer Border", icon: "fluent-ic_fluent_border_outside_20_regular") {
        InspectorControlGroup {
            factory.toggle("showBorders", keyPath: \.showTableBorders, icon: "fluent-ic_fluent_checkmark_circle_20_regular",
                          tooltip: "Show Outer Borders")
            
            if component.style.showTableBorders {
                tableColorControl("borderColor", hexKeyPath: \.tableBorderColor, swiftUIKeyPath: \.tableBorderColorSwiftUI,
                                 icon: "fluent-ic_fluent_color_line_20_regular", tooltip: "Outer Border Color", component: component)
                
                factory.stepper("borderWidth", keyPath: \.tableBorderWidth, icon: "fluent-ic_fluent_line_thickness_20_regular",
                               tooltip: "Outer Border Width", range: 0.5...10, step: 0.5, suffix: "pt", format: .decimal(places: 1))
            }
        }
    }
    
    // 2. Header Separator Group
    if component.style.showTableHeader {
        InspectorGroupBox(title: "Header Separator", icon: "fluent-ic_fluent_border_top_bottom_20_regular") {
            InspectorControlGroup {
                factory.toggle("showHeaderBorder", keyPath: \.showHeaderBorder, icon: "fluent-ic_fluent_checkmark_circle_20_regular",
                              tooltip: "Show Header Separator")
                
                if component.style.showHeaderBorder {
                    tableColorControl("headerBorderColor", hexKeyPath: \.tableHeaderBorderColor, swiftUIKeyPath: \.tableHeaderBorderColorSwiftUI,
                                     icon: "fluent-ic_fluent_color_line_20_regular", tooltip: "Header Separator Color", component: component)
                    
                    factory.stepper("headerBorderWidth", keyPath: \.tableHeaderBorderWidth, icon: "fluent-ic_fluent_line_thickness_20_regular",
                                   tooltip: "Header Separator Width", range: 0.5...10, step: 0.5, suffix: "pt", format: .decimal(places: 1))
                }
            }
        }
    }
    
    // 3. Row Separators Group
    InspectorGroupBox(title: "Row Separators", icon: "fluent-ic_fluent_row_triple_20_regular") {
        InspectorControlGroup {
            factory.toggle("showRowBorders", keyPath: \.showRowBorders, icon: "fluent-ic_fluent_checkmark_circle_20_regular",
                          tooltip: "Show Row Separators")
            
            if component.style.showRowBorders {
                let rowBorderColorBinding = Binding<Color>(
                    get: { Color(hex: component.style.tableRowBorderColor) },
                    set: { newColor in
                        document.updateComponentStyle(for: component.id, actionName: "Change Row Separator Color") { style in
                            style.tableRowBorderColor = newColor.toHex()
                        }
                    }
                )
                
                InspectorControl.colorPicker("rowBorderColor", icon: "fluent-ic_fluent_color_line_20_regular",
                                            tooltip: "Row Separator Color", selection: rowBorderColorBinding)
                
                factory.stepper("rowBorderWidth", keyPath: \.tableRowBorderWidth, icon: "fluent-ic_fluent_line_thickness_20_regular",
                               tooltip: "Row Separator Width", range: 0.5...10, step: 0.5, suffix: "pt", format: .decimal(places: 1))
            }
        }
    }
    
    // 4. Grid Lines
    InspectorGroupBox(title: "Grid Options", icon: "fluent-ic_fluent_grid_20_regular") {
        InspectorControlGroup {
            factory.toggle("showCellBorders", keyPath: \.showCellBorders, icon: "fluent-ic_fluent_grid_20_regular",
                          tooltip: "Show Inner Grid lines")
        }
    }
}
```

---

## Future Footer Support Roadmap

While the parent system does not currently store or render Footers, adding them would be highly consistent with the Header styling pattern. 

### 1. Model Additions (`ComponentStyle`)
```swift
public var showTableFooter: Bool = false
public var tableFooterColor: String = "F3F4F6"
public var tableFooterTextColor: String = ""
public var tableFooterPadding: CGFloat = 8.0
public var tableFooterBorderWidth: CGFloat = 1.0
public var tableFooterBorderColor: String = "D1D5DB"
public var showFooterBorder: Bool = true
```

### 2. Inspector Controls
Within the proposed "Structure" & "Appearance" sections, Footer settings would mimic Headers:
* **In Layout**: `showTableFooter` toggle, and `tableFooterPadding` stepper (conditional on `showTableFooter`).
* **In Colors**: `tableFooterColor` and `tableFooterTextColor` pickers (conditional on `showTableFooter`).
* **In Borders**: `showFooterBorder` toggle, color picker, and stepper (conditional on `showTableFooter`).
