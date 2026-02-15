import SwiftUI
import Core
import SharedUI

// MARK: - Table Controls

extension ComponentPropertyEditor {
    func tableSectionDescriptors(for component: InvoiceComponent) -> [InspectorSectionDescriptor<InspectorSection>] {
        let sections: [(InspectorSection, String, () -> AnyView)] = [
            (.tableLayoutStructure, "Structure", { AnyView(self.tableStructureContent(for: component)) }),
            (.tableFill, "Appearance", { AnyView(self.tableAppearanceContent(for: component)) }),
            (.tableTypography, "Typography", { AnyView(self.tableTypographyContent(for: component)) }),
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

    @ViewBuilder
    func tableStructureContent(for component: InvoiceComponent) -> some View {
        let factory = ComponentInspectorControlFactory(component: component, document: document)
        
        InspectorGroupBox(title: "Layout", icon: "fluent-ic_fluent_table_20_regular") {
            InspectorControlGroup {
                factory.picker("direction", keyPath: \.tableDirection, icon: "fluent-ic_fluent_match_app_layout_20_regular",
                              tooltip: "Direction") { $0.rawValue.capitalized }
                
                factory.toggle("showHeader", keyPath: \.showTableHeader, icon: "fluent-ic_fluent_table_bottom_row_20_regular",
                              tooltip: "Show Header")
                
                factory.stepper("cellPadding", keyPath: \.tableCellPadding, icon: "fluent-ic_fluent_padding_down_20_regular",
                               tooltip: "Cell Padding", range: 0...48, step: 4, suffix: "pt")
                
                if component.style.showTableHeader {
                    factory.stepper("headerPadding", keyPath: \.tableHeaderPadding, icon: "fluent-ic_fluent_padding_top_20_regular",
                                   tooltip: "Header Padding", range: 0...48, step: 4, suffix: "pt")
                }
            }
        }
    }
    
    @ViewBuilder
    func tableAppearanceContent(for component: InvoiceComponent) -> some View {
        let factory = ComponentInspectorControlFactory(component: component, document: document)
        
        // Colors
        InspectorGroupBox(title: "Colors", icon: "fluent-ic_fluent_color_background_20_regular") {
            InspectorControlGroup {
                tableColorControl("textColor", hexKeyPath: \.tableTextColor, swiftUIKeyPath: \.tableTextColorSwiftUI,
                                 icon: "fluent-ic_fluent_text_color_20_regular", tooltip: "Text Color", component: component)
                
                tableColorControl("rowFill", hexKeyPath: \.tableRowColor, swiftUIKeyPath: \.tableRowColorSwiftUI,
                                 icon: "fluent-ic_fluent_row_triple_20_regular", tooltip: "Row Fill", component: component)
                
                factory.toggle("alternatingRows", keyPath: \.useAlternatingRows, icon: "fluent-ic_fluent_toggle_left_20_regular",
                              tooltip: "Alternating Rows")
                
                if component.style.useAlternatingRows {
                    tableColorControl("altRowFill", hexKeyPath: \.tableRowAltColor, swiftUIKeyPath: \.tableRowAltColorSwiftUI,
                                     icon: "fluent-ic_fluent_color_fill_20_regular", tooltip: "Alt Row Fill", component: component)
                }
                
                if component.style.showTableHeader {
                    tableColorControl("headerTextColor", hexKeyPath: \.tableHeaderTextColor, swiftUIKeyPath: \.tableHeaderTextColorSwiftUI,
                                     icon: "fluent-ic_fluent_text_color_20_regular", tooltip: "Header Text Color", component: component)
                    
                    tableColorControl("headerFill", hexKeyPath: \.tableHeaderColor, swiftUIKeyPath: \.tableHeaderColorSwiftUI,
                                     icon: "fluent-ic_fluent_column_triple_20_regular", tooltip: "Header Fill", component: component)
                }
            }
        }
        
        // Borders
        InspectorGroupBox(title: "Borders", icon: "fluent-ic_fluent_border_outside_20_regular") {
            InspectorControlGroup {
                factory.toggle("showBorders", keyPath: \.showTableBorders, icon: "fluent-ic_fluent_checkmark_circle_20_regular",
                              tooltip: "Show Borders")
                
                if component.style.showTableBorders {
                    tableColorControl("borderColor", hexKeyPath: \.tableBorderColor, swiftUIKeyPath: \.tableBorderColorSwiftUI,
                                     icon: "fluent-ic_fluent_color_line_20_regular", tooltip: "Border Color", component: component)
                    
                    factory.stepper("borderWidth", keyPath: \.tableBorderWidth, icon: "fluent-ic_fluent_line_thickness_20_regular",
                                   tooltip: "Border Width", range: 0.5...10, step: 0.5, suffix: "pt", format: .decimal(places: 1))
                }
            }
        }
        
        // Shadow
        shadowControls(for: component)
    }
    
    /// Helper for table color controls with hex string storage and SwiftUI Color getter
    private func tableColorControl(_ id: String, hexKeyPath: WritableKeyPath<ComponentStyle, String>,
                                   swiftUIKeyPath: KeyPath<ComponentStyle, Color>,
                                   icon: String, tooltip: String, component: InvoiceComponent) -> InspectorControl {
        let binding = Binding<Color>(
            get: { component.style[keyPath: swiftUIKeyPath] },
            set: { newColor in
                document.updateComponentStyle(for: component.id, actionName: "Change \(tooltip)") { style in
                    style[keyPath: hexKeyPath] = newColor.toHex()
                }
            }
        )
        return .color(id, icon: icon, tooltip: tooltip, selection: binding)
    }
    
    @ViewBuilder
    func sectionTitleContent(for component: InvoiceComponent) -> some View {
        let configurationBinding = Binding<FontPickerConfiguration>(
            get: {
                FontPickerConfiguration(from: liveComponent.style, scope: .sectionTitle)
            },
            set: { config in
                document.updateComponentStyle(for: component.id, actionName: "Change Section Title Typography") { style in
                    config.apply(to: &style, scope: .sectionTitle)
                }
            }
        )

        InspectorGroupBox(title: "Section Title", icon: "fluent-ic_fluent_text_quote_20_regular") {
            InspectorGrid {
                InspectorControl.text("sectionTitle", icon: "fluent-ic_fluent_text_case_title_20_regular",
                                     tooltip: "Title", text: styleBinding(for: component, \.sectionTitle) { componentID, title in
                                        document.updateComponentStyle(for: componentID, actionName: "Change Section Title") { $0.sectionTitle = title }
                                     })
            }
        }

        InlineFontPicker(configuration: configurationBinding)
    }


    @ViewBuilder
    func tableTypographyContent(for component: InvoiceComponent) -> some View {
        let _ = ensureTableTypographyData(for: component)
        let tableData = tablePreviewData(for: component)
        let currentComponent = tableData.component
        let tabCount = tableData.isHorizontal ? tableData.columnCount : tableData.rowCount
        let selectedIndex = min(typographyTabSelection[component.id] ?? 0, max(0, tabCount - 1))
        let isHorizontal = tableData.isHorizontal
        let columnConfig = currentComponent.style.columnConfiguration(for: selectedIndex)
        let rowConfig = currentComponent.style.rowConfiguration(for: selectedIndex)

        if tabCount > 1 {
            InspectorGroupBox(title: "Selection", icon: "fluent-ic_fluent_grid_20_regular") {
                InspectorGrid {
                    InspectorControl.picker("selection", icon: "fluent-ic_fluent_match_app_layout_20_regular",
                                           tooltip: currentComponent.style.tableDirection == .horizontal ? "Column" : "Row",
                                           selection: Binding(
                                            get: { typographyTabSelection[component.id] ?? 0 },
                                            set: { typographyTabSelection[component.id] = $0 }
                                           )) {
                        ForEach(Array(0..<tabCount), id: \.self) { index in
                            Text(currentComponent.style.tableDirection == .horizontal ? "Column \(index + 1)" : "Row \(index + 1)")
                                .tag(index)
                        }
                    }
                }
            }
        }

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
            }
        }
    }

    @ViewBuilder
    func tableColumnsContent(for component: InvoiceComponent) -> some View {
        let _ = ensureTableColumnData(for: component)
        let tableData = tablePreviewData(for: component)
        let currentComponent = tableData.component
        let columnCount = tableData.columnCount
        let selectedIndex = min(columnTabSelection[component.id] ?? 0, max(0, columnCount - 1))
        let columnConfig = currentComponent.style.columnConfiguration(for: selectedIndex)

        if columnCount > 1 {
            InspectorGroupBox(title: "Column Selection", icon: "fluent-ic_fluent_column_triple_20_regular") {
                InspectorGrid {
                    InspectorControl.picker("columnSelection", icon: "fluent-ic_fluent_table_settings_20_regular",
                                           tooltip: "Column Selection", selection: Binding(
                                            get: { columnTabSelection[component.id] ?? 0 },
                                            set: { columnTabSelection[component.id] = $0 }
                                           )) {
                        ForEach(Array(0..<columnCount), id: \.self) { index in
                            Text("Column \(index + 1)").tag(index)
                        }
                    }
                }
            }
        }

        InspectorGroupBox(title: "Dimensions", icon: "fluent-ic_fluent_arrow_expand_20_regular") {
            InspectorGrid {
                InspectorControl.picker("widthMode", icon: "fluent-ic_fluent_arrow_autofit_width_20_regular",
                                       tooltip: "Width Mode", selection: Binding(
                                        get: { columnConfig.isAutoSized ? ColumnWidthMode.autoSize : (columnConfig.isFlexible ? ColumnWidthMode.flexible : ColumnWidthMode.fixed) },
                                        set: { newMode in
                                            switch newMode {
                                            case .flexible:
                                                document.updateAxisIsFlexible(for: component.id, axis: .column, index: selectedIndex, isFlexible: true)
                                            case .autoSize:
                                                document.updateAxisAutoSizing(for: component.id, axis: .column, index: selectedIndex, isAutoSized: true)
                                            case .fixed:
                                                document.updateAxisIsFlexible(for: component.id, axis: .column, index: selectedIndex, isFlexible: false)
                                                document.updateAxisAutoSizing(for: component.id, axis: .column, index: selectedIndex, isAutoSized: false)
                                            }
                                        }
                                       )) {
                    ForEach(ColumnWidthMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                
                if !columnConfig.isAutoSized && !columnConfig.isFlexible {
                    InspectorControl.stepper("width", icon: "fluent-ic_fluent_resize_image_20_regular",
                                            tooltip: "Width", value: Binding(
                                                get: { Double(columnConfig.width) },
                                                set: { document.updateAxisSize(for: component.id, axis: .column, index: selectedIndex, size: CGFloat($0), actionName: "Resize Column") }
                                            ), range: 0...1000, step: 1, suffix: "pt")
                }
            }
        }

        InspectorGroupBox(title: "Alignment", icon: "square.grid.3x3.fill") {
            InspectorAlignmentGridRow(
                label: "Data Cell",
                horizontalAlignment: Binding(
                    get: { currentComponent.style.columnConfiguration(for: selectedIndex).alignment },
                    set: { document.updateAxisAlignment(for: component.id, axis: .column, index: selectedIndex, alignment: $0, actionName: "Change Column Alignment") }
                ),
                verticalAlignment: Binding(
                    get: { currentComponent.style.columnConfiguration(for: selectedIndex).verticalAlignment },
                    set: { document.updateAxisVerticalAlignment(for: component.id, axis: .column, index: selectedIndex, verticalAlignment: $0, actionName: "Change Vertical Alignment") }
                )
            )
            
            InspectorAlignmentGridRow(
                label: "Header",
                horizontalAlignment: Binding(
                    get: { currentComponent.style.columnConfiguration(for: selectedIndex).headerAlignment },
                    set: { document.updateAxisHeaderAlignment(for: component.id, axis: .column, index: selectedIndex, alignment: $0, actionName: "Change Header Alignment") }
                ),
                verticalAlignment: Binding(
                    get: { currentComponent.style.columnConfiguration(for: selectedIndex).headerVerticalAlignment },
                    set: { document.updateAxisHeaderVerticalAlignment(for: component.id, axis: .column, index: selectedIndex, verticalAlignment: $0, actionName: "Change Header Vertical Alignment") }
                )
            )
        }
    }
}
