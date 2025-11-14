import SwiftUI

// MARK: - Document Grid Layout

/// PreferenceKey for tracking column width requirements
struct ColumnWidthPreferenceKey: PreferenceKey {
    static let defaultValue: [Int: CGFloat] = [:]
    
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        for (columnIndex, width) in nextValue() {
            value[columnIndex] = max(value[columnIndex] ?? 0, width)
        }
    }
}

/// PreferenceKey to measure the grid's width for full-width row styling
private struct GridWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Alignment Grid Picker

/// Custom alignment picker using a 3x3 grid of buttons
struct AlignmentGridPicker: View {
    let label: String
    @Binding var horizontalAlignment: TextAlignment
    @Binding var verticalAlignment: VerticalAlignment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color(NSColor.secondaryLabelColor))
            
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
            .padding(1)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
        }
    }
    
    private func alignmentButton(horizontal: TextAlignment, vertical: VerticalAlignment) -> some View {
        let isSelected = horizontalAlignment == horizontal && verticalAlignment == vertical
        
        // Get the appropriate arrow icon based on alignment
        let iconName = alignmentIconName(horizontal: horizontal, vertical: vertical)
        
        return AlignmentButton(
            iconName: iconName,
            isSelected: isSelected,
            action: {
                withAnimation(.easeInOut(duration: 0.15)) {
                    horizontalAlignment = horizontal
                    verticalAlignment = vertical
                }
            }
        )
    }
    
    private struct AlignmentButton: View {
        let iconName: String
        let isSelected: Bool
        let action: () -> Void
        
        @State private var isHovered = false
        
        var body: some View {
            Button(action: action) {
                Image(systemName: iconName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? .white : Color(NSColor.labelColor))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(AlignmentButtonStyle(isSelected: isSelected, isHovered: isHovered))
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
            .pointerStyle(.link)
            .onHover { hovering in
                isHovered = hovering
            }
        }
    }
    
    private struct AlignmentButtonStyle: ButtonStyle {
        let isSelected: Bool
        let isHovered: Bool
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            isSelected ? Color.blue :
                            configuration.isPressed ? Color(.systemGray).opacity(0.5) :
                            isHovered ? Color(.systemGray).opacity(0.35) :
                            Color(.systemGray).opacity(0.2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                        )
                )
                .scaleEffect(
                    isSelected ? 1.05 :
                    configuration.isPressed ? 0.95 :
                    isHovered ? 1.02 : 1.0
                )
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
                .animation(.easeInOut(duration: 0.1), value: isHovered)
                .animation(.easeInOut(duration: 0.15), value: isSelected)
        }
    }
    
    private func alignmentIconName(horizontal: TextAlignment, vertical: VerticalAlignment) -> String {
        switch (horizontal, vertical) {
        case (.leading, .top):
            return "arrow.up.left"
        case (.center, .top):
            return "arrow.up"
        case (.trailing, .top):
            return "arrow.up.right"
        case (.leading, .center):
            return "arrow.left"
        case (.center, .center):
            return "arrow.up.and.down.and.arrow.left.and.right"
        case (.trailing, .center):
            return "arrow.right"
        case (.leading, .bottom):
            return "arrow.down.left"
        case (.center, .bottom):
            return "arrow.down"
        case (.trailing, .bottom):
            return "arrow.down.right"
        default:
            return "arrow.up.and.down.and.arrow.left.and.right"
        }
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
struct TableBorderOptions {
    var showHeaderBorders: Bool = true
    var showRowBorders: Bool = true
    var showCellBorders: Bool = true
}

public struct DocumentGridView<Item: TableItem, CellContent: View>: View {
    private let data: [[Item]]
    private let cellContent: (DocumentTableItem) -> CellContent
    private let borderColor: Color
    private let borderWidth: CGFloat
    private let columnConfigs: [ColumnWidthConfig]
    private let borderOptions: TableBorderOptions?
    private let defaultAutoColumnWidth: CGFloat = 80
    
    /// Tracks the measured width for each column (for auto-sizing)
    /// Key: columnIndex, Value: measured width
    @State private var contentColumnWidths: [Int: CGFloat] = [:]
    
    init(
        data: [[Item]],
        borderColor: Color = .gray,
        borderWidth: CGFloat = 1.0,
        columnConfigs: [ColumnWidthConfig] = [],
        borderOptions: TableBorderOptions? = nil,
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
        self.borderOptions = borderOptions
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
                        let shouldShowBorder = !cellAboveEmpty && shouldDrawHorizontalBorder(beforeRow: rowIndex)

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
                            
                            // Filter rowData to only DocumentTableItem items for safe casting
                            let safeRowData = rowData.compactMap { $0 as? DocumentTableItem }
                            
                            ZStack {
                                // Cell content
                                cellContent(tableItem)
                                    .frame(width: cellWidth)
                                    .gridCellColumns(tableItem.columnSpan)

                                // Vertical borders for this cell
                                verticalBorderForCell(tableItem, rowIndex: rowIndex, cellIndex: cellIndex, rowData: safeRowData)
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
                    let shouldShowBorder = !finalCellEmpty && shouldDrawBottomBorder()

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
        let showCellBorders = borderOptions?.showCellBorders ?? true
        let edges = getBorderEdgesForCell(
                        rowIndex: rowIndex,
                        cellIndex: cellIndex,
                        totalRows: data.count,
                        totalCells: rowData.count
                    )
        let isFirstCell = cellIndex == 0
        let isLastCell = cellIndex == rowData.count - 1

        return ZStack {
            // Leading border
            if edges.contains(.leading) && (showCellBorders || isFirstCell) {
                let leadingColor = isCurrentCellEmpty ? Color.clear : borderColor
                Rectangle()
                    .fill(leadingColor)
                    .frame(width: borderWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }

            // Trailing border
            if edges.contains(.trailing) && (showCellBorders || isLastCell) {
                Rectangle()
                    .fill(borderColor)
                    .frame(width: borderWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            }
        }
    }

    private func isCellAboveEmpty(rowIndex: Int, cellIndex: Int) -> Bool {
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

    private func shouldDrawHorizontalBorder(beforeRow rowIndex: Int) -> Bool {
        if rowIndex == 0 {
            return borderOptions?.showHeaderBorders ?? true
        }
        return borderOptions?.showRowBorders ?? true
    }

    private func shouldDrawBottomBorder() -> Bool {
        borderOptions?.showRowBorders ?? true
    }
}
