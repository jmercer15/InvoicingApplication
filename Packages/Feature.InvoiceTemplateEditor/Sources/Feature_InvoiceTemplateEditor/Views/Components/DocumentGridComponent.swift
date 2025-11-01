import SwiftUI
import SwiftData

/// PreferenceKey for tracking column width requirements
struct ColumnWidthPreferenceKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        for (columnIndex, width) in nextValue() {
            value[columnIndex] = max(value[columnIndex] ?? 0, width)
    }
    }
}

// MARK: - Alignment Grid Picker

/// Custom alignment picker using a 3x3 grid of buttons
struct AlignmentGridPicker: View {
    @Binding var horizontalAlignment: TextAlignment
    @Binding var verticalAlignment: VerticalAlignment
    
    var body: some View {
        Grid(horizontalSpacing: 1, verticalSpacing: 1) {
            GridRow {
                alignmentButton(horizontal: .leading, vertical: .top)
                alignmentButton(horizontal: .center, vertical: .top)
                alignmentButton(horizontal: .trailing, vertical: .top)
            }
            
            GridRow {
                alignmentButton(horizontal: .leading, vertical: .center)
                alignmentButton(horizontal: .center, vertical: .center)
                alignmentButton(horizontal: .trailing, vertical: .center)
            }
            
            GridRow {
                alignmentButton(horizontal: .leading, vertical: .bottom)
                alignmentButton(horizontal: .center, vertical: .bottom)
                alignmentButton(horizontal: .trailing, vertical: .bottom)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray))
        )
    }
    
    private func alignmentButton(horizontal: TextAlignment, vertical: VerticalAlignment) -> some View {
        let isSelected = horizontalAlignment == horizontal && verticalAlignment == vertical
        
        return Button(action: {
            horizontalAlignment = horizontal
            verticalAlignment = vertical
        }) {
            Image(systemName: isSelected ? "circle.fill" : "circle")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
        .frame(width: 16, height: 16)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(isSelected ? Color.blue : Color(.systemGray))
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 0.5)
                )
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isSelected)
    }
}

// MARK: - TableItem Protocol

/// Protocol defining the requirements for an item to be displayed in the DocumentGridView
public protocol TableItem: Identifiable, Hashable {
    /// A unique identifier for the item
    var id: UUID { get }
    
    /// The number of columns this item should span. Defaults to 1
    var columnSpan: Int { get }
    
    /// The number of rows this item should span. Defaults to 1
    var rowSpan: Int { get }
}

// MARK: - TableItem Default Implementation

public extension TableItem {
    var columnSpan: Int { 1 }
    var rowSpan: Int { 1 }
}

// MARK: - DocumentTableItem

/// Sample data structure for the document grid component
struct DocumentTableItem: TableItem {
    let id = UUID()
    let content: String
    let alignment: Alignment?
    let verticalAlignment: VerticalAlignment?
    let isHeader: Bool
    let customColumnSpan: Int?
    /// The zero-based index of the row this item belongs to.
    /// Used by DocumentGridComponent to apply alternating row styling.
    let rowIndex: Int?
    /// The zero-based column index for default alignment/formatting.
    let columnIndex: Int?
    /// Whether this cell should be transparent (no borders or backgrounds)
    let isTransparent: Bool
    
    var columnSpan: Int { customColumnSpan ?? 1 }
    var rowSpan: Int { 1 }
    
    init(content: String, alignment: Alignment? = nil, verticalAlignment: VerticalAlignment? = nil, isHeader: Bool = false, columnSpan: Int? = nil, rowIndex: Int? = nil, columnIndex: Int? = nil, isTransparent: Bool = false) {
        self.content = content
        self.alignment = alignment
        self.verticalAlignment = verticalAlignment
        self.isHeader = isHeader
        self.customColumnSpan = columnSpan
        self.rowIndex = rowIndex
        self.columnIndex = columnIndex
        self.isTransparent = isTransparent
    }
    
    // MARK: - Hashable Conformance
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(content)
        hasher.combine(isHeader)
        hasher.combine(customColumnSpan)
        hasher.combine(rowIndex)
        hasher.combine(columnIndex)
        // Note: Alignment and VerticalAlignment are not included in hash as they're not Hashable
    }
    
    static func == (lhs: DocumentTableItem, rhs: DocumentTableItem) -> Bool {
        return lhs.id == rhs.id &&
               lhs.content == rhs.content &&
               lhs.alignment == rhs.alignment &&
               lhs.verticalAlignment == rhs.verticalAlignment &&
               lhs.isHeader == rhs.isHeader &&
               lhs.customColumnSpan == rhs.customColumnSpan &&
               lhs.rowIndex == rhs.rowIndex &&
               lhs.columnIndex == rhs.columnIndex
    }
}

// MARK: - PreferenceKeys


/// PreferenceKey to measure the grid's width for full-width row styling
private struct GridWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}



// MARK: - Column Width Configuration

/// Configuration for column width behavior
public struct ColumnWidthConfig {
    let isFlexible: Bool
    let fixedWidth: CGFloat?
    let isAutoSized: Bool
    
    public init(isFlexible: Bool, fixedWidth: CGFloat? = nil, isAutoSized: Bool = false) {
        self.isFlexible = isFlexible
        self.fixedWidth = fixedWidth
        self.isAutoSized = isAutoSized
    }
    
    public static func flexible() -> ColumnWidthConfig {
        return ColumnWidthConfig(isFlexible: true)
    }
    
    public static func fixed(_ width: CGFloat) -> ColumnWidthConfig {
        return ColumnWidthConfig(isFlexible: false, fixedWidth: width)
    }
    
    public static func autoSized() -> ColumnWidthConfig {
        return ColumnWidthConfig(isFlexible: false, fixedWidth: nil, isAutoSized: true)
    }
}

// MARK: - DocumentGridView

/// Generic document grid view with perfect gridlines and custom column widths
public struct DocumentGridView<Item: TableItem, CellContent: View>: View {
    private let data: [[Item]]
    private let cellContent: (DocumentTableItem) -> CellContent
    private let borderColor: Color
    private let borderWidth: CGFloat
    private let columnConfigs: [ColumnWidthConfig]
    private let defaultAutoColumnWidth: CGFloat = 80
    
    /// Tracks the measured width for each column (for auto-sizing)
    /// Key: columnIndex, Value: measured width
    @State private var contentColumnWidths: [Int: CGFloat] = [:]

    init(
        data: [[Item]],
        borderColor: Color = .gray,
        borderWidth: CGFloat = 1.0,
        columnConfigs: [ColumnWidthConfig] = [],
        @ViewBuilder cellContent: @escaping (DocumentTableItem) -> CellContent
    ) {
        self.data = data
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.cellContent = cellContent
        // If no column configs provided, use flexible for all columns
        if columnConfigs.isEmpty {
            self.columnConfigs = Array(repeating: .flexible(), count: data.first?.count ?? 4)
        } else {
            self.columnConfigs = columnConfigs
        }
    }

    public var body: some View {
        GeometryReader { geometry in
            let availableWidth = max(geometry.size.width - borderWidth, 0)
            let columnWidths = resolvedColumnWidths(totalWidth: availableWidth)
            ZStack(alignment: .topLeading) {
                measurementLayer
                mainGridLayer(columnWidths: columnWidths)
            }
            .frame(width: geometry.size.width, alignment: .leading)
            .padding(borderWidth / 2)
        }
    }
    
    // MARK: - Sub-Views for Complex Expression Breakdown
    
    private var measurementLayer: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(data.indices), id: \.self) { rowIndex in
                let rowData = data[rowIndex]
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(rowData.enumerated()), id: \.element.id) { cellIndex, item in
                        if columnConfigs.indices.contains(cellIndex),
                           let tableItem = item as? DocumentTableItem,
                           tableItem.columnSpan <= 1 {
                            measurementCell(for: tableItem, columnIndex: cellIndex)
                        }
                    }
                }
            }
        }
        .opacity(0.0)
        .allowsHitTesting(false)
        .onPreferenceChange(ColumnWidthPreferenceKey.self) { widths in
            contentColumnWidths = widths
        }
    }
    
    private func measurementCell(for item: DocumentTableItem, columnIndex: Int) -> some View {
        cellContent(item)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ColumnWidthPreferenceKey.self,
                        value: [columnIndex: geometry.size.width]
                    )
                }
            )
    }
    
    private func resolvedColumnWidths(totalWidth: CGFloat) -> [CGFloat] {
        let availableWidth = max(totalWidth, 0)
        let columnCount = min(columnConfigs.count, maxColumnCount)
        guard columnCount > 0 else { return [] }
        
        var widths = Array(repeating: CGFloat(0), count: columnCount)
        var remainingWidth = availableWidth
        var flexibleIndices: [Int] = []
        var autoSizedIndices: [Int] = []
        
        for index in 0..<columnCount {
            let config = columnConfigs[index]
            if config.isAutoSized {
                autoSizedIndices.append(index)
                let measuredWidth = contentColumnWidths[index] ?? defaultAutoColumnWidth
                widths[index] = max(measuredWidth, config.fixedWidth ?? 0)
                remainingWidth -= widths[index]
            } else if let fixedWidth = config.fixedWidth {
                widths[index] = fixedWidth
                remainingWidth -= fixedWidth
            } else if config.isFlexible {
                flexibleIndices.append(index)
            } else {
                flexibleIndices.append(index)
            }
        }
        
        if !flexibleIndices.isEmpty {
            let distributableWidth = max(remainingWidth, 0)
            let perColumnWidth = distributableWidth / CGFloat(flexibleIndices.count)
            
            for index in flexibleIndices {
                let measuredWidth = contentColumnWidths[index] ?? 0
                let minimumWidth = columnConfigs[index].fixedWidth ?? 0
                widths[index] = max(perColumnWidth, measuredWidth, minimumWidth)
            }
        }
        
        widths = clampColumnWidths(
            widths,
            targetWidth: availableWidth,
            flexibleIndices: flexibleIndices,
            autoSizedIndices: autoSizedIndices
        )
        
        return widths
    }
    
    private var maxColumnCount: Int {
        data.map { $0.count }.max() ?? 0
    }
    
    private func widthForColumns(startIndex: Int, span: Int, columnWidths: [CGFloat]) -> CGFloat {
        guard span > 0 else { return 0 }
        guard startIndex < columnWidths.count else { return 0 }
        let endIndex = min(startIndex + span, columnWidths.count)
        return columnWidths[startIndex..<endIndex].reduce(0, +)
    }
    
    private func isBottomCellEmpty(columnIndex: Int) -> Bool {
        guard let finalRowData = data.last, columnIndex < finalRowData.count else { return true }
        if let cell = finalRowData[columnIndex] as? DocumentTableItem {
            return cell.isTransparent
        }
        return true
    }
    
    private func clampColumnWidths(
        _ widths: [CGFloat],
        targetWidth: CGFloat,
        flexibleIndices: [Int],
        autoSizedIndices: [Int]
    ) -> [CGFloat] {
        guard targetWidth > 0 else { return Array(repeating: 0, count: widths.count) }
        
        var adjustedWidths = widths
        var excessWidth = adjustedWidths.reduce(0, +) - targetWidth
        guard excessWidth > 0 else { return adjustedWidths }
        
        shrinkWidths(&adjustedWidths, for: flexibleIndices, excessWidth: &excessWidth)
        shrinkWidths(&adjustedWidths, for: autoSizedIndices, excessWidth: &excessWidth)
        shrinkWidths(&adjustedWidths, for: Array(adjustedWidths.indices), excessWidth: &excessWidth)
        
        return adjustedWidths
    }
    
    private func shrinkWidths(
        _ widths: inout [CGFloat],
        for indices: [Int],
        excessWidth: inout CGFloat
    ) {
        guard excessWidth > 0, !indices.isEmpty else { return }
        
        let totalWidth = indices.reduce(CGFloat(0)) { partialResult, index in
            partialResult + widths[index]
        }
        guard totalWidth > 0 else { return }
        
        let shrinkAmount = min(excessWidth, totalWidth)
        let shrinkFactor = max((totalWidth - shrinkAmount) / totalWidth, 0)
        
        for index in indices {
            widths[index] *= shrinkFactor
        }
        
        excessWidth -= shrinkAmount
    }
    
    private func mainGridLayer(columnWidths: [CGFloat]) -> some View {
        return Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            ForEach(Array(data.indices), id: \.self) { rowIndex in
                let rowData = data[rowIndex]
                
                // Add horizontal border before this row (including first row)
                // Border appears where cells above have content
                GridRow {
                    // Check each column position for borders
                    ForEach(0..<columnWidths.count, id: \.self) { colIndex in
                        let cellAboveEmpty = isCellAboveEmpty(rowIndex: rowIndex, cellIndex: colIndex)
                        let shouldShowBorder = !cellAboveEmpty

                        Rectangle()
                            .fill(shouldShowBorder ? borderColor : Color.clear)
                            .frame(width: colIndex < columnWidths.count ? columnWidths[colIndex] : 0, height: borderWidth)
                    }
                }

                // Main content row
                GridRow {
                    ForEach(Array(rowData.enumerated()), id: \.element.id) { cellIndex, item in
                        if let tableItem = item as? DocumentTableItem {
                            let span = max(tableItem.columnSpan, 1)
                            let cellWidth = widthForColumns(startIndex: cellIndex, span: span, columnWidths: columnWidths)
                            
                            ZStack {
                                // Cell content
                                cellContent(tableItem)
                                    .frame(width: cellWidth)
                                    .gridCellColumns(tableItem.columnSpan)

                                // Vertical borders for this cell
                                verticalBorderForCell(tableItem, rowIndex: rowIndex, cellIndex: cellIndex, rowData: rowData as! [DocumentTableItem])
                                    .frame(width: cellWidth)
                            }
                        }
                    }
                }
            }

            // Bottom border for the entire grid
            GridRow {
                // Check each column position for bottom borders
                ForEach(0..<columnWidths.count, id: \.self) { colIndex in
                    let finalCellEmpty = isBottomCellEmpty(columnIndex: colIndex)
                    let shouldShowBorder = !finalCellEmpty

                    Rectangle()
                        .fill(shouldShowBorder ? borderColor : Color.clear)
                        .frame(width: colIndex < columnWidths.count ? columnWidths[colIndex] : 0, height: borderWidth)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion for text wrapping
    }
    
    private func verticalBorderForCell(_ item: DocumentTableItem, rowIndex: Int, cellIndex: Int, rowData: [DocumentTableItem]) -> some View {
        let isCurrentCellEmpty = item.isTransparent
        let edges = getBorderEdgesForCell(
                        rowIndex: rowIndex,
                        cellIndex: cellIndex,
                        totalRows: data.count,
                        totalCells: rowData.count
                    )

        return ZStack {
            // Leading border
            if edges.contains(.leading) {
                let leadingColor = isCurrentCellEmpty ? Color.clear : borderColor
                Rectangle()
                    .fill(leadingColor)
                    .frame(width: borderWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }

            // Trailing border
            if edges.contains(.trailing) {
                Rectangle()
                    .fill(borderColor)
                    .frame(width: borderWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
        }
    }


    private func isCellAboveEmpty(rowIndex: Int, cellIndex: Int) -> Bool {
        // Check if there's a cell above and if it's empty
        guard rowIndex > 0 && rowIndex < data.count else { return false }
        let rowAbove = data[rowIndex - 1]
        guard cellIndex < rowAbove.count else { return false }

        if let cellAbove = rowAbove[cellIndex] as? DocumentTableItem {
            return cellAbove.isTransparent
            }
            return false
        }
        
    private func getBorderEdgesForCell(rowIndex: Int, cellIndex: Int, totalRows: Int, totalCells: Int) -> [Edge] {
        var edges: [Edge] = [.leading] // Every cell gets left border
        
        // Add right border if not the last cell
        if cellIndex == totalCells - 1 {
            edges.append(.trailing)
        }
        
        return edges
    }
    
}

// MARK: - DocumentGridComponent

/// Document grid component for invoice templates
struct DocumentGridComponent: View {
    let component: InvoiceComponent
    @EnvironmentObject private var document: InvoiceDocument
    @Environment(\.modelContext) private var modelContext
    
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
            let data = sampleData
            
            // Initialize column configurations based on actual data
            DocumentGridView(
                data: data,
                borderColor: currentComponent.style.showTableBorders ? currentComponent.style.tableBorderColorSwiftUI : .clear,
                borderWidth: currentComponent.style.showTableBorders ? currentComponent.style.tableBorderWidth : 0,
            columnConfigs: columnConfigurations
            ) { item in
                renderGridCell(for: item)
            }
            .id("\(currentComponent.id)-\(currentComponent.style.hashValue)") // Force re-render when style changes
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(currentComponent.style.padding)
            .background(
                RoundedRectangle(cornerRadius: currentComponent.style.cornerRadius)
                    .fill(isSectionComponent ? Color.clear : currentComponent.style.backgroundColorSwiftUI)
                    .opacity(isSectionComponent ? 1.0 : currentComponent.style.backgroundOpacity)
            )
            // Note: Border is handled by DocumentGridView's unified border system
            .shadow(
                color: currentComponent.style.shadowEnabled ? currentComponent.style.shadowColorSwiftUI.opacity(currentComponent.style.shadowOpacity) : .clear,
                radius: currentComponent.style.shadowRadius,
                x: currentComponent.style.shadowOffsetX,
                y: currentComponent.style.shadowOffsetY
            )
            .padding(currentComponent.style.margin)
        .background(
            GeometryReader { geometry in
                Color.clear
            .onAppear {
                // Initialize column configurations when the view appears
                initializeColumnsForData(data)
            }
        }
        )
        .id(currentComponent.id) // Force re-render when component changes
    }
    
    // MARK: - Column Configurations
    
    private var columnConfigurations: [ColumnWidthConfig] {
        // Get the number of columns from the sample data
        let columnCount = sampleData.first?.count ?? 4
        
        // Initialize configurations based on table direction
        if currentComponent.style.tableDirection == .horizontal {
            if currentComponent.style.columnConfigurations.isEmpty {
                document.initializeColumnConfigurations(for: currentComponent.id, columnCount: columnCount)
            }
        } else {
            if currentComponent.style.rowConfigurations.isEmpty {
                document.initializeRowConfigurations(for: currentComponent.id, rowCount: columnCount)
            }
        }
        
        // Convert dynamic column configurations to ColumnWidthConfig array
        var configs: [ColumnWidthConfig] = []
        for i in 0..<columnCount {
            let config = currentComponent.style.columnConfiguration(for: i)
            configs.append(ColumnWidthConfig(
                isFlexible: config.isFlexible,
                fixedWidth: config.isFlexible ? nil : config.width,
                isAutoSized: config.isAutoSized
            ))
        }
        return configs
    }
    
    // MARK: - Sample Data
    
    private var sampleData: [[DocumentTableItem]] {
        // Initialize shared instance if not already done
        if TemplateDataService.shared == nil {
            TemplateDataService.initializeShared(with: modelContext)
        }

        var data: [[DocumentTableItem]] = []
        
        // Check if this is a section component that should use section-specific data
        if isSectionComponent {
            return generateSectionData()
        }
        
        // Default DocumentGrid data for non-section components
        switch currentComponent.style.tableDirection {
        case .horizontal:
            // Horizontal layout: headers as first row
            if currentComponent.style.showTableHeader {
                data.append([
                    DocumentTableItem(content: "Service", alignment: nil, verticalAlignment: nil, isHeader: true, rowIndex: 0, columnIndex: 0),
                    DocumentTableItem(content: "Quantity", alignment: nil, verticalAlignment: nil, isHeader: true, rowIndex: 0, columnIndex: 1),
                    DocumentTableItem(content: "Rate", alignment: nil, verticalAlignment: nil, isHeader: true, rowIndex: 0, columnIndex: 2),
                    DocumentTableItem(content: "Amount", alignment: nil, verticalAlignment: nil, isHeader: true, rowIndex: 0, columnIndex: 3)
                ])
            }
            
            // Data rows
            let serviceData = [
                ("Consultation Session", "2.0 hr", "$75.00", "$150.00"),
                ("Assessment Report", "1.5 hr", "$100.00", "$150.00"),
                ("Follow-up Meeting", "1.0 hr", "$100.00", "$100.00")
            ]
            
            let startRow = currentComponent.style.showTableHeader ? 1 : 0
            for (index, service) in serviceData.enumerated() {
                data.append([
                    DocumentTableItem(content: service.0, alignment: nil, isHeader: false, rowIndex: startRow + index, columnIndex: 0),
                    DocumentTableItem(content: service.1, alignment: nil, isHeader: false, rowIndex: startRow + index, columnIndex: 1),
                    DocumentTableItem(content: service.2, alignment: nil, isHeader: false, rowIndex: startRow + index, columnIndex: 2),
                    DocumentTableItem(content: service.3, alignment: nil, isHeader: false, rowIndex: startRow + index, columnIndex: 3)
                ])
            }
            
        case .vertical:
            // Vertical layout: headers as first column
            let headerData = [
                ["Service", "Consultation Session", "Assessment Report", "Follow-up Meeting"],
                ["Quantity", "2.0 hr", "1.5 hr", "1.0 hr"],
                ["Rate", "$75.00", "$100.00", "$100.00"],
                ["Amount", "$150.00", "$150.00", "$100.00"]
            ]
            
            for (rowIndex, row) in headerData.enumerated() {
                var rowItems: [DocumentTableItem] = []
                for (colIndex, content) in row.enumerated() {
                    let isHeader = colIndex == 0 && currentComponent.style.showTableHeader
                    rowItems.append(
                        DocumentTableItem(
                            content: content,
                            alignment: nil,
                            verticalAlignment: nil,
                            isHeader: isHeader,
                            rowIndex: rowIndex,
                            columnIndex: colIndex
                        )
                    )
                }
                data.append(rowItems)
            }
        }
        
        return data
    }
    
    /// Determines if this is a section component that should use section-specific data
    private var isSectionComponent: Bool {
        switch currentComponent.type {
        case .billTo, .participant, .invoiceNumberAndDates, .paymentDetails, .servicesTable:
            return true
        default:
            return false
        }
    }
    
    /// Generates section-specific data for section components
    private func generateSectionData() -> [[DocumentTableItem]] {
        switch currentComponent.type {
        case .billTo:
            return generateBillToData()
        case .participant:
            return generateParticipantData()
        case .invoiceNumberAndDates:
            return generateInvoiceDatesData()
        case .paymentDetails:
            return generatePaymentDetailsData()
        case .servicesTable:
            return generateServicesTableData()
        default:
            return generateDefaultSectionData()
        }
    }
    
    private func generateBillToData() -> [[DocumentTableItem]] {
        let payeeData = TemplateDataService.getShared().getPayeeData(for: clientId)
        
        // Match Invoices feature: Name, Email, Address only
        let fields = [
            ("Name", payeeData.name),
            ("Email", payeeData.email),
            ("Address", payeeData.address)
        ]
        
        var data: [[DocumentTableItem]] = []
        for (index, field) in fields.enumerated() {
            data.append([
                DocumentTableItem(content: field.0, alignment: nil, isHeader: true, rowIndex: index, columnIndex: 0),
                DocumentTableItem(content: field.1, alignment: nil, isHeader: false, rowIndex: index, columnIndex: 1)
            ])
        }
        return data
    }
    
    private func generateParticipantData() -> [[DocumentTableItem]] {
        let clientData = TemplateDataService.getShared().getClientData(for: clientId)
        
        // Match Invoices feature: Name and NDIS No. (if available)
        var fields: [(String, String)] = [
            ("Name", clientData.name)
        ]
        
        // Only add NDIS Number if it's not empty (matching Invoices feature behavior)
        if !clientData.ndisNumber.isEmpty {
            fields.append(("NDIS No.", clientData.ndisNumber))
        }
        
        var data: [[DocumentTableItem]] = []
        for (index, field) in fields.enumerated() {
            data.append([
                DocumentTableItem(content: field.0, alignment: nil, isHeader: true, rowIndex: index, columnIndex: 0),
                DocumentTableItem(content: field.1, alignment: nil, isHeader: false, rowIndex: index, columnIndex: 1)
            ])
        }
        return data
    }
    
    private func generateInvoiceDatesData() -> [[DocumentTableItem]] {
        let invoiceData = TemplateDataService.getShared().getInvoiceData(for: invoiceId)
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        let fields = [
            ("Invoice #", invoiceData.invoiceNumber),
            ("Date", formatter.string(from: invoiceData.issueDate)),
            ("Due Date", formatter.string(from: invoiceData.dueDate))
        ]
        
        var data: [[DocumentTableItem]] = []
        for (index, field) in fields.enumerated() {
            data.append([
                DocumentTableItem(content: field.0, alignment: nil, isHeader: true, rowIndex: index, columnIndex: 0),
                DocumentTableItem(content: field.1, alignment: nil, isHeader: false, rowIndex: index, columnIndex: 1)
            ])
        }
        return data
    }
    
    
    private func generatePaymentDetailsData() -> [[DocumentTableItem]] {
        let businessData = TemplateDataService.getShared().getBusinessData()
        
        // Match Invoices feature: Bank Name, Account Name, BSB, Account No.
        let fields = [
            ("Bank Name", businessData.bankName),
            ("Account Name", businessData.bankAccountName),
            ("BSB", businessData.bankBSB),
            ("Account No.", businessData.bankAccountNumber)
        ]
        
        var data: [[DocumentTableItem]] = []
        for (index, field) in fields.enumerated() {
            data.append([
                DocumentTableItem(content: field.0, alignment: nil, isHeader: true, rowIndex: index, columnIndex: 0),
                DocumentTableItem(content: field.1, alignment: nil, isHeader: false, rowIndex: index, columnIndex: 1)
            ])
        }
        return data
    }
    
    private func generateServicesTableData() -> [[DocumentTableItem]] {
        // Services table uses horizontal layout (headers as first row)
        var data: [[DocumentTableItem]] = []
        
        // Header row
        if currentComponent.style.showTableHeader {
            data.append([
                DocumentTableItem(content: "Service", alignment: nil, isHeader: true, rowIndex: 0, columnIndex: 0),
                DocumentTableItem(content: "Quantity", alignment: nil, isHeader: true, rowIndex: 0, columnIndex: 1),
                DocumentTableItem(content: "Rate", alignment: nil, isHeader: true, rowIndex: 0, columnIndex: 2),
                DocumentTableItem(content: "Amount", alignment: nil, isHeader: true, rowIndex: 0, columnIndex: 3)
            ])
        }
        
        // Service data rows - use real data from TemplateDataService
        let services = TemplateDataService.getShared().getServiceData(for: clientId)
        
        let serviceData = services.map { service in
            (service.name, "\(service.quantity) \(service.unit)", String(format: "$%.2f", service.rate), String(format: "$%.2f", service.amount))
        }
        
        let startRow = currentComponent.style.showTableHeader ? 1 : 0
        for (index, service) in serviceData.enumerated() {
            data.append([
                DocumentTableItem(content: service.0, alignment: nil, isHeader: false, rowIndex: startRow + index, columnIndex: 0),
                DocumentTableItem(content: service.1, alignment: nil, isHeader: false, rowIndex: startRow + index, columnIndex: 1),
                DocumentTableItem(content: service.2, alignment: nil, isHeader: false, rowIndex: startRow + index, columnIndex: 2),
                DocumentTableItem(content: service.3, alignment: nil, isHeader: false, rowIndex: startRow + index, columnIndex: 3)
            ])
        }
        
        // Totals rows (appear in the last two columns) - use real invoice data
        let invoiceData = TemplateDataService.getShared().getInvoiceData(for: invoiceId)
        let totalsData = [
            ("Subtotal", String(format: "$%.2f", invoiceData.subtotal)),
            ("Tax (\(Int(invoiceData.taxRate * 100))%)", String(format: "$%.2f", invoiceData.totalAmount - invoiceData.subtotal)),
            ("Total", String(format: "$%.2f", invoiceData.totalAmount))
        ]
        
        let totalsStartRow = startRow + serviceData.count
        for (index, total) in totalsData.enumerated() {
            data.append([
                DocumentTableItem(content: " ", alignment: nil, isHeader: false, rowIndex: totalsStartRow + index, columnIndex: 0, isTransparent: true), // Empty first column - transparent
                DocumentTableItem(content: " ", alignment: nil, isHeader: false, rowIndex: totalsStartRow + index, columnIndex: 1, isTransparent: true), // Empty second column - transparent
                DocumentTableItem(content: total.0, alignment: nil, isHeader: true, rowIndex: totalsStartRow + index, columnIndex: 2), // Label in Rate column
                DocumentTableItem(content: total.1, alignment: nil, isHeader: false, rowIndex: totalsStartRow + index, columnIndex: 3)  // Value in Amount column
            ])
        }
        
        return data
    }
    
    private func generateDefaultSectionData() -> [[DocumentTableItem]] {
        return [
            [
                DocumentTableItem(content: "Label", alignment: nil, isHeader: true, rowIndex: 0, columnIndex: 0),
                DocumentTableItem(content: "Value", alignment: nil, isHeader: false, rowIndex: 0, columnIndex: 1)
            ]
        ]
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
                // Vertical: use row header alignment
                if let row = item.rowIndex {
                    let config = currentComponent.style.rowConfiguration(for: row)
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
            // Vertical: use row default
            if let row = item.rowIndex {
                let config = currentComponent.style.rowConfiguration(for: row)
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
                // Vertical: use row header vertical alignment
                if let row = item.rowIndex {
                    let config = currentComponent.style.rowConfiguration(for: row)
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
            // Vertical: use row default
            if let row = item.rowIndex {
                let config = currentComponent.style.rowConfiguration(for: row)
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
                        .foregroundColor(currentComponent.style.tableTextColorSwiftUI.opacity(currentComponent.style.textOpacity))
                        .lineSpacing(currentComponent.style.lineSpacing)
                        .kerning(currentComponent.style.letterSpacing)
                        .underline(currentComponent.style.textUnderline)
                        .strikethrough(currentComponent.style.textStrikethrough)
                        .textCase(currentComponent.style.textTransform.swiftUITextCase)
                        .lineLimit(effectiveLineLimit(for: item)) // Use configured line limit
                        .multilineTextAlignment(swiftUITextAlignment(effectiveTextAlignment(for: item))) // Match horizontal alignment
                        .padding(isHeader ? currentComponent.style.tableHeaderPadding : currentComponent.style.tableCellPadding)
                }
            }
            .gridCellAnchor(gridCellAnchorForItem(item)) // Apply anchor to the entire cell content
            // Note: Borders are handled by DocumentGridView's unified border system
            .shadow(
                color: currentComponent.style.shadowEnabled && currentComponent.style.shadowColorSwiftUI != Color.clear ? 
                       currentComponent.style.shadowColorSwiftUI.opacity(currentComponent.style.shadowOpacity) : .clear,
                radius: currentComponent.style.shadowRadius,
                x: currentComponent.style.shadowOffsetX,
                y: currentComponent.style.shadowOffsetY
            )
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
    @Environment(\.modelContext) private var modelContext
    let component: InvoiceComponent
    
    
    // State for TabView selection
    @State private var selectedColumnTab = 0
    
    /// Ensures the selected tab is within valid bounds
    private var validSelectedTab: Int {
        min(selectedColumnTab, max(0, tabCount - 1))
    }
    
    // Ensure the property editor updates when the component changes
    private var currentComponent: InvoiceComponent {
        document.components.first { $0.id == component.id } ?? component
    }
    
    // Get the number of columns from the sample data
    private var columnCount: Int {
        // Get the actual number of columns from the sample data
        let sampleData = generateSampleData()
        let detectedCount = sampleData.first?.count ?? 4
        
        // Initialize configurations based on table direction
        if currentComponent.style.tableDirection == .horizontal {
            if currentComponent.style.columnConfigurations.isEmpty {
                document.initializeColumnConfigurations(for: currentComponent.id, columnCount: detectedCount)
            }
        } else {
            if currentComponent.style.rowConfigurations.isEmpty {
                document.initializeRowConfigurations(for: currentComponent.id, rowCount: detectedCount)
            }
        }
        
        return detectedCount
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
    
    /// Determines if this is a section component that should use section-specific data
    private var isSectionComponent: Bool {
        switch currentComponent.type {
        case .billTo, .participant, .invoiceNumberAndDates, .paymentDetails, .servicesTable:
            return true
        default:
            return false
        }
    }
    
    /// Generates section-specific data for section components
    private func generateSectionData() -> [[DocumentTableItem]] {
        switch currentComponent.type {
        case .billTo:
            return generateBillToData()
        case .participant:
            return generateParticipantData()
        case .invoiceNumberAndDates:
            return generateInvoiceDatesData()
        case .paymentDetails:
            return generatePaymentDetailsData()
        case .servicesTable:
            return generateServicesTableData()
        default:
            return generateDefaultSectionData()
        }
    }
    
    // Generate sample data for the property editor
    private func generateSampleData() -> [[DocumentTableItem]] {
        // Initialize shared instance if not already done
        if TemplateDataService.shared == nil {
            TemplateDataService.initializeShared(with: modelContext)
        }

        // Check if this is a section component that should use section-specific data
        if isSectionComponent {
            return generateSectionData()
        }
        
        var data: [[DocumentTableItem]] = []
        
        switch currentComponent.style.tableDirection {
        case .horizontal:
            // Horizontal layout: headers as first row
            if currentComponent.style.showTableHeader {
                data.append([
                    DocumentTableItem(content: "Service", alignment: nil, verticalAlignment: nil, isHeader: true, rowIndex: 0, columnIndex: 0),
                    DocumentTableItem(content: "Quantity", alignment: nil, verticalAlignment: nil, isHeader: true, rowIndex: 0, columnIndex: 1),
                    DocumentTableItem(content: "Rate", alignment: nil, verticalAlignment: nil, isHeader: true, rowIndex: 0, columnIndex: 2),
                    DocumentTableItem(content: "Amount", alignment: nil, verticalAlignment: nil, isHeader: true, rowIndex: 0, columnIndex: 3)
                ])
            }
            
            // Data rows
            let serviceData = [
                ("Consultation Session", "2.0 hr", "$75.00", "$150.00"),
                ("Assessment Report", "1.5 hr", "$100.00", "$150.00"),
                ("Follow-up Meeting", "1.0 hr", "$100.00", "$100.00")
            ]
            
            let startRow = currentComponent.style.showTableHeader ? 1 : 0
            for (index, service) in serviceData.enumerated() {
                // Use different vertical alignments to demonstrate the feature
                let verticalAlignments: [VerticalAlignment] = [.top, .center, .bottom]
                let verticalAlignment = verticalAlignments[index % verticalAlignments.count]
                
                data.append([
                    DocumentTableItem(content: service.0, alignment: nil, verticalAlignment: verticalAlignment, isHeader: false, rowIndex: startRow + index, columnIndex: 0),
                    DocumentTableItem(content: service.1, alignment: nil, verticalAlignment: verticalAlignment, isHeader: false, rowIndex: startRow + index, columnIndex: 1),
                    DocumentTableItem(content: service.2, alignment: nil, verticalAlignment: verticalAlignment, isHeader: false, rowIndex: startRow + index, columnIndex: 2),
                    DocumentTableItem(content: service.3, alignment: nil, verticalAlignment: verticalAlignment, isHeader: false, rowIndex: startRow + index, columnIndex: 3)
                ])
            }
            
        case .vertical:
            // Vertical layout: headers as first column
            let headerData = [
                ["Service", "Consultation Session", "Assessment Report", "Follow-up Meeting"],
                ["Quantity", "2.0 hr", "1.5 hr", "1.0 hr"],
                ["Rate", "$75.00", "$100.00", "$100.00"],
                ["Amount", "$150.00", "$150.00", "$100.00"]
            ]
            
            for (rowIndex, row) in headerData.enumerated() {
                var rowItems: [DocumentTableItem] = []
                for (colIndex, content) in row.enumerated() {
                    let isHeader = colIndex == 0 && currentComponent.style.showTableHeader
                    rowItems.append(
                        DocumentTableItem(
                            content: content,
                            alignment: nil,
                            verticalAlignment: nil,
                            isHeader: isHeader,
                            rowIndex: rowIndex,
                            columnIndex: colIndex
                        )
                    )
                }
                data.append(rowItems)
            }
        }
        
        return data
    }
    
    // MARK: - Section Data Generation Methods
    
    private func generateBillToData() -> [[DocumentTableItem]] {
        let payeeData = TemplateDataService.getShared().getPayeeData(for: nil)
        
        // Match Invoices feature: Name, Email, Address only
        let fields = [
            ("Name", payeeData.name),
            ("Email", payeeData.email),
            ("Address", payeeData.address)
        ]
        
        var data: [[DocumentTableItem]] = []
        for (index, field) in fields.enumerated() {
            data.append([
                DocumentTableItem(content: field.0, alignment: nil, isHeader: true, rowIndex: index, columnIndex: 0),
                DocumentTableItem(content: field.1, alignment: nil, isHeader: false, rowIndex: index, columnIndex: 1)
            ])
        }
        return data
    }
    
    private func generateParticipantData() -> [[DocumentTableItem]] {
        let clientData = TemplateDataService.getShared().getClientData(for: nil)

        // Match Invoices feature: Name and NDIS No. (if available)
        var fields: [(String, String)] = [
            ("Name", clientData.name)
        ]

        // Only add NDIS Number if it's not empty (matching Invoices feature behavior)
        if !clientData.ndisNumber.isEmpty {
            fields.append(("NDIS No.", clientData.ndisNumber))
        }
        
        var data: [[DocumentTableItem]] = []
        for (index, field) in fields.enumerated() {
            data.append([
                DocumentTableItem(content: field.0, alignment: nil, isHeader: true, rowIndex: index, columnIndex: 0),
                DocumentTableItem(content: field.1, alignment: nil, isHeader: false, rowIndex: index, columnIndex: 1)
            ])
        }
        return data
    }
    
    private func generateInvoiceDatesData() -> [[DocumentTableItem]] {
        let invoiceData = TemplateDataService.getShared().getInvoiceData(for: nil)
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        let fields = [
            ("Invoice #", invoiceData.invoiceNumber),
            ("Date", formatter.string(from: invoiceData.issueDate)),
            ("Due Date", formatter.string(from: invoiceData.dueDate))
        ]
        
        var data: [[DocumentTableItem]] = []
        for (index, field) in fields.enumerated() {
            data.append([
                DocumentTableItem(content: field.0, alignment: nil, isHeader: true, rowIndex: index, columnIndex: 0),
                DocumentTableItem(content: field.1, alignment: nil, isHeader: false, rowIndex: index, columnIndex: 1)
            ])
        }
        return data
    }
    
    private func generatePaymentDetailsData() -> [[DocumentTableItem]] {
        let businessData = TemplateDataService.getShared().getBusinessData()
        
        // Match Invoices feature: Bank Name, Account Name, BSB, Account No.
        let fields = [
            ("Bank Name", businessData.bankName),
            ("Account Name", businessData.bankAccountName),
            ("BSB", businessData.bankBSB),
            ("Account No.", businessData.bankAccountNumber)
        ]
        
        var data: [[DocumentTableItem]] = []
        for (index, field) in fields.enumerated() {
            data.append([
                DocumentTableItem(content: field.0, alignment: nil, isHeader: true, rowIndex: index, columnIndex: 0),
                DocumentTableItem(content: field.1, alignment: nil, isHeader: false, rowIndex: index, columnIndex: 1)
            ])
        }
        return data
    }
    
    private func generateServicesTableData() -> [[DocumentTableItem]] {
        // Services table uses horizontal layout (headers as first row)
        var data: [[DocumentTableItem]] = []
        
        // Header row
        if currentComponent.style.showTableHeader {
            data.append([
                DocumentTableItem(content: "Service", alignment: nil, isHeader: true, rowIndex: 0, columnIndex: 0),
                DocumentTableItem(content: "Quantity", alignment: nil, isHeader: true, rowIndex: 0, columnIndex: 1),
                DocumentTableItem(content: "Rate", alignment: nil, isHeader: true, rowIndex: 0, columnIndex: 2),
                DocumentTableItem(content: "Amount", alignment: nil, isHeader: true, rowIndex: 0, columnIndex: 3)
            ])
        }
        
        // Service data rows - use real data from TemplateDataService
        let services = TemplateDataService.getShared().getServiceData(for: nil)
        
        let serviceData = services.map { service in
            (service.name, "\(service.quantity) \(service.unit)", String(format: "$%.2f", service.rate), String(format: "$%.2f", service.amount))
        }
        
        let startRow = currentComponent.style.showTableHeader ? 1 : 0
        for (index, service) in serviceData.enumerated() {
            data.append([
                DocumentTableItem(content: service.0, alignment: nil, isHeader: false, rowIndex: startRow + index, columnIndex: 0),
                DocumentTableItem(content: service.1, alignment: nil, isHeader: false, rowIndex: startRow + index, columnIndex: 1),
                DocumentTableItem(content: service.2, alignment: nil, isHeader: false, rowIndex: startRow + index, columnIndex: 2),
                DocumentTableItem(content: service.3, alignment: nil, isHeader: false, rowIndex: startRow + index, columnIndex: 3)
            ])
        }
        
        // Totals rows (appear in the last two columns) - use real invoice data
        let invoiceData = TemplateDataService.getShared().getInvoiceData(for: nil)
        let totalsData = [
            ("Subtotal", String(format: "$%.2f", invoiceData.subtotal)),
            ("Tax (\(Int(invoiceData.taxRate * 100))%)", String(format: "$%.2f", invoiceData.totalAmount - invoiceData.subtotal)),
            ("Total", String(format: "$%.2f", invoiceData.totalAmount))
        ]
        
        let totalsStartRow = startRow + serviceData.count
        for (index, total) in totalsData.enumerated() {
            data.append([
                DocumentTableItem(content: "", alignment: nil, isHeader: false, rowIndex: totalsStartRow + index, columnIndex: 0, isTransparent: true), // Empty first column - transparent
                DocumentTableItem(content: "", alignment: nil, isHeader: false, rowIndex: totalsStartRow + index, columnIndex: 1, isTransparent: true), // Empty second column - transparent
                DocumentTableItem(content: total.0, alignment: nil, isHeader: true, rowIndex: totalsStartRow + index, columnIndex: 2), // Label in Rate column
                DocumentTableItem(content: total.1, alignment: nil, isHeader: false, rowIndex: totalsStartRow + index, columnIndex: 3)  // Value in Amount column
            ])
        }
        
        return data
    }
    
    private func generateDefaultSectionData() -> [[DocumentTableItem]] {
        return [
            [
                DocumentTableItem(content: "Label", alignment: nil, isHeader: true, rowIndex: 0, columnIndex: 0),
                DocumentTableItem(content: "Value", alignment: nil, isHeader: false, rowIndex: 0, columnIndex: 1)
            ]
        ]
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
        GroupBox("Typography") {
            VStack {
                generateFontFamilyPicker()
                generateFontSizeAndWeightRow()
                generateSpacingRow()
                generateLineLimitSlider()
            }
            .padding()
        }
    }

    private func generateFontFamilyPicker() -> some View {
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
    }

    private func generateFontSizeAndWeightRow() -> some View {
        HStack {
            generateFontSizeSlider()
            generateFontWeightPicker()
        }
    }

    private func generateFontSizeSlider() -> some View {
        LabeledContent("Size", content: {
            HStack {
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
    }

    private func generateFontWeightPicker() -> some View {
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
    }

    private func generateSpacingRow() -> some View {
        HStack {
            generateLineSpacingSlider()
            generateLetterSpacingSlider()
        }
    }

    private func generateLineSpacingSlider() -> some View {
        LabeledContent("Line Spacing", content: {
            HStack {
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
    }

    private func generateLetterSpacingSlider() -> some View {
        LabeledContent("Letter Spacing", content: {
            HStack {
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
    }

    private func generateLineLimitSlider() -> some View {
        LabeledContent("Line Limit", content: {
            HStack {
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
        .onChange(of: tabCount) { newCount in
            // Reset selected tab if it's out of bounds
            if selectedColumnTab >= newCount {
                selectedColumnTab = max(0, newCount - 1)
            }
        }
    }
    
    private func generateTabContent(for index: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading) {
                generateTypographyGroup()
                generateDataCellAlignmentGroup(for: index)
                generateHeaderAlignmentGroup(for: index)
            }
            .padding()
        }
    }
    

    
    private func generateDataCellAlignmentGroup(for index: Int) -> some View {
        GroupBox("Data Cell Alignment") {
                        AlignmentGridPicker(
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
    }
    
    private func generateHeaderAlignmentGroup(for index: Int) -> some View {
        GroupBox("Header Alignment") {
                        AlignmentGridPicker(
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
    }
    
    // Generate column tabs for horizontal tables (for configuring column widths)
    @State private var selectedHorizontalColumnTab = 0
    
    // Generate column tabs for vertical tables (for configuring column widths)
    @State private var selectedVerticalColumnTab = 0
    
    private func generateColumnTabsForHorizontal() -> some View {
        TabView(selection: $selectedHorizontalColumnTab) {
            ForEach(Array(0..<columnCount), id: \.self) { columnIndex in
                VStack(alignment: .leading) {
                    ModernSectionHeader(title: "Column \(columnIndex + 1) Width Settings")
                    
                    ModernDivider()
                    
                    // Width Behavior Section
                    VStack(alignment: .leading) {
                        ModernSectionHeader(title: "Width Behavior")
                        
                        LabeledContent("Flexible Width", content: {
                            Toggle("", isOn: Binding(
                                get: { currentComponent.style.columnConfiguration(for: columnIndex).isFlexible },
                                set: { document.updateColumnIsFlexible(for: currentComponent.id, columnIndex: columnIndex, isFlexible: $0) }
                            ))
                            .labelsHidden()
                        })
                        
                        LabeledContent("Auto-Size Width", content: {
                            Toggle("", isOn: Binding(
                                get: { currentComponent.style.columnConfiguration(for: columnIndex).isAutoSized },
                                set: { document.updateColumnAutoSizing(for: currentComponent.id, columnIndex: columnIndex, isAutoSized: $0) }
                            ))
                            .labelsHidden()
                        })
                        
                        if !currentComponent.style.columnConfiguration(for: columnIndex).isFlexible {
                            LabeledContent("Fixed Width", content: {
                                HStack {
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
        .onChange(of: columnCount) { newCount in
            // Reset selected tab if it's out of bounds
            if selectedHorizontalColumnTab >= newCount {
                selectedHorizontalColumnTab = max(0, newCount - 1)
            }
        }
    }
    
    private func generateColumnTabsForVertical() -> some View {
        TabView(selection: $selectedVerticalColumnTab) {
            ForEach(Array(0..<columnCountForVertical), id: \.self) { columnIndex in
                VStack(alignment: .leading) {
                    ModernSectionHeader(title: "Column \(columnIndex + 1) Width Settings")
                    
                    ModernDivider()
                    
                    // Width Behavior Section
                    VStack(alignment: .leading) {
                        ModernSectionHeader(title: "Width Behavior")
                        
                        LabeledContent("Flexible Width", content: {
                            Toggle("", isOn: Binding(
                                get: { currentComponent.style.columnConfiguration(for: columnIndex).isFlexible },
                                set: { document.updateColumnIsFlexible(for: currentComponent.id, columnIndex: columnIndex, isFlexible: $0) }
                            ))
                            .labelsHidden()
                        })
                        
                        LabeledContent("Auto-Size Width", content: {
                            Toggle("", isOn: Binding(
                                get: { currentComponent.style.columnConfiguration(for: columnIndex).isAutoSized },
                                set: { document.updateColumnAutoSizing(for: currentComponent.id, columnIndex: columnIndex, isAutoSized: $0) }
                            ))
                            .labelsHidden()
                        })
                        
                        if !currentComponent.style.columnConfiguration(for: columnIndex).isFlexible {
                            LabeledContent("Fixed Width", content: {
                                HStack {
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
        .onChange(of: columnCountForVertical) { newCount in
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
                GroupBox("Column Width") {
                    if currentComponent.style.tableDirection == .horizontal {
                        generateColumnTabsForHorizontal()
                            .padding()
                    } else {
                        generateColumnTabsForVertical()
                            .padding()
                    }
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
                GroupBox("Text") {
                    VStack {
                        LabeledContent("Color", content: {
                            HStack {
                                ColorPicker("", selection: Binding(
                                    get: { currentComponent.style.textColorSwiftUI },
                                    set: { document.updateTextColor(for: currentComponent.id, color: sanitizedHex($0.toHex())) }
                                ))
                                .labelsHidden()
                                
                                TextField("Hex", text: Binding(
                                    get: { "#\(currentComponent.style.textColor)" },
                                    set: { 
                                        let hex = $0.replacingOccurrences(of: "#", with: "")
                                        document.updateTextColor(for: currentComponent.id, color: sanitizedHex(hex))
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                        })
                        
                        LabeledContent("Opacity", content: {
                            HStack {
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
                    }
                    .padding()
                }
                
                // Backgrounds Group
                GroupBox("Table Backgrounds") {
                    VStack {
                        LabeledContent("Header", content: {
                            HStack {
                                ColorPicker("", selection: Binding(
                                    get: { currentComponent.style.tableHeaderColorSwiftUI },
                                    set: { document.updateTableHeaderColor(for: currentComponent.id, color: sanitizedHex($0.toHex())) }
                                ))
                                .labelsHidden()
                                
                                TextField("Hex", text: Binding(
                                    get: { "#\(currentComponent.style.tableHeaderColor)" },
                                    set: { 
                                        let hex = $0.replacingOccurrences(of: "#", with: "")
                                        document.updateTableHeaderColor(for: currentComponent.id, color: sanitizedHex(hex))
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                        })
                        
                        LabeledContent(currentComponent.style.tableDirection == .horizontal ? "1st Row" : "1st Column", content: {
                            HStack {
                                ColorPicker("", selection: Binding(
                                    get: { currentComponent.style.tableRowColorSwiftUI },
                                    set: { document.updateTableRowColor(for: currentComponent.id, color: sanitizedHex($0.toHex())) }
                                ))
                                .labelsHidden()
                                
                                TextField("Hex", text: Binding(
                                    get: { "#\(currentComponent.style.tableRowColor)" },
                                    set: { 
                                        let hex = $0.replacingOccurrences(of: "#", with: "")
                                        document.updateTableRowColor(for: currentComponent.id, color: sanitizedHex(hex))
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                        })
                        
                        LabeledContent(currentComponent.style.tableDirection == .horizontal ? "2nd Row" : "2nd Column", content: {
                            HStack {
                                ColorPicker("", selection: Binding(
                                    get: { currentComponent.style.tableRowAltColorSwiftUI },
                                    set: { document.updateTableRowAltColor(for: currentComponent.id, color: sanitizedHex($0.toHex())) }
                                ))
                                .labelsHidden()
                                
                                TextField("Hex", text: Binding(
                                    get: { "#\(currentComponent.style.tableRowAltColor)" },
                                    set: { 
                                        let hex = $0.replacingOccurrences(of: "#", with: "")
                                        document.updateTableRowAltColor(for: currentComponent.id, color: sanitizedHex(hex))
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                            }
                        })
                        
                        LabeledContent(currentComponent.style.tableDirection == .horizontal ? "Alternating Rows" : "Banded Columns", content: {
                            Toggle("", isOn: Binding(
                                get: { currentComponent.style.useAlternatingRows },
                                set: { document.updateUseAlternatingRows(for: currentComponent.id, use: $0) }
                            ))
                            .labelsHidden()
                        })
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
                    GroupBox("Border Settings") {
                        VStack {
                            LabeledContent("Width", content: {
                                HStack {
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
                            
                            LabeledContent("Color", content: {
                                HStack {
                                    ColorPicker("", selection: Binding(
                                        get: { currentComponent.style.tableBorderColorSwiftUI },
                                        set: { document.updateTableBorderColor(for: currentComponent.id, color: sanitizedHex($0.toHex())) }
                                    ))
                                    .labelsHidden()
                                    
                                    TextField("Hex", text: Binding(
                                        get: { "#\(currentComponent.style.tableBorderColor)" },
                                        set: { 
                                            let hex = $0.replacingOccurrences(of: "#", with: "")
                                            document.updateTableBorderColor(for: currentComponent.id, color: sanitizedHex(hex))
                                        }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                }
                            })
                        }
                        .padding()
                    }
                }
            }
            
            // Section 5: Effects
            Section("Effects") {
                Toggle("Enable Shadow", isOn: Binding(
                    get: { currentComponent.style.shadowEnabled },
                    set: { document.updateShadowEnabled(for: currentComponent.id, enabled: $0) }
                ))
                
                if currentComponent.style.shadowEnabled {
                    GroupBox("Shadow Settings") {
                        VStack {
                            HStack {
                                LabeledContent("Radius", content: {
                                    HStack {
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
                                
                                LabeledContent("Opacity", content: {
                                    HStack {
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
                            }
                            
                            LabeledContent("Offset", content: {
                                HStack {
                                    HStack {
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
                                    
                                    HStack {
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
                            
                            LabeledContent("Color", content: {
                                HStack {
                                    ColorPicker("", selection: Binding(
                                        get: { currentComponent.style.shadowColorSwiftUI },
                                        set: { document.updateShadowColor(for: currentComponent.id, color: sanitizedHex($0.toHex())) }
                                    ))
                                    .labelsHidden()
                                    
                                    TextField("Hex", text: Binding(
                                        get: { "#\(currentComponent.style.shadowColor)" },
                                        set: { 
                                            let hex = $0.replacingOccurrences(of: "#", with: "")
                                            document.updateShadowColor(for: currentComponent.id, color: sanitizedHex(hex))
                                        }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                }
                            })
                        }
                        .padding()
                    }
                }
            }
            
            // Section 6: Spacing
            Section("Spacing") {
                GroupBox("Padding") {
                    VStack {
                        LabeledContent {
                            HStack {
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
                        
                        LabeledContent {
                            HStack {
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
                        
                    }
                    .padding()
                }
            }
        }
        .formStyle(.grouped)
        .id(currentComponent.id) // Force re-render when component changes
    }
}

// MARK: - Helper Functions

private func sanitizedHex(_ hex: String) -> String {
    let cleaned = hex.replacingOccurrences(of: "#", with: "").uppercased()
    return cleaned
}
 
