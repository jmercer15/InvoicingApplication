import Foundation
import SwiftUI

/// Observable table model that backs the editor views.
@MainActor
public final class TableDocument: ObservableObject {
    @Published public private(set) var rowCount: Int
    @Published public private(set) var colCount: Int
    
    /// Sparse storage: Only anchor cells are stored here.
    @Published public var cells: [GridCoordinate: CellModel]
    
    /// Maps every logical coordinate to its governing anchor coordinate.
    /// If (1,1) is part of a merge starting at (0,0), spanIndex[(1,1)] = (0,0).
    /// If (2,2) is a single cell, spanIndex[(2,2)] = (2,2).
    @Published public var spanIndex: [GridCoordinate: GridCoordinate]
    
    // Styling + sizing controls
    @Published public var rowHeights: [Int: CGFloat] = [:]
    @Published public var rowContentHeights: [Int: CGFloat] = [:]
    @Published public var colWidths: [Int: CGFloat] = [:]
    @Published public var isAlternatingRowColorsEnabled: Bool = false
    @Published public var isHeaderRowEnabled: Bool = false
    @Published public var isFirstColumnEnabled: Bool = false
    
    nonisolated public static let minColumnWidth: CGFloat = 50
    nonisolated public static let minRowHeight: CGFloat = 24
    
    public init(rowCount: Int, colCount: Int) {
        self.rowCount = rowCount
        self.colCount = colCount
        self.cells = [:]
        self.spanIndex = [:]
        
        for row in 0..<rowCount {
            for col in 0..<colCount {
                let coord = GridCoordinate(row: row, column: col)
                let cell = CellModel(content: RichTextContent(), coordinate: coord)
                self.cells[coord] = cell
                self.spanIndex[coord] = coord
            }
        }
    }
}

// MARK: - Accessors
public extension TableDocument {
    var activeCells: [CellModel] {
        // Return all stored anchor cells. 
        // Note: In a sparse model, 'cells' only contains the visible anchors.
        // We sort them for consistent iteration order (e.g. for accessibility or debugging).
        cells.values.sorted { 
            if $0.coordinate.row != $1.coordinate.row {
                return $0.coordinate.row < $1.coordinate.row
            }
            return $0.coordinate.column < $1.coordinate.column
        }
    }
    
    func cell(at coordinate: GridCoordinate) -> CellModel? {
        // Direct lookup of the anchor.
        // If the coordinate is part of a merged cell, we must look up the anchor via spanIndex.
        guard let anchorCoord = spanIndex[coordinate] else { return nil }
        return cells[anchorCoord]
    }
    
    func anchor(for coordinate: GridCoordinate) -> CellModel? {
        // In the sparse model, cell(at:) essentially returns the anchor.
        return cell(at: coordinate)
    }
    
    @MainActor
    func bindingForContent(at coordinate: GridCoordinate) -> Binding<RichTextContent> {
        Binding<RichTextContent>(
            get: { self.cell(at: coordinate)?.content ?? RichTextContent() },
            set: { newValue in
                self.updateContent(for: coordinate, content: newValue)
            }
        )
    }
}

// MARK: - Public mutations
public extension TableDocument {
    func updateContent(for coordinate: GridCoordinate, content: RichTextContent) {
        guard var cell = cell(at: coordinate) else { return }
        cell.content = content
        // Update the anchor in storage
        cells[cell.coordinate] = cell
    }
    
    func updateStyle(for selection: Set<GridCoordinate>, update: (inout CellStyle) -> Void) {
        for coord in selection {
            guard var cell = cell(at: coord) else { continue }
            update(&cell.style)
            cells[cell.coordinate] = cell
        }
    }
    
    func merge(selection: Set<GridCoordinate>) {
        guard let rect = expandedSelectionRect(for: selection) else { return }
        
        let anchorCoord = GridCoordinate(row: rect.rows.lowerBound, column: rect.cols.lowerBound)
        let rowSpan = rect.rows.upperBound - rect.rows.lowerBound + 1
        let colSpan = rect.cols.upperBound - rect.cols.lowerBound + 1
        
        // 1. Get the anchor cell (or create a new one if the top-left was previously part of another merge, though expandedSelectionRect should prevent that).
        guard var anchorCell = cell(at: anchorCoord) else { return }
        
        // 2. Update anchor properties
        anchorCell.span = CellSpan(rowSpan: rowSpan, colSpan: colSpan)
        anchorCell.isVisible = true
        
        // 3. Consolidate content
        // Iterate in reading order (row-major)
        for r in rect.rows {
            for c in rect.cols {
                let coord = GridCoordinate(row: r, column: c)
                if coord == anchorCoord { continue }
                
                // Get content from the cell at this coordinate (it might be an anchor or a spanned part)
                // But in our sparse model, we only store anchors.
                // If (r,c) is part of another span, we should have already expanded the rect to include it entirely.
                // So we just need to check if there is an anchor at this coord.
                if let otherCell = cells[coord] {
                    anchorCell.content.append(otherCell.content)
                }
            }
        }
        
        // 4. Update storage and span index
        cells[anchorCoord] = anchorCell
        
        for r in rect.rows {
            for c in rect.cols {
                let coord = GridCoordinate(row: r, column: c)
                if coord != anchorCoord {
                    // Remove other cells from storage
                    cells.removeValue(forKey: coord)
                }
                // Point all coords in the rect to the anchor
                spanIndex[coord] = anchorCoord
            }
        }
    }
    
    func split(cell: CellModel) {
        // The passed cell is the anchor.
        let anchorCoord = cell.coordinate
        let rowSpan = cell.span.rowSpan
        let colSpan = cell.span.colSpan
        
        guard rowSpan > 1 || colSpan > 1 else { return }
        
        // 1. Reset anchor span
        var newAnchor = cell
        newAnchor.span = .standard
        cells[anchorCoord] = newAnchor
        
        // 2. Restore other cells
        for r in anchorCoord.row..<(anchorCoord.row + rowSpan) {
            for c in anchorCoord.column..<(anchorCoord.column + colSpan) {
                let coord = GridCoordinate(row: r, column: c)
                
                // Update span index to point to itself
                spanIndex[coord] = coord
                
                if coord != anchorCoord {
                    // Create new empty cell
                    let newCell = CellModel(
                        id: UUID(),
                        content: RichTextContent(),
                        coordinate: coord,
                        span: .standard,
                        isVisible: true,
                        style: cell.style // Inherit style
                    )
                    cells[coord] = newCell
                }
            }
        }
    }
    
    func insertRow(at index: Int) {
        let insertIndex = max(0, min(index, rowCount))
        rowCount += 1
        
        // We must shift all cells below the insertion point down by 1.
        // Iterate backwards to avoid overwriting.
        // Since it's a dictionary, order doesn't matter for correctness, but we need to be careful not to process the same cell twice if we were iterating.
        // Strategy: Collect all updates then apply.
        
        var newCells: [GridCoordinate: CellModel] = [:]
        var newSpanIndex: [GridCoordinate: GridCoordinate] = [:]
        
        // Rebuild the grid
        // This is O(N) where N is number of cells.
        for (coord, cell) in cells {
            var newCoord = coord
            var newSpan = cell.span
            
            // If the cell is below the insertion point, shift it down.
            if coord.row >= insertIndex {
                newCoord.row += 1
            }
            
            // If the insertion point cuts through a spanned cell, expand the span.
            if coord.row < insertIndex && (coord.row + cell.span.rowSpan) > insertIndex {
                newSpan.rowSpan += 1
            }
            
            var newCell = cell
            newCell.coordinate = newCoord
            newCell.span = newSpan
            newCells[newCoord] = newCell
        }
        
        // Fill the gap with new cells
        for c in 0..<colCount {
            let coord = GridCoordinate(row: insertIndex, column: c)
            // Check if this spot is covered by a span from above
            var coveredBySpan = false
            for (existingCoord, existingCell) in newCells {
                if existingCoord.row < insertIndex && (existingCoord.row + existingCell.span.rowSpan) > insertIndex &&
                   existingCoord.column <= c && (existingCoord.column + existingCell.span.colSpan) > c {
                    coveredBySpan = true
                    break
                }
            }
            
            if !coveredBySpan {
                let newCell = CellModel(content: RichTextContent(), coordinate: coord)
                newCells[coord] = newCell
            }
        }
        
        self.cells = newCells
        rebuildSpanIndex()
    }
    
    func insertColumn(at index: Int) {
        let insertIndex = max(0, min(index, colCount))
        colCount += 1
        
        var newCells: [GridCoordinate: CellModel] = [:]
        
        for (coord, cell) in cells {
            var newCoord = coord
            var newSpan = cell.span
            
            if coord.column >= insertIndex {
                newCoord.column += 1
            }
            
            if coord.column < insertIndex && (coord.column + cell.span.colSpan) > insertIndex {
                newSpan.colSpan += 1
            }
            
            var newCell = cell
            newCell.coordinate = newCoord
            newCell.span = newSpan
            newCells[newCoord] = newCell
        }
        
        for r in 0..<rowCount {
            let coord = GridCoordinate(row: r, column: insertIndex)
            var coveredBySpan = false
            for (existingCoord, existingCell) in newCells {
                if existingCoord.column < insertIndex && (existingCoord.column + existingCell.span.colSpan) > insertIndex &&
                   existingCoord.row <= r && (existingCoord.row + existingCell.span.rowSpan) > r {
                    coveredBySpan = true
                    break
                }
            }
            
            if !coveredBySpan {
                let newCell = CellModel(content: RichTextContent(), coordinate: coord)
                newCells[coord] = newCell
            }
        }
        
        self.cells = newCells
        rebuildSpanIndex()
    }
    
    func deleteRow(at index: Int) {
        guard rowCount > 1 else { return }
        let removeIndex = max(0, min(index, rowCount - 1))
        rowCount -= 1
        
        var newCells: [GridCoordinate: CellModel] = [:]
        
        for (coord, cell) in cells {
            if coord.row == removeIndex {
                // This anchor is being deleted.
                // If it was a spanned cell, we might need to handle the remaining parts?
                // For simplicity, we just delete it.
                continue
            }
            
            var newCoord = coord
            var newSpan = cell.span
            
            if coord.row > removeIndex {
                newCoord.row -= 1
            }
            
            if coord.row < removeIndex && (coord.row + cell.span.rowSpan) > removeIndex {
                newSpan.rowSpan = max(1, newSpan.rowSpan - 1)
            }
            
            var newCell = cell
            newCell.coordinate = newCoord
            newCell.span = newSpan
            newCells[newCoord] = newCell
        }
        
        self.cells = newCells
        rebuildSpanIndex()
    }
    
    func deleteColumn(at index: Int) {
        guard colCount > 1 else { return }
        let removeIndex = max(0, min(index, colCount - 1))
        colCount -= 1
        
        var newCells: [GridCoordinate: CellModel] = [:]
        
        for (coord, cell) in cells {
            if coord.column == removeIndex { continue }
            
            var newCoord = coord
            var newSpan = cell.span
            
            if coord.column > removeIndex {
                newCoord.column -= 1
            }
            
            if coord.column < removeIndex && (coord.column + cell.span.colSpan) > removeIndex {
                newSpan.colSpan = max(1, newSpan.colSpan - 1)
            }
            
            var newCell = cell
            newCell.coordinate = newCoord
            newCell.span = newSpan
            newCells[newCoord] = newCell
        }
        
        self.cells = newCells
        rebuildSpanIndex()
    }
    
    private func rebuildSpanIndex() {
        spanIndex = [:]
        for (anchorCoord, cell) in cells {
            for r in anchorCoord.row..<(anchorCoord.row + cell.span.rowSpan) {
                for c in anchorCoord.column..<(anchorCoord.column + cell.span.colSpan) {
                    spanIndex[GridCoordinate(row: r, column: c)] = anchorCoord
                }
            }
        }
    }
    
    func distributeRows(in rows: Set<Int>) {
        guard !rows.isEmpty else { return }
        let maxHeight = rows.compactMap { rowHeights[$0] }.max() ?? 40
        for r in rows {
            rowHeights[r] = maxHeight
        }
    }
    
    func distributeColumns(in cols: Set<Int>) {
        guard !cols.isEmpty else { return }
        let maxWidth = cols.compactMap { colWidths[$0] }.max() ?? 100
        for c in cols {
            colWidths[c] = maxWidth
        }
    }
    
    func resizeColumn(index: Int, width: CGFloat) {
        colWidths[index] = max(TableDocument.minColumnWidth, width)
    }
    
    func resizeRow(index: Int, height: CGFloat) {
        rowHeights[index] = max(TableDocument.minRowHeight, height)
    }
    
    func updateRowContentHeight(index: Int, height: CGFloat) {
        // Only update if changed to avoid infinite loops if the value oscillates slightly
        guard rowContentHeights[index] != height else { return }
        
        // Defer update to avoid "Publishing changes from within view updates" warning
        let newValue = height
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.rowContentHeights[index] = newValue
        }
    }
}

// MARK: - Helpers
private extension TableDocument {
    func expandedSelectionRect(for selection: Set<GridCoordinate>) -> (rows: ClosedRange<Int>, cols: ClosedRange<Int>)? {
        guard !selection.isEmpty else { return nil }
        
        // Expand selection to cover full spans of any merged cells touched.
        var expanded = selection
        var changed = true
        while changed {
            changed = false
            for coord in expanded {
                guard let anchor = anchor(for: coord) else { continue }
                let rowRange = anchor.coordinate.row..<(anchor.coordinate.row + anchor.span.rowSpan)
                let colRange = anchor.coordinate.column..<(anchor.coordinate.column + anchor.span.colSpan)
                for r in rowRange {
                    for c in colRange {
                        let expandedCoord = GridCoordinate(row: r, column: c)
                        if !expanded.contains(expandedCoord) {
                            expanded.insert(expandedCoord)
                            changed = true
                        }
                    }
                }
            }
        }
        
        let rows = expanded.map { $0.row }
        let cols = expanded.map { $0.column }
        guard let minRow = rows.min(),
              let maxRow = rows.max(),
              let minCol = cols.min(),
              let maxCol = cols.max() else { return nil }
        
        let expectedRowCount = maxRow - minRow + 1
        let expectedColCount = maxCol - minCol + 1
        
        // Require that every row/col within the bounds is touched at least once,
        // otherwise this is likely a disjoint selection (e.g. two far apart cells).
        let uniqueRows = Set(rows)
        let uniqueCols = Set(cols)
        guard uniqueRows.count == expectedRowCount,
              uniqueCols.count == expectedColCount else { return nil }
        
        return (rows: minRow...maxRow, cols: minCol...maxCol)
    }
}
