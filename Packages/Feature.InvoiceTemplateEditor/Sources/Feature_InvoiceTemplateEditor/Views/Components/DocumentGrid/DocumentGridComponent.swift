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
        VStack(alignment: .leading, spacing: 0) {
            if !currentComponent.style.sectionTitle.isEmpty {
                sectionTitleView
                    .frame(width: gridWidth > 0 ? gridWidth : nil, alignment: .leading)
                    .id(sectionTitleIdentifier)
            }
            
            DocumentGridView(
                data: cachedSampleData,
                columnConfigs: columnConfigurations,
                borderAppearance: borderAppearance,
                onCellTap: { rowIndex, columnIndex in
                    document.selectTableElement(.cell(row: rowIndex, column: columnIndex), in: component.id)
                },
                selectedCell: selectedCellIndices,
                selectedRange: selectedRangeIndices,
                selectedRow: selectedRowIndex,
                selectedColumn: selectedColumnIndex,
                onSelectionChange: { selection in
                    document.selectTableElement(selection, in: component.id)
                }
            ) { item in
                renderGridCell(for: item)
            }
            .background(
                GeometryReader { geometry in
                    Color.clear.onAppear {
                        gridWidth = geometry.size.width
                    }
                    .onChange(of: geometry.size.width) { _, newWidth in
                        gridWidth = newWidth
                    }
                }
            )
            .overlay(alignment: .topLeading) {
                // Table handle inside grid's top-left corner
                tableHandle
                    .padding(4)
            }
            .onHover { hovering in
                isHoveringGrid = hovering
            }
        }
        .shadow(
            color: shadowColor,
            radius: currentComponent.style.shadowRadius,
            x: currentComponent.style.shadowOffsetX,
            y: currentComponent.style.shadowOffsetY
        )
        .background(sizeMeasurementLayer)
        .onPreferenceChange(ColumnWidthPreferenceKey.self) { widths in
            updateColumnWidths(widths)
        }
        .onPreferenceChange(GridIdealWidthPreferenceKey.self) { idealWidth in
            updateComponentWidth(idealWidth)
        }
        .id(currentComponent.id)
        .onAppear {
            updateCachedData()
        }
        .onChange(of: currentComponent.style) { _, _ in updateCachedData() }
        .onChange(of: templateDataService.selectedInvoice) { _, _ in updateCachedData() }
        .onChange(of: templateDataService.selectedInvoiceItems) { _, _ in updateCachedData() }
        .onChange(of: templateDataService.selectedClient) { _, _ in updateCachedData() }
        .onChange(of: templateDataService.selectedBusiness) { _, _ in updateCachedData() }
        .onChange(of: templateDataService.selectedPayee) { _, _ in updateCachedData() }
    }
    
    // MARK: - Computed Properties
    
    private var selectedCellIndices: (row: Int, column: Int)? {
        guard document.selectedComponentID == component.id,
              let selection = document.selectedTableElement,
              case .cell(let row, let col) = selection else {
            return nil
        }
        return (row, col)
    }
    
    private var selectedRangeIndices: (rows: ClosedRange<Int>, columns: ClosedRange<Int>)? {
        guard document.selectedComponentID == component.id,
              let selection = document.selectedTableElement,
              case .cellRange(let rows, let columns) = selection else {
            return nil
        }
        return (rows, columns)
    }
    
    private var selectedRowIndex: Int? {
        guard document.selectedComponentID == component.id,
              let selection = document.selectedTableElement,
              case .row(let row) = selection else {
            return nil
        }
        return row
    }
    
    private var selectedColumnIndex: Int? {
        guard document.selectedComponentID == component.id,
              let selection = document.selectedTableElement,
              case .column(let col) = selection else {
            return nil
        }
        return col
    }
    
    private var isSectionTitleSelected: Bool {
        guard document.selectedComponentID == component.id,
              let selection = document.selectedTableElement,
              case .sectionTitle = selection else {
            return false
        }
        return true
    }
    
    /// Unique identifier for section title view that changes when styling properties change
    private var sectionTitleIdentifier: String {
        let style = currentComponent.style
        return "\(style.sectionTitle)-\(style.sectionTitleFontSize)-\(style.sectionTitleFontWeight)-\(style.sectionTitleFontFamily)-\(style.sectionTitleBottomPadding)"
    }
    
    private var borderAppearance: TableBorderAppearance {
        let bordersEnabled = currentComponent.style.showTableBorders
        return TableBorderAppearance(
            color: bordersEnabled ? currentComponent.style.tableBorderColorSwiftUI : .clear,
            width: bordersEnabled ? currentComponent.style.tableBorderWidth : 0,
            headerColor: bordersEnabled ? currentComponent.style.tableHeaderBorderColorSwiftUI : nil,
            showHeaderBorders: bordersEnabled,
            showRowBorders: bordersEnabled,
            showCellBorders: bordersEnabled
        )
    }
    
    private var shadowColor: Color {
        currentComponent.style.shadowEnabled
        ? currentComponent.style.shadowColorSwiftUI.opacity(currentComponent.style.shadowOpacity)
        : .clear
    }
    
    /// Table handle for selecting the whole component (like MS Word's table selector)
    @ViewBuilder
    private var tableHandle: some View {
        let isComponentSelected = document.selectedComponentID == component.id && document.selectedTableElement == nil
        let showHandle = document.selectedComponentID == component.id || isHoveringGrid
        
        SelectionHandle(
            elementType: .component,
            isSelected: isComponentSelected,
            action: {
                document.selectedTableElement = nil
                document.selectComponent(component.id)
            },
            onHover: { hovering in
                isHoveringGrid = hovering
            }
        )
        .opacity(showHandle ? 1 : 0)
        .animation(.easeInOut(duration: 0.15), value: showHandle)
    }
    
    @State private var isHoveringGrid = false
    
    // MARK: - Size Measurement
    
    private var sizeMeasurementLayer: some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear {
                    initializeColumnsIfNeeded()
                    initializeColumnsForData(sampleData)
                    // Initial height check
                    updateComponentHeight(geometry.size.height)
                }
                .onChange(of: geometry.size.height) { _, newHeight in
                    updateComponentHeight(newHeight)
                }
        }
    }
    
    private func updateColumnWidths(_ widths: [Int: CGFloat]) {
        guard !widths.isEmpty else { return }
        
        var updated = false
        var newConfigs = currentComponent.style.columnConfigurations
        
        for (index, width) in widths {
            // Check if we have a config for this column and if it's auto-sized
            if var config = newConfigs[index], config.isAutoSized {
                // Only update if significantly different to avoid infinite loops
                if abs(config.width - width) > 0.5 {
                    config.width = width
                    newConfigs[index] = config
                    updated = true
                }
            }
        }
        
        if updated {
            document.saveStateForUndo(actionName: "Resize Column")
            document.updateComponent(id: currentComponent.id) { component in
                component.style.columnConfigurations = newConfigs
            }
        }
    }
    
    private func updateComponentWidth(_ width: CGFloat) {
        guard width > 0 else { return }
        let currentWidth = currentComponent.size.width
        
        // Only update if significantly different to avoid infinite loops
        // And only if the component is NOT currently being resized by the user
        guard abs(width - currentWidth) > 0.5, !currentComponent.isResizing else { return }
        
        document.saveStateForUndo(actionName: "Resize Table")
        document.updateComponent(id: currentComponent.id) { component in
            component.size.width = width
        }
    }
    
    private func updateComponentHeight(_ height: CGFloat) {
        guard height > 0 else { return }
        let currentHeight = currentComponent.size.height
        
        // Only update if significantly different to avoid infinite loops
        // And only if the component is NOT currently being resized by the user
        guard abs(height - currentHeight) > 0.5, !currentComponent.isResizing else { return }
        
        document.saveStateForUndo(actionName: "Resize Table")
        document.updateComponent(id: currentComponent.id) { component in
            component.size.height = height
        }
    }
    
    // MARK: - Caching
    
    @State private var cachedSampleData: [[DocumentTableItem]] = []
    @State private var cachedColumnConfigs: [ColumnWidthConfig] = []
    
    private func updateCachedData() {
        let generator = DocumentGridDataGenerator(
            component: currentComponent,
            templateDataService: templateDataService,
            clientId: clientId,
            invoiceId: invoiceId
        )
        let newData = generator.generateSampleData()
        
        // Only update if changed to avoid unnecessary re-renders
        if newData != cachedSampleData {
            cachedSampleData = newData
        }
        
        // Update column configs based on new data
        updateCachedColumnConfigs(data: newData)
    }
    
    private func updateCachedColumnConfigs(data: [[DocumentTableItem]]) {
        let columnCount = data.first?.count ?? 4
        var configs: [ColumnWidthConfig] = []
        
        for i in 0..<columnCount {
            let config = currentComponent.style.columnConfiguration(for: i)
            if config.isAutoSized {
                configs.append(.autoSized())
            } else if config.isFlexible {
                configs.append(.flexible())
            } else {
                configs.append(.fixed(config.width))
            }
        }
        
        if configs.map({ $0.isFlexible }) != cachedColumnConfigs.map({ $0.isFlexible }) ||
           configs.map({ $0.fixedWidth }) != cachedColumnConfigs.map({ $0.fixedWidth }) ||
           configs.map({ $0.isAutoSized }) != cachedColumnConfigs.map({ $0.isAutoSized }) {
             cachedColumnConfigs = configs
        }
    }

    // MARK: - Column Configurations
    
    @State private var hasInitializedColumns = false
    @State private var gridWidth: CGFloat = 0
    
    private var columnConfigurations: [ColumnWidthConfig] {
        if cachedColumnConfigs.isEmpty && !cachedSampleData.isEmpty {
           // Fallback if cache is empty but we have data (should rare/impossible with correct flow)
           return (0..<(cachedSampleData.first?.count ?? 4)).map { _ in .flexible() }
        }
        return cachedColumnConfigs
    }
    
    private func initializeColumnsIfNeeded() {
        guard !hasInitializedColumns else { return }
        
        // Use cached data if available, otherwise generate temp
        let data = cachedSampleData.isEmpty ? sampleData : cachedSampleData
        let columnCount = data.first?.count ?? 4
        
        // Initialize configurations based on table direction
        if currentComponent.style.tableDirection == .horizontal {
            if currentComponent.style.columnConfigurations.isEmpty {
                document.initializeAxisConfigurations(for: currentComponent.id, axis: .column, count: columnCount)
                hasInitializedColumns = true
            }
        } else {
            if currentComponent.style.rowConfigurations.isEmpty {
                document.initializeAxisConfigurations(for: currentComponent.id, axis: .row, count: columnCount) // Note: columnCount is correct here as it refers to data "columns" which become rows in vertical table? Or is it rowCount? The variable name is columnCount.
                hasInitializedColumns = true
            }
        }
    }
    
    // MARK: - Sample Data
    
    // Computed property for initial load / fallback, though we use cachedSampleData in view
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
        // Lightweight enough to compute on fly, or could cache
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
        // First priority: cell-specific override
        if let row = item.rowIndex, let col = item.columnIndex,
           let override = currentComponent.style.cellStyle(row: row, column: col),
           let alignment = override.alignment {
            return alignment
        }
        
        // Second priority: explicit alignment on the item
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
            // Horizontal: use column alignment from configuration
            if let col = item.columnIndex {
                let config = currentComponent.style.columnConfiguration(for: col)
                return config.alignment
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
        // First priority: cell-specific override
        if let row = item.rowIndex, let col = item.columnIndex,
           let override = currentComponent.style.cellStyle(row: row, column: col),
           let verticalAlignment = override.verticalAlignment {
            return verticalAlignment
        }
        
        // Second priority: explicit vertical alignment on the item
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
                    gridCellTextView(for: item, displayText: displayText, isHeader: isHeader)
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
        // Check for cell-specific override first
        if let row = item.rowIndex, let col = item.columnIndex {
            if let style = currentComponent.style.cellStyle(row: row, column: col),
               let bgHex = style.backgroundColor {
                return Color(hex: bgHex).opacity(currentComponent.style.backgroundOpacity)
            }
        }
        
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
            document.initializeAxisConfigurations(for: currentComponent.id, axis: .column, count: columnCount)
        }
    }
    
    /// Resolves the effective line limit for a given item using per-cell configuration
    /// first, then falling back to row/column defaults set in the DocumentGrid property editor.
    ///
    /// Priority:
    /// 1. Row/Column line limit (from DocumentGrid property editor)
    /// 2. Default of 1 line (fallback)
    private func effectiveLineLimit(for item: DocumentTableItem) -> Int {
        // 1. Cell-specific override
        if let row = item.rowIndex, let col = item.columnIndex,
           let override = currentComponent.style.cellStyle(row: row, column: col),
           let limit = override.lineLimit {
            return limit
        }
        
        // 2. Row/Column configuration
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
    
    private func alignment(from textAlignment: TextAlignment) -> Alignment {
        switch textAlignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
    
    private func fontWeight(from weight: String) -> Font.Weight {
        switch weight.lowercased() {
        case "ultraLight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return .regular
        }
    }
    
    // MARK: - View Builders
    
    // MARK: - View Builders
    
    private var sectionTitleView: some View {
        CoreTextLabel(attributedString: currentComponent.style.sectionTitleNSAttributedString())
            .padding(.bottom, currentComponent.style.sectionTitleBottomPadding)
            .background(
                isSectionTitleSelected ? 
                Color.accentColor.opacity(0.1).cornerRadius(4) : 
                Color.clear.cornerRadius(0)
            )
            .overlay(
                isSectionTitleSelected ?
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor, lineWidth: 2) :
                nil
            )
            .contentShape(Rectangle())
            .onTapGesture {
                document.selectTableElement(.sectionTitle, in: component.id)
            }
    }
    
    private func gridCellTextView(for item: DocumentTableItem, displayText: String, isHeader: Bool) -> some View {
        let alignment = effectiveTextAlignment(for: item)
        
        // Fetch cell style override
        var cellOverride: ComponentStyle.CellStyle? = nil
        if let row = item.rowIndex, let col = item.columnIndex {
            cellOverride = currentComponent.style.cellStyle(row: row, column: col)
        }
        
        return CoreTextLabel(
            attributedString: currentComponent.style.cellTextNSAttributedString(
                for: displayText, 
                isHeader: isHeader, 
                alignment: alignment, 
                override: cellOverride
            ),
            numberOfLines: effectiveLineLimit(for: item)
        )
            .padding(isHeader ? currentComponent.style.tableHeaderPadding : currentComponent.style.tableCellPadding)
    }
    
    private func textScale(from scale: String) -> Text.Scale {
        switch scale {
        case "secondary": return .secondary
        default: return .default
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
}
