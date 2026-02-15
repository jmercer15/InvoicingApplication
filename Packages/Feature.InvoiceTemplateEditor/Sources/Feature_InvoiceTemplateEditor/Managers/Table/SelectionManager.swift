import Foundation
import Combine
import AppKit

@MainActor
public class SelectionManager: ObservableObject {
    @Published public var selectedCells: Set<GridCoordinate> = []
    private var document: TableDocument
    
    public init(document: TableDocument) {
        self.document = document
    }
    
    @Published public var selectionAnchor: GridCoordinate?
    @Published public var selectionHead: GridCoordinate?
    
    /// Selects a range from start (anchor) to end (head), respecting merged cell boundaries.
    public func selectRange(from start: GridCoordinate, to end: GridCoordinate) {
        self.selectionAnchor = start
        self.selectionHead = end
        
        var minRow = min(start.row, end.row)
        var maxRow = max(start.row, end.row)
        var minCol = min(start.column, end.column)
        var maxCol = max(start.column, end.column)
        
        var selectionChanged = true
        
        // Iteratively expand selection until it stabilizes (Merged Cell Invariant)
        while selectionChanged {
            selectionChanged = false
            
            let currentMinRow = minRow
            let currentMaxRow = maxRow
            let currentMinCol = minCol
            let currentMaxCol = maxCol
            
            for r in currentMinRow...currentMaxRow {
                for c in currentMinCol...currentMaxCol {
                    let coord = GridCoordinate(row: r, column: c)
                    if document.cell(at: coord) != nil {
                        if let anchor = document.anchor(for: coord) {
                            let startRow = anchor.coordinate.row
                            let endRow = startRow + anchor.span.rowSpan - 1
                            let startCol = anchor.coordinate.column
                            let endCol = startCol + anchor.span.colSpan - 1
                            
                            if startRow < minRow { minRow = startRow; selectionChanged = true }
                            if endRow > maxRow { maxRow = endRow; selectionChanged = true }
                            if startCol < minCol { minCol = startCol; selectionChanged = true }
                            if endCol > maxCol { maxCol = endCol; selectionChanged = true }
                        }
                    }
                }
            }
        }
        
        // Finalize selection
        var newSelection: Set<GridCoordinate> = []
        for r in minRow...maxRow {
            for c in minCol...maxCol {
                newSelection.insert(GridCoordinate(row: r, column: c))
            }
        }
        
        self.selectedCells = newSelection
    }
    
    public enum MoveDirection {
        case up, down, left, right
    }
    
    public func moveSelection(direction: MoveDirection, modifiers: NSEvent.ModifierFlags) {
        // Use tracked head, or default to (0,0) if missing
        let currentHead = selectionHead ?? GridCoordinate(row: 0, column: 0)
        let currentAnchor = selectionAnchor ?? currentHead
        
        // Get span of the CURRENT head cell to determine jump size
        // If the head is part of a merged cell, we should move from the edge of that merge?
        // Logic:
        // - Logic for standard navigation (no shift): Jump to next cell.
        // - Logic for selection extension (shift): extend by 1 unit or by merged cell block?
        // Excel extends by 1 unit of the underlying grid usually, unless navigating "over" a merge.
        // Let's stick to moving by span for consistency with "moving out of a cell".
        
        guard let cell = document.cell(at: currentHead) else { return }
        
        var nextRow = currentHead.row
        var nextCol = currentHead.column
        
        switch direction {
        case .up:
            // Move up from the top of the current cell
            nextRow = max(0, currentHead.row - 1)
        case .down:
            // Move down from the bottom of the current cell
            nextRow = min(document.rowCount - 1, currentHead.row + cell.span.rowSpan)
        case .left:
            // Move left from the left of the current cell
            nextCol = max(0, currentHead.column - 1)
        case .right:
            // Move right from the right of the current cell
            nextCol = min(document.colCount - 1, currentHead.column + cell.span.colSpan)
        }
        
        let nextCoord = GridCoordinate(row: nextRow, column: nextCol)
        
        // Check if we bumped into bounds (didn't change)
        // Note: checking equality of coord is not enough if we are spanned, 
        // but here we calculated based on span, so if we are at edge, it clamps.
        
        if let target = document.cell(at: nextCoord) {
            // Target is the anchor of the cell we landed on.
            // If we are shift-selecting, we want to encompass this target.
            
            if modifiers.contains(.shift) {
                // Extend selection from original anchor to the NEW target
                // We use target.coordinate which is the anchor of the cell we moved to.
                selectRange(from: currentAnchor, to: target.coordinate)
            } else {
                // Move selection entireley
                selectRange(from: target.coordinate, to: target.coordinate)
            }
        }
    }
    
    public func clearSelection() {
        selectedCells.removeAll()
    }
}
