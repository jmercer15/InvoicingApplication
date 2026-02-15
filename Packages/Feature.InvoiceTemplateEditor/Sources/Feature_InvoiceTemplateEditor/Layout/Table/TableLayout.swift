import SwiftUI

public struct TableLayout: Layout {
    public var cells: [CellModel] // These must be the *active* cells, matching the subviews
    public var colCount: Int
    public var rowCount: Int
    public var horizontalSpacing: CGFloat = 0
    public var verticalSpacing: CGFloat = 0
    
    public var explicitRowHeights: [Int: CGFloat]
    public var explicitColWidths: [Int: CGFloat]
    public var rowContentHeights: [Int: CGFloat]
    
    public init(cells: [CellModel], colCount: Int, rowCount: Int, horizontalSpacing: CGFloat = 0, verticalSpacing: CGFloat = 0, explicitRowHeights: [Int: CGFloat] = [:], explicitColWidths: [Int: CGFloat] = [:], rowContentHeights: [Int: CGFloat] = [:]) {
        self.cells = cells
        self.colCount = colCount
        self.rowCount = rowCount
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.explicitRowHeights = explicitRowHeights
        self.explicitColWidths = explicitColWidths
        self.rowContentHeights = rowContentHeights
    }
    
    public func makeCache(subviews: Subviews) -> TableLayoutCache {
        // 1. Calculate Column Widths
        var columnWidths = Array(repeating: TableDocument.minColumnWidth, count: colCount)
        
        // Pass 1: Single-column cells
        for (index, subview) in subviews.enumerated() {
            guard index < cells.count else { continue }
            let cell = cells[index]
            
            if cell.span.colSpan == 1 {
                // Check for explicit width
                if let explicit = explicitColWidths[cell.coordinate.column] {
                    columnWidths[cell.coordinate.column] = max(TableDocument.minColumnWidth, explicit)
                } else {
                    let size = subview.sizeThatFits(.unspecified)
                    columnWidths[cell.coordinate.column] = max(columnWidths[cell.coordinate.column], size.width)
                }
            }
        }
        
        // Pass 2: Spanned cells (simplified: ensure total width covers it)
        for (index, subview) in subviews.enumerated() {
            guard index < cells.count else { continue }
            let cell = cells[index]
            
            if cell.span.colSpan > 1 {
                let size = subview.sizeThatFits(.unspecified)
                let startCol = cell.coordinate.column
                let endCol = startCol + cell.span.colSpan
                
                let currentWidth = (startCol..<endCol).reduce(0) { $0 + columnWidths[$1] } + CGFloat(cell.span.colSpan - 1) * horizontalSpacing
                
                if currentWidth < size.width {
                    let deficit = size.width - currentWidth
                    let distribution = deficit / CGFloat(cell.span.colSpan)
                    for c in startCol..<endCol {
                        columnWidths[c] += distribution
                    }
                }
            }
        }
        
        // 2. Calculate Row Heights
        // We need to propose the calculated column widths to the cells to get their heights.
        var rowHeights = Array(repeating: TableDocument.minRowHeight, count: rowCount)
        
        for (index, subview) in subviews.enumerated() {
            guard index < cells.count else { continue }
            let cell = cells[index]
            
            // Calculate available width for this cell
            let startCol = cell.coordinate.column
            let endCol = startCol + cell.span.colSpan
            let cellWidth = (startCol..<endCol).reduce(0) { $0 + columnWidths[$1] } + CGFloat(cell.span.colSpan - 1) * horizontalSpacing
            
            let size = subview.sizeThatFits(ProposedViewSize(width: cellWidth, height: nil))
            
            // Distribute height (simplified: give it all to the last row or distribute? 
            // Standard table behavior usually expands the row. 
            // For spanned rows, we check if the sum of rows covers it.)
            
            if cell.span.rowSpan == 1 {
                let contentHeight = rowContentHeights[cell.coordinate.row] ?? 0
                if let explicit = explicitRowHeights[cell.coordinate.row] {
                    rowHeights[cell.coordinate.row] = max(explicit, contentHeight)
                } else {
                    rowHeights[cell.coordinate.row] = max(rowHeights[cell.coordinate.row], size.height, contentHeight)
                }
            } else {
                // Spanned rows logic
                let startRow = cell.coordinate.row
                let endRow = startRow + cell.span.rowSpan
                let currentHeight = (startRow..<endRow).reduce(0) { $0 + rowHeights[$1] } + CGFloat(cell.span.rowSpan - 1) * verticalSpacing
                
                if currentHeight < size.height {
                    let deficit = size.height - currentHeight
                    // Word-like behavior: Add the deficit to the last row of the span.
                    // This prevents "wobble" where all rows grow slightly.
                    let lastRowIndex = endRow - 1
                    if lastRowIndex < rowHeights.count {
                        rowHeights[lastRowIndex] += deficit
                    }
                }
            }
        }
        
        // 3. Calculate Total Size
        let totalWidth = columnWidths.reduce(0, +) + CGFloat(colCount - 1) * horizontalSpacing
        let totalHeight = rowHeights.reduce(0, +) + CGFloat(rowCount - 1) * verticalSpacing
        
        return TableLayoutCache(columnWidths: columnWidths, rowHeights: rowHeights, totalSize: CGSize(width: totalWidth, height: totalHeight))
    }
    
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout TableLayoutCache) -> CGSize {
        return cache.totalSize
    }
    
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout TableLayoutCache) {
        let xOffsets = GeometryUtils.computeCumulative(sizes: cache.columnWidths, spacing: horizontalSpacing)
        let yOffsets = GeometryUtils.computeCumulative(sizes: cache.rowHeights, spacing: verticalSpacing)
        
        for (index, subview) in subviews.enumerated() {
            guard index < cells.count else { continue }
            let cell = cells[index]
            
            let r = cell.coordinate.row
            let c = cell.coordinate.column
            
            guard r < yOffsets.count - 1, c < xOffsets.count - 1 else { continue }
            
            let x = bounds.minX + xOffsets[c]
            let y = bounds.minY + yOffsets[r]
            
            // Calculate width based on span
            let width = (0..<cell.span.colSpan).reduce(0) { $0 + cache.columnWidths[c + $1] } + CGFloat(cell.span.colSpan - 1) * horizontalSpacing
            
            // Calculate height based on span
            let height = (0..<cell.span.rowSpan).reduce(0) { $0 + cache.rowHeights[r + $1] } + CGFloat(cell.span.rowSpan - 1) * verticalSpacing
            
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: height)
            )
        }
    }
}
