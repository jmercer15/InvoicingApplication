import SwiftUI

// Layout types and DocumentGridView are now in DocumentGridLayout.swift

// MARK: - DocumentGridComponent

/// Document grid component for invoice templates
struct DocumentGridComponent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument
    @EnvironmentObject private var templateDataService: TemplateDataService
    
    // Context parameters for targeted data access
    let clientId: UUID?
    let invoiceId: UUID?
    
    // Ensure the view updates when the component changes
    private var currentComponent: InvoiceComponent {
        document.components.first { $0.id == component.id } ?? component
    }
    
    // Initializer with context parameters
    init(component: InvoiceComponent, clientId: UUID? = nil, invoiceId: UUID? = nil) {
        self.component = component
        self.clientId = clientId
        self.invoiceId = invoiceId
    }
    
    var body: some View {
        DocumentGridView(
            data: sampleData,
            borderColor: borderColor,
            borderWidth: borderWidth,
            columnConfigs: columnConfigurations,
            borderOptions: borderOptions,
            horizontalBorderAppearance: horizontalBorderAppearance
        ) { item in
            renderGridCell(for: item)
        }
        .id("\(currentComponent.id)-\(currentComponent.style.hashValue)")
        .frame(width: currentComponent.size.width)
        .shadow(
            color: shadowColor,
            radius: currentComponent.style.shadowRadius,
            x: currentComponent.style.shadowOffsetX,
            y: currentComponent.style.shadowOffsetY
        )
        .background(sizeMeasurementLayer)
        .id(currentComponent.id)
    }
    
    // MARK: - Computed Properties
    
    private var borderColor: Color {
        currentComponent.style.showTableBorders ? currentComponent.style.tableBorderColorSwiftUI : .clear
    }
    
    private var borderWidth: CGFloat {
        currentComponent.style.showTableBorders ? currentComponent.style.tableBorderWidth : 0
    }
    
    private var borderOptions: TableBorderOptions {
        TableBorderOptions(
            showHeaderBorders: currentComponent.style.showHeaderBorder,
            showRowBorders: currentComponent.style.showRowBorders,
            showCellBorders: currentComponent.style.showCellBorders
        )
    }
    
    private var horizontalBorderAppearance: TableHorizontalBorderAppearance {
        let bordersEnabled = currentComponent.style.showTableBorders
        return TableHorizontalBorderAppearance(
            header: TableBorderSegmentAppearance(
                color: bordersEnabled ? currentComponent.style.tableHeaderBorderColorSwiftUI : .clear,
                width: bordersEnabled ? currentComponent.style.tableHeaderBorderWidth : 0
            ),
            row: TableBorderSegmentAppearance(
                color: bordersEnabled ? currentComponent.style.tableRowBorderColorSwiftUI : .clear,
                width: bordersEnabled ? currentComponent.style.tableRowBorderWidth : 0
            )
        )
    }
    
    private var shadowColor: Color {
        currentComponent.style.shadowEnabled 
            ? currentComponent.style.shadowColorSwiftUI.opacity(currentComponent.style.shadowOpacity)
            : .clear
    }
    
    // MARK: - Size Measurement
    
    private var sizeMeasurementLayer: some View {
        GeometryReader { _ in
            Color.clear
                .onAppear {
                    initializeColumnsIfNeeded()
                    initializeColumnsForData(sampleData)
                }
                .onPreferenceChange(GridSizePreferenceKey.self, perform: updateComponentSize)
        }
    }
    
    private func updateComponentSize(_ measuredSize: CGSize) {
        guard measuredSize != .zero && measuredSize.height > 0 else { return }
        
        let newHeight = measuredSize.height
        let currentHeight = currentComponent.size.height
        
        guard abs(newHeight - currentHeight) > 0.5 else { return }
        
        document.updateComponent(id: currentComponent.id) { component in
            component.size = CGSize(
                width: component.size.width,
                height: newHeight
            )
        }
    }
    
    // MARK: - Column Configurations
    
    @State private var hasInitializedColumns = false
    
    private var columnConfigurations: [ColumnWidthConfig] {
        // Get the number of columns from the sample data
        let columnCount = sampleData.first?.count ?? 4
        
        // Note: Initialization is moved to onAppear to avoid modifying @Published
        // properties from computed properties, which causes infinite loops
        
        // Convert dynamic column configurations to ColumnWidthConfig array
        var configs: [ColumnWidthConfig] = []
        for i in 0..<columnCount {
            let config = currentComponent.style.columnConfiguration(for: i)
            // Enforce mutual exclusivity: prioritize auto-sized, then flexible, then fixed
            if config.isAutoSized {
                configs.append(.autoSized())
            } else if config.isFlexible {
                configs.append(.flexible())
            } else {
                configs.append(.fixed(config.width))
            }
        }
        return configs
    }
    
    private func initializeColumnsIfNeeded() {
        guard !hasInitializedColumns else { return }
        
        let columnCount = sampleData.first?.count ?? 4
        
        // Initialize configurations based on table direction
        if currentComponent.style.tableDirection == .horizontal {
            if currentComponent.style.columnConfigurations.isEmpty {
                document.initializeColumnConfigurations(for: currentComponent.id, columnCount: columnCount)
                hasInitializedColumns = true
            }
        } else {
            if currentComponent.style.rowConfigurations.isEmpty {
                document.initializeRowConfigurations(for: currentComponent.id, rowCount: columnCount)
                hasInitializedColumns = true
        }
        }
    }
    
    // MARK: - Sample Data
    // Data generation logic moved to DocumentGridData.swift
    
    private var sampleData: [[DocumentTableItem]] {
        let generator = DocumentGridDataGenerator(
            component: currentComponent,
            templateDataService: templateDataService,
            clientId: clientId,
            invoiceId: invoiceId
        )
        return generator.generateSampleData()
    }
    
    private var isSectionComponent: Bool {
        let generator = DocumentGridDataGenerator(
            component: currentComponent,
            templateDataService: templateDataService,
            clientId: clientId,
            invoiceId: invoiceId
        )
        return generator.isSectionComponent
    }
    
    // MARK: - Column Default Mapping (Alignment & Formatting)
    /// Optional default alignment per column. If an item doesn't specify an alignment,
    /// the grid will fall back to this mapping.
    private var columnAlignmentDefaults: [Int: TextAlignment] {
        let columnCount = sampleData.first?.count ?? 4
        var defaults: [Int: TextAlignment] = [:]
        
        for i in 0..<columnCount {
            let config = currentComponent.style.columnConfiguration(for: i)
            defaults[i] = config.alignment
        }
        
        return defaults
    }
    
    /// Optional default formatter per column. If present (and the item is not a header),
    /// the formatter can transform the cell's display text. Default is `nil` for all columns.
    private func defaultFormatter(forColumn index: Int) -> ((String) -> String)? {
        return nil
    }
    
    /// Resolves the effective text alignment for a given item using per-cell override
    /// first, then falling back to row/column defaults set in the DocumentGrid property editor.
    /// 
    /// Priority:
    /// 1. Item's explicit alignment (if not nil)
    /// 2. Row/Column header alignment (if item is header)
    /// 3. Row/Column default alignment (from DocumentGrid property editor)
    /// 4. Leading alignment (fallback)
    private func effectiveTextAlignment(for item: DocumentTableItem) -> TextAlignment {
        // First priority: explicit alignment on the item
        if let alignment = item.alignment {
            return convertAlignmentToTextAlignment(alignment)
        }
        
        // Second priority: header alignment (if item is header)
        if isItemHeader(item) {
            switch currentComponent.style.tableDirection {
            case .horizontal:
                // Horizontal: use column header alignment
                if let col = item.columnIndex {
                    let config = currentComponent.style.columnConfiguration(for: col)
                    return config.headerAlignment
                }
            case .vertical:
                // Vertical: use column header alignment (columns are configured, not rows)
                if let col = item.columnIndex {
                    let config = currentComponent.style.columnConfiguration(for: col)
                    return config.headerAlignment
                }
            }
        }
        
        // Third priority: row/column default from DocumentGrid property editor
        switch currentComponent.style.tableDirection {
        case .horizontal:
            // Horizontal: use column default
            if let col = item.columnIndex, let def = columnAlignmentDefaults[col] {
                return def
            }
        case .vertical:
            // Vertical: use column default (columns are configured, not rows)
            if let col = item.columnIndex {
                let config = currentComponent.style.columnConfiguration(for: col)
                return config.alignment
            }
        }
        
        // Fallback: leading alignment
        return .leading
    }
    
    /// Resolves the effective vertical alignment for a given item using per-cell override
    /// first, then falling back to row/column defaults set in the DocumentGrid property editor.
    /// 
    /// Priority:
    /// 1. Item's explicit vertical alignment (if not nil)
    /// 2. Row/Column header vertical alignment (if item is header)
    /// 3. Row/Column default vertical alignment (from DocumentGrid property editor)
    /// 4. Center alignment (fallback)
    private func effectiveVerticalAlignment(for item: DocumentTableItem) -> VerticalAlignment {
        // First priority: explicit vertical alignment on the item
        if let verticalAlignment = item.verticalAlignment {
            return verticalAlignment
        }
        
        // Second priority: header vertical alignment (if item is header)
        if isItemHeader(item) {
            switch currentComponent.style.tableDirection {
            case .horizontal:
                // Horizontal: use column header vertical alignment
                if let col = item.columnIndex {
                    let config = currentComponent.style.columnConfiguration(for: col)
                    return config.headerVerticalAlignment
                }
            case .vertical:
                // Vertical: use column header vertical alignment (columns are configured, not rows)
                if let col = item.columnIndex {
                    let config = currentComponent.style.columnConfiguration(for: col)
                    return config.headerVerticalAlignment
                }
            }
        }
        
        // Third priority: row/column default from DocumentGrid property editor
        switch currentComponent.style.tableDirection {
        case .horizontal:
            // Horizontal: use column default
            if let col = item.columnIndex {
                let config = currentComponent.style.columnConfiguration(for: col)
                return config.verticalAlignment
            }
        case .vertical:
            // Vertical: use column default (columns are configured, not rows)
            if let col = item.columnIndex {
                let config = currentComponent.style.columnConfiguration(for: col)
                return config.verticalAlignment
            }
        }
        
        // Fallback: center alignment
        return .center
    }
    
    // MARK: - Helper Methods
    
    /// Determines if an item should be treated as a header based on table direction
    private func isItemHeader(_ item: DocumentTableItem) -> Bool {
        switch currentComponent.style.tableDirection {
        case .horizontal:
            // Horizontal: headers are in the first row
            return item.isHeader
        case .vertical:
            // Vertical: headers are in the first column
            return item.columnIndex == 0 && currentComponent.style.showTableHeader
        }
    }
    
    /// Renders a grid cell directly as part of the DocumentGrid
    private func renderGridCell(for item: DocumentTableItem) -> some View {
        let colIndex = item.columnIndex ?? 0
        let isHeader = isItemHeader(item)
        let displayText = isHeader ? item.content : (defaultFormatter(forColumn: colIndex)?(item.content) ?? item.content)
        
        return AnyView(
            ZStack(alignment: alignmentFromUnitPoint(gridCellAnchorForItem(item))) {
                // Cell background (applied to entire cell area) - transparent for transparent cells
                if !item.isTransparent {
                    RoundedRectangle(cornerRadius: currentComponent.style.cornerRadius)
                        .fill(backgroundColorForItem(item))
                        .opacity(1.0)
                }

                // Text content - invisible for transparent cells
                if !item.isTransparent {
                    Text(displayText)
                        .font(.custom(currentComponent.style.fontFamily.isEmpty ? "Helvetica" : currentComponent.style.fontFamily, size: max(8, currentComponent.style.fontSize))
                            .weight(isHeader ? .bold : currentComponent.style.fontWeightValue))
                        .foregroundColor(
                            (isHeader ? currentComponent.style.tableHeaderTextColorSwiftUI : currentComponent.style.tableTextColorSwiftUI)
                                .opacity(currentComponent.style.textOpacity)
                        )
                        .lineSpacing(currentComponent.style.lineSpacing)
                        .kerning(currentComponent.style.letterSpacing)
                        .underline(currentComponent.style.textUnderline)
                        .strikethrough(currentComponent.style.textStrikethrough)
                        .textCase(currentComponent.style.textTransform.swiftUITextCase)
                        .lineLimit(effectiveLineLimit(for: item)) // Use configured line limit
                        .multilineTextAlignment(swiftUITextAlignment(effectiveTextAlignment(for: item))) // Match horizontal alignment
                        .padding(isHeader ? currentComponent.style.tableHeaderPadding : currentComponent.style.tableCellPadding)
                        .background(DocumentGridCellHeightReporter(rowIndex: item.rowIndex))
                }
            }
            .gridCellAnchor(gridCellAnchorForItem(item)) // Apply anchor to the entire cell content
        )
    }
    
    /// Converts Alignment to TextAlignment for ComponentStyle
    private func convertAlignmentToTextAlignment(_ alignment: Alignment) -> TextAlignment {
        switch alignment {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        default:
            return .leading
        }
    }
    
    
    private func backgroundColorForItem(_ item: DocumentTableItem) -> Color {
        let isHeader = isItemHeader(item)
        
        if isHeader {
            return currentComponent.style.tableHeaderColorSwiftUI
        } else {
            let isAlternating: Bool
            switch currentComponent.style.tableDirection {
            case .horizontal:
                // Horizontal: alternating rows
                let rowIndex = item.rowIndex ?? 0
                isAlternating = currentComponent.style.useAlternatingRows && rowIndex % 2 == 1
            case .vertical:
                // Vertical: alternating columns (banded columns)
                let columnIndex = item.columnIndex ?? 0
                isAlternating = currentComponent.style.useAlternatingRows && columnIndex % 2 == 1
            }
            return isAlternating ? currentComponent.style.tableRowAltColorSwiftUI : currentComponent.style.tableRowColorSwiftUI
        }
    }
    
    // MARK: - Dynamic Column Detection
    
    /// Detect the number of columns from any TableItem data
    func detectColumnCount<T: TableItem>(from data: [[T]]) -> Int {
        return data.first?.count ?? 0
    }
    
    /// Initialize column configurations for a given data structure
    func initializeColumnsForData<T: TableItem>(_ data: [[T]]) {
        let columnCount = detectColumnCount(from: data)
        if columnCount > 0 && currentComponent.style.columnConfigurations.isEmpty {
            document.initializeColumnConfigurations(for: currentComponent.id, columnCount: columnCount)
        }
    }
    
    /// Resolves the effective line limit for a given item using per-cell configuration
    /// first, then falling back to row/column defaults set in the DocumentGrid property editor.
    ///
    /// Priority:
    /// 1. Row/Column line limit (from DocumentGrid property editor)
    /// 2. Default of 1 line (fallback)
    private func effectiveLineLimit(for item: DocumentTableItem) -> Int {
        switch currentComponent.style.tableDirection {
        case .horizontal:
            // Horizontal: use column line limit
            if let col = item.columnIndex {
                return currentComponent.style.columnConfiguration(for: col).lineLimit
            }
        case .vertical:
            // Vertical: use row line limit
            if let row = item.rowIndex {
                return currentComponent.style.rowConfiguration(for: row).lineLimit
            }
        }

        // Fallback: 1 line
        return 1
    }
    
    /// Converts the current alignment system to gridCellAnchor for proper SwiftUI Grid alignment
    private func gridCellAnchorForItem(_ item: DocumentTableItem) -> UnitPoint {
        let horizontalAlignment = effectiveTextAlignment(for: item)
        let verticalAlignment = effectiveVerticalAlignment(for: item)

        // Combine horizontal and vertical alignments to create the appropriate grid cell anchor
        switch (horizontalAlignment.horizontalAlignment, verticalAlignment) {
        case (.leading, .top):
            return .topLeading
        case (.center, .top):
            return .top
        case (.trailing, .top):
            return .topTrailing
        case (.leading, .center):
            return .leading
        case (.center, .center):
            return .center
        case (.trailing, .center):
            return .trailing
        case (.leading, .bottom):
            return .bottomLeading
        case (.center, .bottom):
            return .bottom
        case (.trailing, .bottom):
            return .bottomTrailing
        case (.leading, .firstTextBaseline):
            return .topLeading
        case (.center, .firstTextBaseline):
            return .top
        case (.trailing, .firstTextBaseline):
            return .topTrailing
        case (.leading, .lastTextBaseline):
            return .bottomLeading
        case (.center, .lastTextBaseline):
            return .bottom
        case (.trailing, .lastTextBaseline):
            return .bottomTrailing
        default:
            return .center // Fallback to center alignment
        }
    }
    
    /// Converts UnitPoint to Alignment for ZStack alignment
    private func alignmentFromUnitPoint(_ unitPoint: UnitPoint) -> Alignment {
        switch unitPoint {
        case .topLeading:
            return .topLeading
        case .top:
            return .top
        case .topTrailing:
            return .topTrailing
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        case .bottomLeading:
            return .bottomLeading
        case .bottom:
            return .bottom
        case .bottomTrailing:
            return .bottomTrailing
        default:
            return .center
        }
    }
    
    /// Converts custom TextAlignment to SwiftUI TextAlignment
    private func swiftUITextAlignment(_ textAlignment: TextAlignment) -> SwiftUI.TextAlignment {
        switch textAlignment {
        case .leading:
            return .leading
        case .center:
            return .center
        case .trailing:
            return .trailing
        }
    }
    
}


// MARK: - DocumentGridPropertyEditor

/// Property editor for the document grid component with advanced grid-specific options
struct DocumentGridPropertyEditor: View {
    @EnvironmentObject private var document: InvoiceDocument
    @EnvironmentObject private var templateDataService: TemplateDataService
    @Environment(\.modelContext) private var modelContext
    let component: InvoiceComponent
    let clientId: UUID?
    let invoiceId: UUID?
    
    // State for TabView selection
    @State private var selectedColumnTab = 0
    
    // Initializer with default values for optional parameters
    init(component: InvoiceComponent, clientId: UUID? = nil, invoiceId: UUID? = nil) {
        self.component = component
        self.clientId = clientId
        self.invoiceId = invoiceId
    }
    
    /// Ensures the selected tab is within valid bounds
    private var validSelectedTab: Int {
        min(selectedColumnTab, max(0, tabCount - 1))
    }
    
    // Ensure the property editor updates when the component changes
    private var currentComponent: InvoiceComponent {
        document.components.first { $0.id == component.id } ?? component
    }
    
    // Get the number of columns from the sample data
    @State private var hasInitializedPropertyEditorColumns = false
    
    private var columnCount: Int {
        // Get the actual number of columns from the sample data
        let sampleData = generateSampleData()
        let detectedCount = sampleData.first?.count ?? 4
        
        // Note: Initialization is deferred to avoid modifying @Published properties
        // from computed properties. Use .onAppear or Task for initialization.
        
        return detectedCount
    }
    
    private func initializePropertyEditorColumnsIfNeeded() {
        guard !hasInitializedPropertyEditorColumns else { return }
        
        let sampleData = generateSampleData()
        let detectedCount = sampleData.first?.count ?? 4
        
        // Initialize configurations based on table direction
        if currentComponent.style.tableDirection == .horizontal {
            if currentComponent.style.columnConfigurations.isEmpty {
                document.initializeColumnConfigurations(for: currentComponent.id, columnCount: detectedCount)
                hasInitializedPropertyEditorColumns = true
            }
        } else {
            if currentComponent.style.rowConfigurations.isEmpty {
                document.initializeRowConfigurations(for: currentComponent.id, rowCount: detectedCount)
                hasInitializedPropertyEditorColumns = true
            }
        }
    }
    
    /// Returns the number of tabs needed based on table direction (for rows/data fields)
    private var tabCount: Int {
        let sampleData = generateSampleData()
        let direction = currentComponent.style.tableDirection
        
        let count: Int
        switch direction {
        case .horizontal:
            // For horizontal tables, tabs represent columns
            count = sampleData.first?.count ?? 4
        case .vertical:
            // For vertical tables, tabs represent the number of data fields (rows)
            // Each row in vertical layout represents one field that can be configured
            count = sampleData.count
        }
        
        return count
    }
    
    /// Returns the number of columns (for vertical tables to configure column widths)
    private var columnCountForVertical: Int {
        let sampleData = generateSampleData()
        return sampleData.first?.count ?? 2 // Usually 2 for vertical (label + value)
    }
    
    /// Generates section-specific data for section components
    private func generateSectionData() -> [[DocumentTableItem]] {
        let generator = DocumentGridDataGenerator(
            component: currentComponent,
            templateDataService: templateDataService,
            clientId: clientId,
            invoiceId: invoiceId
        )
        return generator.generateSectionData()
    }
    
    // Generate sample data for the property editor
    private func generateSampleData() -> [[DocumentTableItem]] {
        let generator = DocumentGridDataGenerator(
            component: currentComponent,
            templateDataService: templateDataService,
            clientId: clientId,
            invoiceId: invoiceId
        )
        return generator.generateSampleData()
    }
    
    // MARK: - Direction-Aware Configuration Helpers
    
    /// Gets the appropriate configuration for the given tab index based on table direction
    private func getConfigurationForTab(_ tabIndex: Int) -> Any {
        switch currentComponent.style.tableDirection {
        case .horizontal:
            // For horizontal tables, return column configuration
            return currentComponent.style.columnConfiguration(for: tabIndex)
        case .vertical:
            // For vertical tables, return row configuration
            return currentComponent.style.rowConfiguration(for: tabIndex)
        }
    }
    
    /// Gets column configuration for horizontal tables
    private func getColumnConfigurationForTab(_ tabIndex: Int) -> ComponentStyle.ColumnConfiguration {
        return currentComponent.style.columnConfiguration(for: tabIndex)
    }
    
    /// Gets row configuration for vertical tables
    private func getRowConfigurationForTab(_ tabIndex: Int) -> ComponentStyle.RowConfiguration {
        return currentComponent.style.rowConfiguration(for: tabIndex)
    }
    
    /// Updates alignment for the given tab index based on table direction
    private func updateAlignmentForTab(_ tabIndex: Int, alignment: TextAlignment) {
        switch currentComponent.style.tableDirection {
        case .horizontal:
            // For horizontal tables, update column alignment
            document.updateColumnAlignment(for: currentComponent.id, columnIndex: tabIndex, alignment: alignment)
        case .vertical:
            // For vertical tables, update row alignment
            document.updateRowAlignment(for: currentComponent.id, rowIndex: tabIndex, alignment: alignment)
        }
    }
    
    /// Updates vertical alignment for the given tab index based on table direction
    private func updateVerticalAlignmentForTab(_ tabIndex: Int, verticalAlignment: VerticalAlignment) {
        switch currentComponent.style.tableDirection {
        case .horizontal:
            document.updateColumnVerticalAlignment(for: currentComponent.id, columnIndex: tabIndex, verticalAlignment: verticalAlignment)
        case .vertical:
            document.updateRowVerticalAlignment(for: currentComponent.id, rowIndex: tabIndex, verticalAlignment: verticalAlignment)
        }
    }
    
    /// Updates header alignment for the given tab index based on table direction
    private func updateHeaderAlignmentForTab(_ tabIndex: Int, alignment: TextAlignment) {
        switch currentComponent.style.tableDirection {
        case .horizontal:
            document.updateColumnHeaderAlignment(for: currentComponent.id, columnIndex: tabIndex, alignment: alignment)
        case .vertical:
            document.updateRowHeaderAlignment(for: currentComponent.id, rowIndex: tabIndex, alignment: alignment)
        }
    }
    
    /// Updates header vertical alignment for the given tab index based on table direction
    private func updateHeaderVerticalAlignmentForTab(_ tabIndex: Int, verticalAlignment: VerticalAlignment) {
        switch currentComponent.style.tableDirection {
        case .horizontal:
            document.updateColumnHeaderVerticalAlignment(for: currentComponent.id, columnIndex: tabIndex, verticalAlignment: verticalAlignment)
        case .vertical:
            document.updateRowHeaderVerticalAlignment(for: currentComponent.id, rowIndex: tabIndex, verticalAlignment: verticalAlignment)
        }
    }
    
    /// Updates flexibility for the given tab index based on table direction
    private func updateFlexibilityForTab(_ tabIndex: Int, isFlexible: Bool) {
        switch currentComponent.style.tableDirection {
        case .horizontal:
            document.updateColumnIsFlexible(for: currentComponent.id, columnIndex: tabIndex, isFlexible: isFlexible)
        case .vertical:
            document.updateRowIsFlexible(for: currentComponent.id, rowIndex: tabIndex, isFlexible: isFlexible)
        }
    }
    
    /// Updates width for the given tab index based on table direction
    private func updateWidthForTab(_ tabIndex: Int, width: CGFloat) {
        switch currentComponent.style.tableDirection {
        case .horizontal:
            document.updateColumnWidth(for: currentComponent.id, columnIndex: tabIndex, width: width)
        case .vertical:
            document.updateColumnWidth(for: currentComponent.id, columnIndex: tabIndex, width: width)
        }
    }
    
    /// Updates auto-sizing for the given tab index based on table direction
    private func updateAutoSizingForTab(_ tabIndex: Int, isAutoSized: Bool) {
        switch currentComponent.style.tableDirection {
        case .horizontal:
            document.updateColumnAutoSizing(for: currentComponent.id, columnIndex: tabIndex, isAutoSized: isAutoSized)
        case .vertical:
            document.updateRowAutoSizing(for: currentComponent.id, rowIndex: tabIndex, isAutoSized: isAutoSized)
        }
    }

    /// Updates line limit for the given tab index based on table direction
    private func updateLineLimitForTab(_ tabIndex: Int, lineLimit: Int) {
        switch currentComponent.style.tableDirection {
        case .horizontal:
            document.updateColumnLineLimit(for: currentComponent.id, columnIndex: tabIndex, lineLimit: lineLimit)
        case .vertical:
            document.updateRowLineLimit(for: currentComponent.id, rowIndex: tabIndex, lineLimit: lineLimit)
        }
    }

    /// Gets line limit for the given tab index based on table direction
    private func getLineLimitForTab(_ tabIndex: Int) -> Int {
        switch currentComponent.style.tableDirection {
        case .horizontal:
            return getColumnConfigurationForTab(tabIndex).lineLimit
        case .vertical:
            return getRowConfigurationForTab(tabIndex).lineLimit
        }
    }

    private func generateTypographyGroup() -> some View {
        Group {
            generateFontFamilyPicker()
            generateFontSizeAndWeightRow()
            generateSpacingRow()
            generateLineLimitSlider()
        }
        .padding()
    }

    private func generateFontFamilyPicker() -> some View {
        ControlRowContainer {
        LabeledContent("Font Family", content: {
            Picker("Font Family", selection: Binding(
                get: { FontFamilyOption(styleValue: currentComponent.style.fontFamily) },
                set: { document.updateFontFamily(for: currentComponent.id, family: $0.styleValue) }
            )) {
                ForEach(FontFamilyOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
        })
            .padding(.vertical, 3)
        }
    }

    private func generateFontSizeAndWeightRow() -> some View {
        Group {
            generateFontSizeSlider()
            generateFontWeightPicker()
        }
    }

    private func generateFontSizeSlider() -> some View {
        ControlRowContainer {
        LabeledContent("Size", content: {
            Group {
                Slider(
                    value: Binding(
                        get: { Double(currentComponent.style.fontSize) },
                        set: { document.updateFontSize(for: currentComponent.id, fontSize: CGFloat($0)) }
                    ),
                    in: 8...48,
                    step: 1
                )
                Text("\(Int(currentComponent.style.fontSize))")
                    .monospacedDigit()
            }
        })
            .padding(.vertical, 3)
        }
    }

    private func generateFontWeightPicker() -> some View {
        ControlRowContainer {
        LabeledContent("Weight", content: {
            Picker("Weight", selection: Binding(
                get: { FontWeightOption(styleValue: currentComponent.style.fontWeight) },
                set: { document.updateFontWeight(for: currentComponent.id, weight: $0.styleValue) }
            )) {
                ForEach(FontWeightOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.menu)
        })
            .padding(.vertical, 3)
        }
    }

    private func generateSpacingRow() -> some View {
        Group {
            generateLineSpacingSlider()
            generateLetterSpacingSlider()
        }
    }

    private func generateLineSpacingSlider() -> some View {
        ControlRowContainer {
        LabeledContent("Line Spacing", content: {
            Group {
                Slider(
                    value: Binding(
                        get: { Double(currentComponent.style.lineSpacing) },
                        set: { document.updateLineSpacing(for: currentComponent.id, spacing: CGFloat($0)) }
                    ),
                    in: 0.8...2.5,
                    step: 0.05
                )
                Text(String(format: "%.2f", currentComponent.style.lineSpacing))
                    .monospacedDigit()
            }
        })
            .padding(.vertical, 3)
        }
    }

    private func generateLetterSpacingSlider() -> some View {
        ControlRowContainer {
        LabeledContent("Letter Spacing", content: {
            Group {
                Slider(
                    value: Binding(
                        get: { Double(currentComponent.style.letterSpacing) },
                        set: { document.updateLetterSpacing(for: currentComponent.id, spacing: CGFloat($0)) }
                    ),
                    in: -2...10,
                    step: 0.1
                )
                Text(String(format: "%.1f", currentComponent.style.letterSpacing))
                    .monospacedDigit()
            }
        })
            .padding(.vertical, 3)
        }
    }

    private func generateLineLimitSlider() -> some View {
        ControlRowContainer {
        LabeledContent("Line Limit", content: {
            Group {
                Slider(
                    value: Binding(
                        get: { Double(getLineLimitForTab(selectedColumnTab)) },
                        set: { updateLineLimitForTab(selectedColumnTab, lineLimit: Int($0)) }
                    ),
                    in: 1...5,
                    step: 1
                )
                Text("\(getLineLimitForTab(selectedColumnTab))")
                    .monospacedDigit()
            }
        })
            .padding(.vertical, 3)
        }
    }
    
    // Generate direction-aware tabs (columns for horizontal, rows for vertical)
    private func generateDirectionTabs() -> some View {
        let tabSelection = Binding(
            get: { validSelectedTab },
            set: { selectedColumnTab = $0 }
        )
        
        return TabView(selection: tabSelection) {
            ForEach(Array(0..<tabCount), id: \.self) { index in
                generateTabContent(for: index)
                    .tabItem {
                        Label(currentComponent.style.tableDirection == .horizontal ? 
                              "Column \(index + 1)" : 
                              "Row \(index + 1)", 
                              systemImage: "\(index + 1).circle")
                    }
                    .tag(index)
            }
        }
        .frame(height: 450)
        .padding(.horizontal, 8)
        .onChange(of: tabCount) { _, newCount in
            // Reset selected tab if it's out of bounds
            if selectedColumnTab >= newCount {
                selectedColumnTab = max(0, newCount - 1)
            }
        }
    }
    
    private func generateTabContent(for index: Int) -> some View {
        Group {
            generateTypographyGroup()
            generateDataCellAlignmentGroup(for: index)
            generateHeaderAlignmentGroup(for: index)
        }
        .padding()
    }
    

    
    private func generateDataCellAlignmentGroup(for index: Int) -> some View {
                        AlignmentGridPicker(
            label: "Data Cell Alignment",
                            horizontalAlignment: Binding(
                                get: { 
                                    switch currentComponent.style.tableDirection {
                                    case .horizontal:
                                        return getColumnConfigurationForTab(index).alignment
                                    case .vertical:
                                        return getRowConfigurationForTab(index).alignment
                                    }
                                },
                                set: { updateAlignmentForTab(index, alignment: $0) }
                            ),
                            verticalAlignment: Binding(
                                get: { 
                                    switch currentComponent.style.tableDirection {
                                    case .horizontal:
                                        return getColumnConfigurationForTab(index).verticalAlignment
                                    case .vertical:
                                        return getRowConfigurationForTab(index).verticalAlignment
                                    }
                                },
                                set: { updateVerticalAlignmentForTab(index, verticalAlignment: $0) }
                            )
                        )
            .padding()
    }
    
    private func generateHeaderAlignmentGroup(for index: Int) -> some View {
                        AlignmentGridPicker(
            label: "Header Alignment",
                            horizontalAlignment: Binding(
                                get: { 
                                    switch currentComponent.style.tableDirection {
                                    case .horizontal:
                                        return getColumnConfigurationForTab(index).headerAlignment
                                    case .vertical:
                                        return getRowConfigurationForTab(index).headerAlignment
                                    }
                                },
                                set: { updateHeaderAlignmentForTab(index, alignment: $0) }
                            ),
                            verticalAlignment: Binding(
                                get: { 
                                    switch currentComponent.style.tableDirection {
                                    case .horizontal:
                                        return getColumnConfigurationForTab(index).headerVerticalAlignment
                                    case .vertical:
                                        return getRowConfigurationForTab(index).headerVerticalAlignment
                                    }
                                },
                                set: { updateHeaderVerticalAlignmentForTab(index, verticalAlignment: $0) }
                            )
                        )
            .padding()
    }
    
    // Generate column tabs for horizontal tables (for configuring column widths)
    @State private var selectedHorizontalColumnTab = 0
    
    // Generate column tabs for vertical tables (for configuring column widths)
    @State private var selectedVerticalColumnTab = 0
    
    private func generateColumnTabsForHorizontal() -> some View {
        TabView(selection: $selectedHorizontalColumnTab) {
            ForEach(Array(0..<columnCount), id: \.self) { columnIndex in
                Group {
                    Text("Column \(columnIndex + 1) Width Settings")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                        .padding(.vertical, 4)
                    
                    Divider()
                        .background(Color(NSColor.separatorColor).opacity(0.3))
                        .padding(.vertical, 4)
                    
                    // Width Behavior Section
                    Group {
                        Text("Width Behavior")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(NSColor.secondaryLabelColor))
                            .padding(.vertical, 4)
                        
                        ControlRowContainer {
                        LabeledContent("Flexible Width", content: {
                            Toggle("", isOn: Binding(
                                get: { currentComponent.style.columnConfiguration(for: columnIndex).isFlexible },
                                set: { document.updateColumnIsFlexible(for: currentComponent.id, columnIndex: columnIndex, isFlexible: $0) }
                            ))
                            .labelsHidden()
                        })
                            .padding(.vertical, 3)
                        }
                        
                        ControlRowContainer {
                        LabeledContent("Auto-Size Width", content: {
                            Toggle("", isOn: Binding(
                                get: { currentComponent.style.columnConfiguration(for: columnIndex).isAutoSized },
                                set: { document.updateColumnAutoSizing(for: currentComponent.id, columnIndex: columnIndex, isAutoSized: $0) }
                            ))
                            .labelsHidden()
                        })
                            .padding(.vertical, 3)
                        }
                        
                        if !currentComponent.style.columnConfiguration(for: columnIndex).isFlexible {
                            ControlRowContainer {
                            LabeledContent("Fixed Width", content: {
                                Group {
                                    Slider(
                                        value: Binding(
                                            get: { Double(currentComponent.style.columnConfiguration(for: columnIndex).width) },
                                            set: { document.updateColumnWidth(for: currentComponent.id, columnIndex: columnIndex, width: CGFloat($0)) }
                                        ),
                                        in: 50...300,
                                step: 10
                                    )
                                    Text("\(Int(currentComponent.style.columnConfiguration(for: columnIndex).width))")
                                        .monospacedDigit()
                            }
                            })
                                .padding(.vertical, 3)
                            }
                        }
                    }
                }
                .padding()
                .tabItem {
                    Label("Column \(columnIndex + 1)", systemImage: "\(columnIndex + 1).circle")
                }
                .tag(columnIndex)
            }
        }
        .frame(height: 300)
        .padding(.horizontal, 8)
        .onChange(of: columnCount) { _, newCount in
            // Reset selected tab if it's out of bounds
            if selectedHorizontalColumnTab >= newCount {
                selectedHorizontalColumnTab = max(0, newCount - 1)
            }
        }
    }
    
    private func generateColumnTabsForVertical() -> some View {
        TabView(selection: $selectedVerticalColumnTab) {
            ForEach(Array(0..<columnCountForVertical), id: \.self) { columnIndex in
                Group {
                    Text("Column \(columnIndex + 1) Width Settings")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                        .padding(.vertical, 4)
                    
                    Divider()
                        .background(Color(NSColor.separatorColor).opacity(0.3))
                        .padding(.vertical, 4)
                    
                    // Width Behavior Section
                    Group {
                        Text("Width Behavior")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color(NSColor.secondaryLabelColor))
                            .padding(.vertical, 4)
                        
                        ControlRowContainer {
                        LabeledContent("Flexible Width", content: {
                            Toggle("", isOn: Binding(
                                get: { currentComponent.style.columnConfiguration(for: columnIndex).isFlexible },
                                set: { document.updateColumnIsFlexible(for: currentComponent.id, columnIndex: columnIndex, isFlexible: $0) }
                            ))
                            .labelsHidden()
                        })
                            .padding(.vertical, 3)
                        }
                        
                        ControlRowContainer {
                        LabeledContent("Auto-Size Width", content: {
                            Toggle("", isOn: Binding(
                                get: { currentComponent.style.columnConfiguration(for: columnIndex).isAutoSized },
                                set: { document.updateColumnAutoSizing(for: currentComponent.id, columnIndex: columnIndex, isAutoSized: $0) }
                            ))
                            .labelsHidden()
                        })
                            .padding(.vertical, 3)
                        }
                        
                        if !currentComponent.style.columnConfiguration(for: columnIndex).isFlexible {
                            ControlRowContainer {
                            LabeledContent("Fixed Width", content: {
                                Group {
                                    Slider(
                                        value: Binding(
                                            get: { Double(currentComponent.style.columnConfiguration(for: columnIndex).width) },
                                            set: { document.updateColumnWidth(for: currentComponent.id, columnIndex: columnIndex, width: CGFloat($0)) }
                                        ),
                                        in: 50...300,
                                step: 10
                                    )
                                    Text("\(Int(currentComponent.style.columnConfiguration(for: columnIndex).width))")
                                        .monospacedDigit()
                            }
                            })
                                .padding(.vertical, 3)
                            }
                        }
                    }
                }
                .padding()
                .tabItem {
                    Label("Column \(columnIndex + 1)", systemImage: "\(columnIndex + 1).circle")
                }
                .tag(columnIndex)
            }
        }
        .frame(height: 300)
        .padding(.horizontal, 8)
        .onChange(of: columnCountForVertical) { _, newCount in
            // Reset selected tab if it's out of bounds
            if selectedVerticalColumnTab >= newCount {
                selectedVerticalColumnTab = max(0, newCount - 1)
            }
        }
    }
    
    var body: some View {
        Form {
            // Section 1: Layout
            Section("Layout") {
                // Table Direction - Segmented Picker
                Picker("Table Direction", selection: Binding(
                    get: { currentComponent.style.tableDirection },
                    set: { document.updateTableDirection(for: currentComponent.id, direction: $0) }
                )) {
                    Text("Horizontal").tag(TableDirection.horizontal)
                    Text("Vertical").tag(TableDirection.vertical)
                }
                .pickerStyle(.segmented)
                
                // Show Header - Toggle
                Toggle("Show Header", isOn: Binding(
                    get: { currentComponent.style.showTableHeader },
                    set: { document.updateShowTableHeader(for: currentComponent.id, show: $0) }
                ))
                
                // Column Width Settings
                if currentComponent.style.tableDirection == .horizontal {
                    generateColumnTabsForHorizontal()
                        .padding()
                } else {
                    generateColumnTabsForVertical()
                        .padding()
                }
            }
            
            // Section 2: Content
            Section("Content") {
                generateDirectionTabs()
                
                Text(currentComponent.style.tableDirection == .horizontal ? 
                     "• Each column can have separate alignment settings for headers and data cells, plus width behavior" :
                     "• Each row can have separate alignment settings for headers and data cells, plus height behavior")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            
            // Section 3: Fill
            Section("Fill") {
                // Text Group
                Group {
                    ControlRowContainer {
                    LabeledContent("Color", content: {
                        Group {
                            ColorPicker("", selection: Binding(
                                get: { currentComponent.style.textColorSwiftUI },
                                set: { document.updateTextColor(for: currentComponent.id, color: $0.toHex().replacingOccurrences(of: "#", with: "").uppercased()) }
                            ))
                            .labelsHidden()
                            
                            TextField("Hex", text: Binding(
                                get: { "#\(currentComponent.style.textColor)" },
                                set: { 
                                    let hex = $0.replacingOccurrences(of: "#", with: "")
                                    document.updateTextColor(for: currentComponent.id, color: hex.uppercased())
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                    })
                        .padding(.vertical, 3)
                    }
                    
                    ControlRowContainer {
                    LabeledContent("Opacity", content: {
                        Group {
                            Slider(
                                value: Binding(
                                    get: { Double(currentComponent.style.textOpacity) },
                                    set: { document.updateTextOpacity(for: currentComponent.id, opacity: CGFloat($0)) }
                                ),
                                in: 0...1,
                                step: 0.05
                            )
                            Text(String(format: "%.2f", currentComponent.style.textOpacity))
                                .monospacedDigit()
                        }
                    })
                        .padding(.vertical, 3)
                    }
                }
                .padding()
                
                // Backgrounds Group
                Group {
                    ControlRowContainer {
                    LabeledContent("Header", content: {
                            Group {
                                ColorPicker("", selection: Binding(
                                    get: { currentComponent.style.tableHeaderColorSwiftUI },
                                    set: { document.updateTableHeaderColor(for: currentComponent.id, color: $0.toHex().replacingOccurrences(of: "#", with: "").uppercased()) }
                                ))
                                .labelsHidden()
                                
                                TextField("Hex", text: Binding(
                                    get: { "#\(currentComponent.style.tableHeaderColor)" },
                                    set: { 
                                        let hex = $0.replacingOccurrences(of: "#", with: "")
                                        document.updateTableHeaderColor(for: currentComponent.id, color: hex.uppercased())
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                        })
                        .padding(.vertical, 3)
                    }
                        
                        ControlRowContainer {
                        LabeledContent(currentComponent.style.tableDirection == .horizontal ? "1st Row" : "1st Column", content: {
                            Group {
                                ColorPicker("", selection: Binding(
                                    get: { currentComponent.style.tableRowColorSwiftUI },
                                    set: { document.updateTableRowColor(for: currentComponent.id, color: $0.toHex().replacingOccurrences(of: "#", with: "").uppercased()) }
                                ))
                                .labelsHidden()
                                
                                TextField("Hex", text: Binding(
                                    get: { "#\(currentComponent.style.tableRowColor)" },
                                    set: { 
                                        let hex = $0.replacingOccurrences(of: "#", with: "")
                                        document.updateTableRowColor(for: currentComponent.id, color: hex.uppercased())
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                        })
                        .padding(.vertical, 3)
                    }
                        
                        ControlRowContainer {
                        LabeledContent(currentComponent.style.tableDirection == .horizontal ? "2nd Row" : "2nd Column", content: {
                            Group {
                                ColorPicker("", selection: Binding(
                                    get: { currentComponent.style.tableRowAltColorSwiftUI },
                                    set: { document.updateTableRowAltColor(for: currentComponent.id, color: $0.toHex().replacingOccurrences(of: "#", with: "").uppercased()) }
                                ))
                                .labelsHidden()
                                
                                TextField("Hex", text: Binding(
                                    get: { "#\(currentComponent.style.tableRowAltColor)" },
                                    set: { 
                                        let hex = $0.replacingOccurrences(of: "#", with: "")
                                        document.updateTableRowAltColor(for: currentComponent.id, color: hex.uppercased())
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                        })
                        .padding(.vertical, 3)
                    }
                        
                        ControlRowContainer {
                        LabeledContent(currentComponent.style.tableDirection == .horizontal ? "Alternating Rows" : "Banded Columns", content: {
                            Toggle("", isOn: Binding(
                                get: { currentComponent.style.useAlternatingRows },
                                set: { document.updateUseAlternatingRows(for: currentComponent.id, use: $0) }
                            ))
                            .labelsHidden()
                        })
                        .padding(.vertical, 3)
                    }
                    }
                    .padding()
                }
            }
            
            // Section 4: Stroke
            Section("Stroke") {
                Toggle("Show Borders", isOn: Binding(
                    get: { currentComponent.style.showTableBorders },
                    set: { document.updateShowTableBorders(for: currentComponent.id, show: $0) }
                ))
                
                if currentComponent.style.showTableBorders {
                    Group {
                        ControlRowContainer {
                        LabeledContent("Width", content: {
                            Group {
                                Slider(
                                    value: Binding(
                                        get: { Double(currentComponent.style.tableBorderWidth) },
                                        set: { document.updateTableBorderWidth(for: currentComponent.id, width: CGFloat($0)) }
                                    ),
                                    in: 0.5...3.0,
                                    step: 0.1
                                )
                                Text(String(format: "%.1f", currentComponent.style.tableBorderWidth))
                                    .monospacedDigit()
                            }
                        })
                            .padding(.vertical, 3)
                        }
                            
                        ControlRowContainer {
                        LabeledContent("Color", content: {
                            Group {
                                ColorPicker("", selection: Binding(
                                    get: { currentComponent.style.tableBorderColorSwiftUI },
                                    set: { document.updateTableBorderColor(for: currentComponent.id, color: $0.toHex().replacingOccurrences(of: "#", with: "").uppercased()) }
                                ))
                                .labelsHidden()
                                
                                TextField("Hex", text: Binding(
                                    get: { "#\(currentComponent.style.tableBorderColor)" },
                                    set: { 
                                        let hex = $0.replacingOccurrences(of: "#", with: "")
                                        document.updateTableBorderColor(for: currentComponent.id, color: hex.uppercased())
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                        })
                            .padding(.vertical, 3)
                        }
                    }
                    .padding()
                }
            }
            
            // Section 5: Effects
            Section("Effects") {
                Toggle("Enable Shadow", isOn: Binding(
                    get: { currentComponent.style.shadowEnabled },
                    set: { document.updateShadowEnabled(for: currentComponent.id, enabled: $0) }
                ))
                
                if currentComponent.style.shadowEnabled {
                    Group {
                        ControlRowContainer {
                        LabeledContent("Radius", content: {
                            Group {
                                Slider(
                                    value: Binding(
                                        get: { Double(currentComponent.style.shadowRadius) },
                                        set: { document.updateShadowRadius(for: currentComponent.id, radius: CGFloat($0)) }
                                    ),
                                        in: 0...20,
                        step: 0.5
                                )
                                Text(String(format: "%.1f", currentComponent.style.shadowRadius))
                                    .monospacedDigit()
                            }
                        })
                            .padding(.vertical, 3)
                        }
                            
                        ControlRowContainer {
                        LabeledContent("Opacity", content: {
                            Group {
                                Slider(
                                    value: Binding(
                                        get: { Double(currentComponent.style.shadowOpacity) },
                                        set: { document.updateShadowOpacity(for: currentComponent.id, opacity: CGFloat($0)) }
                                    ),
                                        in: 0...1,
                                        step: 0.05
                                )
                                Text(String(format: "%.2f", currentComponent.style.shadowOpacity))
                                    .monospacedDigit()
                            }
                        })
                            .padding(.vertical, 3)
                        }
                            
                        ControlRowContainer {
                        LabeledContent("Offset", content: {
                            Group {
                                Group {
                                    Text("X:")
                                    
                                    Slider(
                                        value: Binding(
                                            get: { Double(currentComponent.style.shadowOffsetX) },
                                            set: { document.updateShadowOffset(for: currentComponent.id, x: CGFloat($0), y: currentComponent.style.shadowOffsetY) }
                                        ),
                                        in: -10...10,
                                        step: 1
                                    )
                                    Text("\(Int(currentComponent.style.shadowOffsetX))")
                                }
                                
                                Group {
                                    Text("Y:")
                                    
                                    Slider(
                                        value: Binding(
                                            get: { Double(currentComponent.style.shadowOffsetY) },
                                            set: { document.updateShadowOffset(for: currentComponent.id, x: currentComponent.style.shadowOffsetX, y: CGFloat($0)) }
                                        ),
                                        in: -10...10,
                                        step: 1
                                    )
                                    Text("\(Int(currentComponent.style.shadowOffsetY))")
                                }
                            }
                        })
                        .padding(.vertical, 3)
                        }
                            
                        ControlRowContainer {
                        LabeledContent("Color", content: {
                            Group {
                                ColorPicker("", selection: Binding(
                                    get: { currentComponent.style.shadowColorSwiftUI },
                                    set: { document.updateShadowColor(for: currentComponent.id, color: $0.toHex().replacingOccurrences(of: "#", with: "").uppercased()) }
                                ))
                                .labelsHidden()
                                
                                TextField("Hex", text: Binding(
                                    get: { "#\(currentComponent.style.shadowColor)" },
                                    set: { 
                                        let hex = $0.replacingOccurrences(of: "#", with: "")
                                        document.updateShadowColor(for: currentComponent.id, color: hex.uppercased())
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                        })
                        .padding(.vertical, 3)
                        }
                    }
                    .padding()
                }
            }
            
            // Section 6: Spacing
            Section("Spacing") {
                Group {
                    ControlRowContainer {
                    LabeledContent {
                        Group {
                            Slider(
                                value: Binding(
                                    get: { Double(currentComponent.style.tableHeaderPadding) },
                                    set: { document.updateTableHeaderPadding(for: currentComponent.id, padding: CGFloat($0)) }
                                ),
                                in: 4...20,
                    step: 1
                            )
                            Text("\(Int(currentComponent.style.tableHeaderPadding))")
                                .monospacedDigit()
                        }
                    } label: {
                        Label("Header", systemImage: "square.stack.3d.up")
                        }
                        .padding(.vertical, 3)
                    }
                    
                    ControlRowContainer {
                    LabeledContent {
                        Group {
                            Slider(
                                value: Binding(
                                    get: { Double(currentComponent.style.tableCellPadding) },
                                    set: { document.updateTableCellPadding(for: currentComponent.id, padding: CGFloat($0)) }
                                ),
                                in: 4...20,
                    step: 1
                            )
                            Text("\(Int(currentComponent.style.tableCellPadding))")
                                .monospacedDigit()
                        }
                    } label: {
                        Label("Cell", systemImage: "square.grid.2x2")
                        }
                        .padding(.vertical, 3)
                    }
                    
                }
                .padding()
            }
        
        .formStyle(.grouped)
        .id(currentComponent.id) // Force re-render when component changes
        .onAppear {
            // Initialize columns when property editor appears to avoid infinite loops
            initializePropertyEditorColumnsIfNeeded()
        }
    }
}

// MARK: - Cell Height Reporter

private struct DocumentGridCellHeightReporter: View {
    let rowIndex: Int?
    @Environment(\.documentGridMeasurementPhase) private var measurementPhase
    
    var body: some View {
        Group {
            if measurementPhase == .content, let rowIndex {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: DocumentGridCellHeightPreferenceKey.self,
                        value: [DocumentGridCellHeightMeasurement(rowIndex: rowIndex, height: geometry.size.height)]
                    )
                }
            } else {
                Color.clear
            }
        }
    }
}
