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

/// PreferenceKey to measure the grid's actual rendered size
struct GridSizePreferenceKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

/// Captures measured text heights for each grid cell
struct DocumentGridCellHeightMeasurement: Equatable {
    let rowIndex: Int
    let height: CGFloat
}

struct DocumentGridCellHeightPreferenceKey: PreferenceKey {
    static let defaultValue: [DocumentGridCellHeightMeasurement] = []
    
    static func reduce(value: inout [DocumentGridCellHeightMeasurement], nextValue: () -> [DocumentGridCellHeightMeasurement]) {
        value.append(contentsOf: nextValue())
    }
}

/// PreferenceKey to report the ideal width of the grid (sum of column widths)
struct GridIdealWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// PreferenceKey to map (row, col) to frame in Grid coordinate space
struct DocumentGridCellFramePreferenceKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

// MARK: - Measurement Phase Environment

enum DocumentGridMeasurementPhase {
    case content
    case widthMeasurement
}

private struct DocumentGridMeasurementPhaseKey: EnvironmentKey {
    static let defaultValue: DocumentGridMeasurementPhase = .content
}

extension EnvironmentValues {
    var documentGridMeasurementPhase: DocumentGridMeasurementPhase {
        get { self[DocumentGridMeasurementPhaseKey.self] }
        set { self[DocumentGridMeasurementPhaseKey.self] = newValue }
    }
}

// MARK: - Alignment Grid Picker

/// Custom alignment picker using a 3x3 grid of buttons
struct AlignmentGridPicker: View {
    let label: String
    @Binding var horizontalAlignment: TextAlignment
    @Binding var verticalAlignment: VerticalAlignment
    var onChange: ((TextAlignment, VerticalAlignment) -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(InspectorTypography.label)
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
        let iconName = iconName(horizontal: horizontal, vertical: vertical)
        
        return AlignmentButton(
            iconName: iconName,
            isSelected: isSelected,
            action: {
                if let onChange = onChange {
                    onChange(horizontal, vertical)
                } else {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        horizontalAlignment = horizontal
                        verticalAlignment = vertical
                    }
                }
            }
        )
    }
    
    private struct AlignmentButton: View {
        let iconName: String
        let isSelected: Bool
        let action: () -> Void
        
        @State private var isHovered = false
        @State private var isPressed = false
        
        var body: some View {
            Image(iconName, bundle: .module)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(isSelected ? .white : Color(NSColor.labelColor))
                .frame(width: 12, height: 12)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            isSelected ? Color.blue :
                            isPressed ? Color(.systemGray).opacity(0.5) :
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
                    isPressed ? 0.95 :
                    isHovered ? 1.02 : 1.0
                )
                .animation(.easeInOut(duration: 0.1), value: isPressed)
                .animation(.easeInOut(duration: 0.1), value: isHovered)
                .animation(.easeInOut(duration: 0.15), value: isSelected)
                .contentShape(Rectangle())
                .onTapGesture {
                    action()
                }
                .onHover { hovering in
                    isHovered = hovering
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in isPressed = true }
                        .onEnded { _ in isPressed = false }
                )
        }
    }
    
    private func iconName(horizontal: TextAlignment, vertical: VerticalAlignment) -> String {
        switch (horizontal, vertical) {
        case (.leading, .top):
            return "fluent-ic_fluent_arrow_up_left_20_regular"
        case (.center, .top):
            return "fluent-ic_fluent_arrow_up_20_regular"
        case (.trailing, .top):
            return "fluent-ic_fluent_arrow_up_right_20_regular"
        case (.leading, .center):
            return "fluent-ic_fluent_arrow_left_20_regular"
        case (.center, .center):
            return "fluent-ic_fluent_arrow_move_20_regular"
        case (.trailing, .center):
            return "fluent-ic_fluent_arrow_right_20_regular"
        case (.leading, .bottom):
            return "fluent-ic_fluent_arrow_down_left_20_regular"
        case (.center, .bottom):
            return "fluent-ic_fluent_arrow_down_20_regular"
        case (.trailing, .bottom):
            return "fluent-ic_fluent_arrow_down_20_regular" // effective fallback for arrow_down_right
        default:
            return "fluent-ic_fluent_arrow_move_20_regular"
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
struct TableBorderAppearance {
    var color: Color
    var width: CGFloat
    var headerColor: Color?
    var showHeaderBorders: Bool
    var showRowBorders: Bool
    var showCellBorders: Bool
    
    init(
        color: Color = .gray,
        width: CGFloat = 1.0,
        headerColor: Color? = nil,
        showHeaderBorders: Bool = true,
        showRowBorders: Bool = true,
        showCellBorders: Bool = true
    ) {
        self.color = color
        self.width = width
        self.headerColor = headerColor
        self.showHeaderBorders = showHeaderBorders
        self.showRowBorders = showRowBorders
        self.showCellBorders = showCellBorders
    }
    
    var effectiveHeaderColor: Color {
        headerColor ?? color
    }
}

public struct DocumentGridView<Item: TableItem, CellContent: View>: View {
    private let data: [[Item]]
    private let cellContent: (DocumentTableItem) -> CellContent
    private let borderAppearance: TableBorderAppearance
    private let columnConfigs: [ColumnWidthConfig]
    private let defaultAutoColumnWidth: CGFloat = 20
    private let onCellTap: ((Int, Int) -> Void)?
    private let selectedCell: (row: Int, column: Int)?
    private let selectedRange: (rows: ClosedRange<Int>, columns: ClosedRange<Int>)?
    private let selectedRow: Int?
    private let selectedColumn: Int?
    private let onRowTap: ((Int) -> Void)?
    private let onColumnTap: ((Int) -> Void)?
    private let showHeaders: Bool
    private let onSelectionChange: ((TableElementSelection) -> Void)?
    
    // Drag selection state
    @State private var dragStartCell: (row: Int, column: Int)?
    @State private var liveSelectionRange: (rows: ClosedRange<Int>, columns: ClosedRange<Int>)?
    @State private var cellFrames: [String: CGRect] = [:] // "row:col" -> global frame
    @State private var hoveredCell: (row: Int, column: Int)?
    
    /// Tracks the measured width for each column (for auto-sizing)
    /// Key: columnIndex, Value: measured width
    @State private var contentColumnWidths: [Int: CGFloat] = [:]
    @State private var calculatedGridHeight: CGFloat = 0
    
    init(
        data: [[Item]],
        columnConfigs: [ColumnWidthConfig] = [],
        borderAppearance: TableBorderAppearance = TableBorderAppearance(),
        onCellTap: ((Int, Int) -> Void)? = nil,
        selectedCell: (row: Int, column: Int)? = nil,
        selectedRange: (rows: ClosedRange<Int>, columns: ClosedRange<Int>)? = nil,
        selectedRow: Int? = nil,
        selectedColumn: Int? = nil,
        onRowTap: ((Int) -> Void)? = nil,
        onColumnTap: ((Int) -> Void)? = nil,
        showHeaders: Bool = false,
        onSelectionChange: ((TableElementSelection) -> Void)? = nil,
        @ViewBuilder cellContent: @escaping (DocumentTableItem) -> CellContent
    ) {
        self.data = data
        self.cellContent = cellContent
        self.onCellTap = onCellTap
        self.selectedCell = selectedCell
        self.selectedRange = selectedRange
        self.selectedRow = selectedRow
        self.selectedColumn = selectedColumn
        self.onRowTap = onRowTap
        self.onColumnTap = onColumnTap
        self.showHeaders = showHeaders
        self.onSelectionChange = onSelectionChange
        // If no column configs provided, use flexible for all columns
        if columnConfigs.isEmpty {
            self.columnConfigs = Array(repeating: .flexible(), count: data.first?.count ?? 4)
        } else {
            self.columnConfigs = columnConfigs
        }
        
        self.borderAppearance = borderAppearance
    }
    
    public var body: some View {
        Group {
            if hasFlexibleColumns {
                GeometryReader { geometry in
                    let availableWidth = max(geometry.size.width - borderAppearance.width, 0)
                    let columnWidths = resolvedColumnWidths(totalWidth: availableWidth)
                    gridContent(columnWidths: columnWidths)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .padding(borderAppearance.width / 2)
                }
            } else {
                let idealWidth = calculateIdealWidth()
                let columnWidths = resolvedColumnWidths(totalWidth: idealWidth)
                gridContent(columnWidths: columnWidths)
                    .frame(width: idealWidth + borderAppearance.width)
                    .padding(borderAppearance.width / 2)
            }
        }
        .frame(height: calculatedGridHeight > 0 ? calculatedGridHeight : nil)
        .fixedSize(horizontal: !hasFlexibleColumns, vertical: true)
        .onPreferenceChange(DocumentGridCellHeightPreferenceKey.self) { measurements in
            updateCalculatedGridHeight(with: measurements)
        }
        .background(
            Color.clear.preference(
                key: GridIdealWidthPreferenceKey.self,
                value: calculateIdealWidth() + borderAppearance.width
            )
        )
        .coordinateSpace(name: "documentGrid")
        .onPreferenceChange(DocumentGridCellFramePreferenceKey.self) { frames in
            self.cellFrames = frames
        }
    }
    
    private func gridContent(columnWidths: [CGFloat]) -> some View {
        ZStack {
            measurementLayer
                .environment(\.documentGridMeasurementPhase, .widthMeasurement)
            mainGridLayer(columnWidths: columnWidths)
                .environment(\.documentGridMeasurementPhase, .content)
        }
    }
    
    private var hasFlexibleColumns: Bool {
        columnConfigs.contains { $0.isFlexible }
    }
    
    private func calculateIdealWidth() -> CGFloat {
        var width: CGFloat = 0
        for (index, config) in columnConfigs.enumerated() {
            if config.isAutoSized {
                width += contentColumnWidths[index] ?? defaultAutoColumnWidth
            } else if let fixed = config.fixedWidth {
                width += fixed
            }
        }
        return width
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
                let rawMeasuredWidth = contentColumnWidths[index] ?? 0
                // If measured width is 0 (empty), use default fallback
                let measuredWidth = rawMeasuredWidth > 0 ? rawMeasuredWidth : defaultAutoColumnWidth
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
            
            // Column Headers Removed

            
            ForEach(Array(data.indices), id: \.self) { rowIndex in
                let rowData = data[rowIndex]
                
                // Add horizontal border before this row (including first row)
                // Border appears where cells above have content
                GridRow {
                    // Row Header Border Spacer Removed


                    // Check each column position for borders
                    ForEach(0..<columnWidths.count, id: \.self) { colIndex in
                        let cellAboveEmpty = isCellAboveEmpty(rowIndex: rowIndex, cellIndex: colIndex)
                        let shouldShowBorder = !cellAboveEmpty && shouldDrawHorizontalBorder(beforeRow: rowIndex)

                        Rectangle()
                            .fill(shouldShowBorder ? horizontalBorderColor(forRow: rowIndex) : Color.clear)
                            .frame(
                                width: colIndex < columnWidths.count ? columnWidths[colIndex] : 0,
                                height: borderAppearance.width
                            )
                    }
                }

                // Main content row
                GridRow {
                    // Row Header Removed


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
                                
                                // Selection Overlay - uses live drag range or committed selection
                                selectionOverlay(for: rowIndex, column: cellIndex, width: cellWidth)
                            }
                            .contentShape(Rectangle())
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: DocumentGridCellFramePreferenceKey.self, 
                                        value: ["\(rowIndex):\(cellIndex)": geo.frame(in: .named("documentGrid"))]
                                    )
                                }
                            )
                            .onTapGesture {
                                onCellTap?(rowIndex, cellIndex)
                            }
                            .onHover { isHovering in
                                if isHovering {
                                    hoveredCell = (row: rowIndex, column: cellIndex)
                                } else if hoveredCell?.row == rowIndex && hoveredCell?.column == cellIndex {
                                    hoveredCell = nil
                                }
                            }
                        }
                    }
                }
            }

            // Bottom border for the entire grid
            GridRow {
                // Row Header Spacer Removed

                // Check each column position for bottom borders
                ForEach(0..<columnWidths.count, id: \.self) { colIndex in
                    let finalCellEmpty = isBottomCellEmpty(columnIndex: colIndex)
                    let shouldShowBorder = !finalCellEmpty && shouldDrawBottomBorder()

                    Rectangle()
                        .fill(shouldShowBorder ? borderAppearance.color : Color.clear)
                        .frame(
                            width: colIndex < columnWidths.count ? columnWidths[colIndex] : 0,
                            height: borderAppearance.width
                        )
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true) // Allow vertical expansion for text wrapping
        .background(
            GeometryReader { gridGeometry in
                Color.clear.preference(
                    key: GridSizePreferenceKey.self,
                    value: gridGeometry.size
                )
            }
        )
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleDrag(value)
                }
                .onEnded { _ in
                    handleDragEnd()
                }
        )
    }

    /// Returns selection overlay view for a cell based on live drag or committed range
    @ViewBuilder
    private func selectionOverlay(for row: Int, column: Int, width: CGFloat) -> some View {
        let effectiveRange = liveSelectionRange ?? selectedRange
        let isSingleCell = selectedCell != nil && selectedCell?.row == row && selectedCell?.column == column
        let isInRange = effectiveRange.map { $0.rows.contains(row) && $0.columns.contains(column) } ?? false
        let isHovered = hoveredCell?.row == row && hoveredCell?.column == column
        let isSelected = isSingleCell || isInRange
        
        ZStack {
            // Hover highlight (fill only)
            if isHovered && !isSelected {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.08))
                    .frame(width: width)
            }
            
            // Selection frame (border only)
            if isSelected {
                selectionBorder(for: row, column: column, range: effectiveRange, isSingle: isSingleCell, width: width)
                    .frame(width: width)
                    .animation(.easeInOut(duration: 0.12), value: effectiveRange?.rows)
                    .animation(.easeInOut(duration: 0.12), value: effectiveRange?.columns)
            }
        }
    }
    
    /// Creates border overlay showing edges only on range boundary
    @ViewBuilder
    private func selectionBorder(for row: Int, column: Int, range: (rows: ClosedRange<Int>, columns: ClosedRange<Int>)?, isSingle: Bool, width: CGFloat) -> some View {
        let borderWidth: CGFloat = 2
        let borderColor = Color.accentColor
        
        if isSingle {
            // Single cell - all edges
            Rectangle()
                .stroke(borderColor, lineWidth: borderWidth)
        } else if let range = range {
            // Range - only edges on boundary
            ZStack {
                if row == range.rows.lowerBound {
                    Rectangle().fill(borderColor).frame(height: borderWidth).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                if row == range.rows.upperBound {
                    Rectangle().fill(borderColor).frame(height: borderWidth).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                if column == range.columns.lowerBound {
                    Rectangle().fill(borderColor).frame(width: borderWidth).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
                if column == range.columns.upperBound {
                    Rectangle().fill(borderColor).frame(width: borderWidth).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private func handleDrag(_ value: DragGesture.Value) {
        let location = value.location
        
        // Find cell under location
        guard let hit = cellFrames.first(where: { $0.value.contains(location) }) else { return }
        let parts = hit.key.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return }
        let row = parts[0]
        let col = parts[1]
        
        if dragStartCell == nil {
            dragStartCell = (row, col)
        }
        
        guard let start = dragStartCell else { return }
        
        // Calculate range
        let minRow = min(start.row, row)
        let maxRow = max(start.row, row)
        let minCol = min(start.column, col)
        let maxCol = max(start.column, col)
        
        // Update live preview
        liveSelectionRange = (rows: minRow...maxRow, columns: minCol...maxCol)
    }
    
    private func handleDragEnd() {
        // Commit the selection
        if let range = liveSelectionRange {
            if range.rows.count == 1 && range.columns.count == 1 {
                onSelectionChange?(.cell(row: range.rows.lowerBound, column: range.columns.lowerBound))
            } else {
                onSelectionChange?(.cellRange(rows: range.rows, columns: range.columns))
            }
        }
        
        // Clear live state
        dragStartCell = nil
        liveSelectionRange = nil
    }

    
    private func updateCalculatedGridHeight(with measurements: [DocumentGridCellHeightMeasurement]) {
        guard !measurements.isEmpty else {
            calculatedGridHeight = 0
            return
        }
        
        var rowHeights: [Int: CGFloat] = [:]
        for measurement in measurements where measurement.height > 0 {
            rowHeights[measurement.rowIndex] = max(rowHeights[measurement.rowIndex] ?? 0, measurement.height)
        }
        
        let totalRowHeight = (0..<data.count).reduce(CGFloat(0)) { partial, rowIndex in
            partial + (rowHeights[rowIndex] ?? 0)
        }
        
        let borderHeight = totalHorizontalBorderHeight(rowCount: data.count)
        let paddingContribution = borderAppearance.width
        let totalHeight = max(totalRowHeight + borderHeight + paddingContribution, 0)
        
        if abs(totalHeight - calculatedGridHeight) > 0.5 {
            calculatedGridHeight = totalHeight
        }
    }
    
    private func totalHorizontalBorderHeight(rowCount: Int) -> CGFloat {
        guard rowCount > 0 else {
            return shouldDrawBottomBorder() ? borderAppearance.width : 0
        }
        
        var total: CGFloat = 0
        for rowIndex in 0..<rowCount {
            if shouldDrawHorizontalBorder(beforeRow: rowIndex) {
                total += borderAppearance.width
            }
        }
        
        if shouldDrawBottomBorder() {
            total += borderAppearance.width
        }
        
        return total
    }
    
    private func verticalBorderForCell(_ item: DocumentTableItem, rowIndex: Int, cellIndex: Int, rowData: [DocumentTableItem]) -> some View {
        let isCurrentCellEmpty = item.isTransparent
        let showCellBorders = borderAppearance.showCellBorders
        let isFirstCell = cellIndex == 0
        let isLastCell = cellIndex == rowData.count - 1

        return ZStack {
            // Leading border - only for first cell or when cell borders are enabled
            if isFirstCell || showCellBorders {
                let leadingColor = isCurrentCellEmpty ? Color.clear : borderAppearance.color
                Rectangle()
                    .fill(leadingColor)
                    .frame(width: borderAppearance.width)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }

            // Trailing border - only for last cell
            if isLastCell {
                let trailingColor = isCurrentCellEmpty ? Color.clear : borderAppearance.color
                Rectangle()
                    .fill(trailingColor)
                    .frame(width: borderAppearance.width)
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
            return borderAppearance.showHeaderBorders
        }
        return borderAppearance.showRowBorders
    }

    private func shouldDrawBottomBorder() -> Bool {
        borderAppearance.showRowBorders
    }

    private func horizontalBorderColor(forRow rowIndex: Int) -> Color {
        rowIndex == 0 ? borderAppearance.effectiveHeaderColor : borderAppearance.color
    }
}
