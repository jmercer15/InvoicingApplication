import SwiftUI
import Core
import SharedUI

struct TableElementPropertyEditor: View {
    let selection: TableElementSelection
    let component: InvoiceComponent
    @Binding var expandedSections: Set<AnyHashable>
    
    @EnvironmentObject var document: InvoiceDocument
    
    private enum TableElementInspectorSection: Hashable {
        case cellText
        case cellAppearance
        case cellDimensions
        case cellActions
        case sectionTitleContent
        case sectionTitleTypography
        case rowDimensions
        case columnDimensions
        case columnAppearance
    }
    
    var body: some View {
        InspectorContentLayout(
            header: header,
            descriptors: sectionDescriptors,
            expandedSections: $expandedSections
        )
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Table Properties")
                    .font(InspectorTypography.panelTitle)
                    .foregroundColor(Color.primaryText)
                
                Text("\(component.type.rawValue) - \(selection.displayName)")
                    .font(InspectorTypography.panelSubtitle)
                    .foregroundColor(Color.secondaryText)
            }
            
            HStack(spacing: 6) {
                InspectorHeaderStat(
                    icon: "fluent-ic_fluent_table_20_regular",
                    label: "Selection",
                    value: selectionKindLabel
                )
                
                InspectorHeaderStat(
                    icon: "fluent-ic_fluent_grid_20_regular",
                    label: "Scope",
                    value: selectionScopeLabel
                )
                
                InspectorHeaderStat(
                    icon: "fluent-ic_fluent_arrow_bidirectional_up_down_20_regular",
                    label: "Layout",
                    value: component.style.tableDirection.rawValue.capitalized
                )
                
                Spacer(minLength: 0)
            }
        }
    }
    
    private var sectionDescriptors: [InspectorSectionDescriptor<TableElementInspectorSection>] {
        switch selection {
        case .cell(let row, let column):
            return cellDescriptors(for: row...row, columns: column...column)
        case .cellRange(let rows, let columns):
            return cellDescriptors(for: rows, columns: columns)
        case .sectionTitle:
            return sectionTitleDescriptors
        case .row(let row):
            return rowDescriptors(for: row)
        case .column(let column):
            return columnDescriptors(for: column)
        }
    }
    
    private func cellDescriptors(for rows: ClosedRange<Int>, columns: ClosedRange<Int>) -> [InspectorSectionDescriptor<TableElementInspectorSection>] {
        [
            makeDescriptor(section: .cellText, title: "Text") {
                TableSelectionSectionView(component: component, rows: rows, columns: columns, mode: .text)
            },
            makeDescriptor(section: .cellAppearance, title: "Appearance") {
                TableSelectionSectionView(component: component, rows: rows, columns: columns, mode: .appearance)
            },
            makeDescriptor(section: .cellDimensions, title: "Dimensions") {
                TableSelectionSectionView(component: component, rows: rows, columns: columns, mode: .dimensions)
            },
            makeDescriptor(section: .cellActions, title: "Actions") {
                TableSelectionSectionView(component: component, rows: rows, columns: columns, mode: .actions)
            }
        ]
    }
    
    private var sectionTitleDescriptors: [InspectorSectionDescriptor<TableElementInspectorSection>] {
        [
            makeDescriptor(section: .sectionTitleContent, title: "Section Title") {
                SectionTitleInspectorSectionView(component: component, mode: .content)
            },
            makeDescriptor(section: .sectionTitleTypography, title: "Typography") {
                SectionTitleInspectorSectionView(component: component, mode: .typography)
            }
        ]
    }
    
    private func rowDescriptors(for row: Int) -> [InspectorSectionDescriptor<TableElementInspectorSection>] {
        [
            makeDescriptor(section: .rowDimensions, title: "Row") {
                RowInspectorSectionView(component: component, row: row)
            }
        ]
    }
    
    private func columnDescriptors(for column: Int) -> [InspectorSectionDescriptor<TableElementInspectorSection>] {
        [
            makeDescriptor(section: .columnDimensions, title: "Dimensions") {
                ColumnInspectorSectionView(component: component, column: column, mode: .dimensions)
            },
            makeDescriptor(section: .columnAppearance, title: "Appearance") {
                ColumnInspectorSectionView(component: component, column: column, mode: .appearance)
            }
        ]
    }
    
    private func makeDescriptor<V: View>(
        section: TableElementInspectorSection,
        title: String,
        @ViewBuilder builder: @escaping () -> V
    ) -> InspectorSectionDescriptor<TableElementInspectorSection> {
        InspectorSectionDescriptor(
            section: section,
            title: title,
            alwaysExpanded: false,
            isVisible: true,
            buildContent: { AnyView(builder()) }
        )
    }
    
    private var selectionKindLabel: String {
        switch selection {
        case .cell: return "Cell"
        case .cellRange: return "Range"
        case .row: return "Row"
        case .column: return "Column"
        case .sectionTitle: return "Section"
        }
    }
    
    private var selectionScopeLabel: String {
        switch selection {
        case .cell:
            return "1 × 1"
        case .cellRange(let rows, let columns):
            return "\(rows.count) × \(columns.count)"
        case .row(let index):
            return "Row \(index + 1)"
        case .column(let index):
            return "Column \(index + 1)"
        case .sectionTitle:
            return "Header"
        }
    }
}

private struct TableSelectionSectionView: View {
    enum Mode {
        case text
        case appearance
        case dimensions
        case actions
    }
    
    let component: InvoiceComponent
    let rows: ClosedRange<Int>
    let columns: ClosedRange<Int>
    let mode: Mode
    
    @EnvironmentObject var document: InvoiceDocument
    
    var body: some View {
        switch mode {
        case .text:
            textControls
        case .appearance:
            appearanceControls
        case .dimensions:
            dimensionControls
        case .actions:
            actionControls
        }
    }
    
    @ViewBuilder
    private var textControls: some View {
        InspectorGroupBox(title: "Text", icon: "fluent-ic_fluent_text_font_20_regular") {
            InspectorGrid {
                InspectorControl.picker("alignment", icon: "fluent-ic_fluent_text_align_left_20_regular",
                                       tooltip: "Alignment", selection: binding(for: \.alignment, actionName: "Change Text Alignment")) {
                    Text("Mixed/Auto").tag(Optional<TextAlignment>.none)
                    ForEach(TextAlignment.allCases, id: \.self) { alignment in
                        Text(alignment.rawValue).tag(Optional(alignment))
                    }
                }
                
                InspectorControl.picker("vAlignment", icon: "fluent-ic_fluent_text_baseline_20_regular",
                                       tooltip: "Vertical Alignment", selection: binding(for: \.verticalAlignmentOption, actionName: "Change Vertical Alignment")) {
                    Text("Mixed/Auto").tag(Optional<VerticalAlignmentOption>.none)
                    ForEach(VerticalAlignmentOption.allCases, id: \.self) { alignment in
                        Text(alignment.rawValue).tag(Optional(alignment))
                    }
                }
                
                InspectorControl.text("fontSize", icon: "fluent-ic_fluent_font_increase_20_regular",
                                     tooltip: "Font Size", text: Binding(
                                        get: {
                                            if let s = currentStyle?.fontSize { return String(format: "%.0f", s) }
                                            return ""
                                        },
                                        set: {
                                            if let v = Double($0) {
                                                updateStyle(actionName: "Change Font Size") { $0.fontSize = CGFloat(v) }
                                            }
                                        }
                                     ))
                
                InspectorControl.colorPicker("textColor", icon: "fluent-ic_fluent_text_color_20_regular",
                                           tooltip: "Text Color", selection: Binding(
                                            get: {
                                                if let hex = currentStyle?.textColor { return Color(hex: hex) ?? .black }
                                                return .black
                                            },
                                            set: {
                                                let hex = $0.toHex()
                                                updateStyle(actionName: "Change Text Color") { $0.textColor = hex }
                                            }
                                           ))
                
                InspectorControl.picker("fontWeight", icon: "fluent-ic_fluent_text_bold_20_regular",
                                       tooltip: "Font Weight", selection: binding(for: \.fontWeight, actionName: "Change Font Weight")) {
                    Text("Mixed/Default").tag(Optional<String>.none)
                    Text("Regular").tag(Optional("regular"))
                    Text("Medium").tag(Optional("medium"))
                    Text("Bold").tag(Optional("bold"))
                }
                
                InspectorControl.picker("transform", icon: "fluent-ic_fluent_text_case_title_20_regular",
                                       tooltip: "Text Transform", selection: binding(for: \.textTransform, actionName: "Change Text Transform")) {
                    Text("Mixed/Default").tag(Optional<TextTransform>.none)
                    ForEach(TextTransform.allCases, id: \.self) { transform in
                        Text(transform.rawValue).tag(Optional(transform))
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var appearanceControls: some View {
        InspectorGroupBox(title: "Appearance", icon: "fluent-ic_fluent_paint_brush_20_regular") {
            InspectorGrid {
                InspectorControl.colorPicker("bgColor", icon: "fluent-ic_fluent_paint_bucket_20_regular",
                                           tooltip: "Background Color", selection: Binding(
                                            get: {
                                                if let bg = currentStyle?.backgroundColor { return Color(hex: bg) ?? .white }
                                                return .white
                                            },
                                            set: {
                                                let hex = $0.toHex()
                                                updateStyle(actionName: "Change Cell Background") { $0.backgroundColor = hex }
                                            }
                                           ))
                
                InspectorControl.text("lineLimit", icon: "fluent-ic_fluent_line_style_20_regular",
                                     tooltip: "Line Limit", text: Binding(
                                        get: {
                                            if let l = binding(for: \.lineLimit).wrappedValue { return "\(l)" }
                                            return ""
                                        },
                                        set: {
                                            if let v = Int($0) {
                                                binding(for: \.lineLimit, actionName: "Change Line Limit").wrappedValue = v
                                            }
                                        }
                                     ))
            }
        }
    }
    
    @ViewBuilder
    private var dimensionControls: some View {
        InspectorGroupBox(title: "Dimensions", icon: "fluent-ic_fluent_ruler_20_regular") {
            InspectorGrid {
                InspectorControl.text("rowHeight", icon: "fluent-ic_fluent_arrow_autofit_height_20_regular",
                                     tooltip: "Row Height", text: Binding(
                                        get: {
                                            let heights = rows.map { component.style.rowConfiguration(for: $0).height }
                                            let unique = Set(heights)
                                            if unique.count == 1, let h = unique.first { return String(format: "%.0f", h) }
                                            return ""
                                        },
                                        set: {
                                            if let v = Double($0) {
                                                document.updateComponentStyle(for: component.id, actionName: "Resize Row") { style in
                                                    for r in rows {
                                                        style.updateAxisSize(for: .row, at: r, size: CGFloat(v))
                                                        style.updateAxisAutoSizing(for: .row, at: r, isAutoSized: false)
                                                        style.updateAxisIsFlexible(for: .row, at: r, isFlexible: false)
                                                    }
                                                }
                                            }
                                        }
                                     ))
                                     .overlay(alignment: .trailing) {
                                        if rows.count > 1 {
                                            Text("(\(rows.count))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .offset(x: 24)
                                        }
                                     }
                
                InspectorControl.text("colWidth", icon: "fluent-ic_fluent_arrow_autofit_width_20_regular",
                                     tooltip: "Column Width", text: Binding(
                                        get: {
                                            let widths = columns.map { component.style.columnConfiguration(for: $0).width }
                                            let unique = Set(widths)
                                            if unique.count == 1, let w = unique.first { return String(format: "%.0f", w) }
                                            return ""
                                        },
                                        set: {
                                            if let w = Double($0) {
                                                document.updateComponentStyle(for: component.id, actionName: "Resize Column") { style in
                                                    for c in columns {
                                                        style.updateAxisSize(for: .column, at: c, size: CGFloat(w))
                                                        style.updateAxisAutoSizing(for: .column, at: c, isAutoSized: false)
                                                        style.updateAxisIsFlexible(for: .column, at: c, isFlexible: false)
                                                    }
                                                }
                                            }
                                        }
                                     ))
                                     .overlay(alignment: .trailing) {
                                        if columns.count > 1 {
                                            Text("(\(columns.count))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .offset(x: 24)
                                        }
                                     }
            }
        }
    }
    
    @ViewBuilder
    private var actionControls: some View {
        InspectorGroupBox(title: "Actions", icon: "fluent-ic_fluent_arrow_undo_20_regular") {
            InspectorGrid {
                InspectorControl.button("resetStyles", icon: "fluent-ic_fluent_arrow_undo_20_regular",
                                       tooltip: "Reset Styles", title: "Reset Cell Styles", action: {
                    document.updateComponentStyle(for: component.id, actionName: "Reset Cell Styles") { style in
                        style.updateCellStyles(rows: rows, columns: columns) { cellStyle in
                            cellStyle = ComponentStyle.CellStyle()
                        }
                        for r in rows {
                            for c in columns {
                                style.cellStyles["\(r):\(c)"] = nil
                            }
                        }
                    }
                })
                .tint(.red)
            }
        }
    }
    
    private var currentStyle: ComponentStyle.CellStyle? {
        component.style.cellStyle(row: rows.lowerBound, column: columns.lowerBound)
    }
    
    private func binding<T>(for keyPath: WritableKeyPath<ComponentStyle.CellStyle, T?>, actionName: String = "Change Cell Style") -> Binding<T?> {
        Binding(
            get: {
                currentStyle?[keyPath: keyPath]
            },
            set: { newValue in
                updateStyle(actionName: actionName) { style in
                    style[keyPath: keyPath] = newValue
                }
            }
        )
    }
    
    private func updateStyle(actionName: String = "Change Cell Style", _ update: @escaping (inout ComponentStyle.CellStyle) -> Void) {
        document.updateComponentStyle(for: component.id, actionName: actionName) { style in
            style.updateCellStyles(rows: rows, columns: columns, update: update)
        }
    }
}

private struct SectionTitleInspectorSectionView: View {
    enum Mode {
        case content
        case typography
    }
    
    let component: InvoiceComponent
    let mode: Mode
    
    @EnvironmentObject var document: InvoiceDocument
    
    var body: some View {
        switch mode {
        case .content:
            contentControls
        case .typography:
            typographyControls
        }
    }
    
    private var configurationBinding: Binding<FontPickerConfiguration> {
        Binding<FontPickerConfiguration>(
            get: {
                FontPickerConfiguration(from: liveComponent.style, scope: .sectionTitle)
            },
            set: { config in
                document.updateComponentStyle(for: component.id, actionName: "Change Section Title Typography") { style in
                    config.apply(to: &style, scope: .sectionTitle)
                }
            }
        )
    }
    
    private var liveComponent: InvoiceComponent {
        document.component(component.id) ?? component
    }
    
    @ViewBuilder
    private var contentControls: some View {
        InspectorGroupBox(title: "Section Title", icon: "fluent-ic_fluent_text_align_left_20_regular") {
            InspectorGrid {
                InspectorControl.text("sectionTitle", icon: "fluent-ic_fluent_text_case_title_20_regular",
                                     tooltip: "Title", text: Binding(
                                        get: { liveComponent.style.sectionTitle ?? "" },
                                        set: { newVal in
                                            document.updateComponentStyle(for: component.id, actionName: "Change Section Title") { style in
                                                style.sectionTitle = newVal
                                            }
                                        }
                                     ))
                
                InspectorControl.picker("titleAlignment", icon: "fluent-ic_fluent_text_align_left_20_regular",
                                       tooltip: "Alignment", selection: Binding(
                                        get: { liveComponent.style.sectionTitleAlignment },
                                        set: { value in
                                            document.updateComponentStyle(for: component.id, actionName: "Change Section Title Alignment") { style in
                                                style.sectionTitleAlignment = value
                                            }
                                        }
                                       )) {
                    ForEach(TextAlignment.allCases, id: \.self) { align in
                        Text(align.rawValue).tag(align)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var typographyControls: some View {
        InspectorGroupBox(title: "Typography", icon: "fluent-ic_fluent_text_font_20_regular") {
            InlineFontPicker(configuration: configurationBinding)
        }
    }
}

private struct RowInspectorSectionView: View {
    let component: InvoiceComponent
    let row: Int
    
    @EnvironmentObject var document: InvoiceDocument
    
    var body: some View {
        InspectorGroupBox(title: "Dimensions", icon: "fluent-ic_fluent_ruler_20_regular") {
            InspectorGrid {
                InspectorControl.toggle("flexible", icon: "fluent-ic_fluent_checkbox_checked_20_regular",
                                       tooltip: "Flexible Height", isOn: Binding(
                                        get: { component.style.rowConfiguration(for: row).isFlexible },
                                        set: { isFlexible in
                                            document.updateComponentStyle(for: component.id, actionName: "Toggle Row Flexibility") { style in
                                                style.updateAxisIsFlexible(for: .row, at: row, isFlexible: isFlexible)
                                            }
                                        }
                                       ))
                
                if !component.style.rowConfiguration(for: row).isFlexible {
                    InspectorControl.toggle("autoSize", icon: "fluent-ic_fluent_arrow_autofit_height_20_regular",
                                           tooltip: "Auto Size", isOn: Binding(
                                            get: { component.style.rowConfiguration(for: row).isAutoSized },
                                            set: { isAutoSized in
                                                document.updateComponentStyle(for: component.id, actionName: "Toggle Row Auto-Size") { style in
                                                    style.updateAxisAutoSizing(for: .row, at: row, isAutoSized: isAutoSized)
                                                }
                                            }
                                           ))
                    
                    if !component.style.rowConfiguration(for: row).isAutoSized {
                        InspectorControl.stepper("height", icon: "fluent-ic_fluent_arrow_autofit_height_20_regular",
                                                tooltip: "Height", value: Binding(
                                                    get: { Double(component.style.rowConfiguration(for: row).height) },
                                                    set: { height in
                                                        document.updateComponentStyle(for: component.id, actionName: "Resize Row") { style in
                                                            style.updateAxisSize(for: .row, at: row, size: CGFloat(height))
                                                        }
                                                    }
                                                ), range: 0...1000, step: 1, suffix: "pt")
                    }
                }
            }
        }
    }
}

private struct ColumnInspectorSectionView: View {
    enum Mode {
        case dimensions
        case appearance
    }
    
    let component: InvoiceComponent
    let column: Int
    let mode: Mode
    
    @EnvironmentObject var document: InvoiceDocument
    
    var body: some View {
        switch mode {
        case .dimensions:
            dimensionControls
        case .appearance:
            appearanceControls
        }
    }
    
    private var columnConfig: ComponentStyle.ColumnConfiguration {
        component.style.columnConfiguration(for: column)
    }
    
    @ViewBuilder
    private var dimensionControls: some View {
        InspectorGroupBox(title: "Dimensions", icon: "fluent-ic_fluent_ruler_20_regular") {
            InspectorGrid {
                InspectorControl.toggle("flexible", icon: "fluent-ic_fluent_checkbox_checked_20_regular",
                                       tooltip: "Flexible Width", isOn: Binding(
                                        get: { columnConfig.isFlexible },
                                        set: { isFlexible in
                                            document.updateComponentStyle(for: component.id, actionName: "Toggle Column Flexibility") { style in
                                                style.updateAxisIsFlexible(for: .column, at: column, isFlexible: isFlexible)
                                            }
                                        }
                                       ))
                
                if !columnConfig.isFlexible {
                    InspectorControl.toggle("autoSize", icon: "fluent-ic_fluent_arrow_autofit_width_20_regular",
                                           tooltip: "Auto Size", isOn: Binding(
                                            get: { columnConfig.isAutoSized },
                                            set: { isAutoSized in
                                                document.updateComponentStyle(for: component.id, actionName: "Toggle Column Auto-Size") { style in
                                                    style.updateAxisAutoSizing(for: .column, at: column, isAutoSized: isAutoSized)
                                                }
                                            }
                                           ))
                    
                    if !columnConfig.isAutoSized {
                        InspectorControl.stepper("width", icon: "fluent-ic_fluent_arrow_autofit_width_20_regular",
                                                tooltip: "Width", value: Binding(
                                                    get: { Double(columnConfig.width) },
                                                    set: { width in
                                                        document.updateComponentStyle(for: component.id, actionName: "Resize Column") { style in
                                                            style.updateAxisSize(for: .column, at: column, size: CGFloat(width))
                                                        }
                                                    }
                                                ), range: 0...1000, step: 1, suffix: "pt")
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var appearanceControls: some View {
        InspectorGroupBox(title: "Appearance", icon: "fluent-ic_fluent_text_align_left_20_regular") {
            InspectorGrid {
                InspectorControl.picker("alignment", icon: "fluent-ic_fluent_text_align_left_20_regular",
                                       tooltip: "Alignment", selection: Binding(
                                        get: { columnConfig.alignment },
                                        set: { alignment in
                                            document.updateComponentStyle(for: component.id, actionName: "Change Column Alignment") { style in
                                                style.updateAxisAlignment(for: .column, at: column, alignment: alignment)
                                            }
                                        }
                                       )) {
                    ForEach(TextAlignment.allCases, id: \.self) { align in
                        Text(align.rawValue).tag(align)
                    }
                }
            }
        }
    }
}
