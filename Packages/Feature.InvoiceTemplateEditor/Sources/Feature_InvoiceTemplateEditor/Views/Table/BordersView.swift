import SwiftUI

/// Unified borders component combining visual rendering and resize interaction
struct BordersView: View {
    @ObservedObject var document: TableDocument
    let cellFrames: [GridCoordinate: CGRect]
    
    @State private var draggingBorder: DraggingBorderInfo?
    @State private var hoveringBorder: HoveringBorderInfo?
    
    struct HoveringBorderInfo: Equatable {
        enum Axis { case row, column }
        let axis: Axis
        let index: Int
    }
    
    struct DraggingBorderInfo {
        enum Axis { case row, column }
        let axis: Axis
        let index: Int
        let initialPosition: CGFloat
        let initialSize: CGFloat
        var currentDelta: CGFloat
    }
    
    // Calculate cumulative column positions based on actual cell frames
    private var columnPositions: [CGFloat] {
        var positions: [CGFloat] = [0]
        var currentX: CGFloat = 0
        
        for col in 0..<document.colCount {
            // Try to find a cell that ends at this column to get the exact position
            // We look for a cell at (row, col) with span 1, or any cell ending at col
            var foundWidth: CGFloat?
            
            // 1. Search for a direct width from a single-span cell in this column
            for row in 0..<document.rowCount {
                let coord = GridCoordinate(row: row, column: col)
                if let frame = cellFrames[coord], 
                   let cell = document.activeCells.first(where: { $0.coordinate == coord }),
                   cell.span.colSpan == 1 {
                    foundWidth = frame.width
                    break
                }
            }
            
            // 2. If not found, try to derive from a cell ending at this column
            if foundWidth == nil {
                // This is harder with just a map, but we can iterate active cells
                // Fallback to model width if we can't find visual evidence
                foundWidth = document.colWidths[col] ?? TableDocument.minColumnWidth
            }
            
            let width = foundWidth ?? TableDocument.minColumnWidth
            currentX += width
            positions.append(currentX)
        }
        
        // Correction: The above logic is still additive and might drift. 
        // Better approach: Find the MAX X of column i directly.
        
        var exactPositions: [CGFloat] = [0]
        
        for col in 0..<document.colCount {
            // Target column index is 'col'. We want the Right edge of this column.
            // Find any cell that ends at 'col'.
            // i.e. cell.col + cell.colSpan - 1 == col
            
            var maxEdge: CGFloat?
            
            for (coord, frame) in cellFrames {
                // We need the cell model to know the span
                // Optimization: We can just check if coord.column == col and assume span 1? 
                // No, we need to handle spans.
                // But cellFrames keys are the anchors.
                
                if let cell = document.activeCells.first(where: { $0.coordinate == coord }) {
                    let endCol = cell.coordinate.column + cell.span.colSpan - 1
                    if endCol == col {
                        maxEdge = frame.maxX
                        break // Found an edge
                    }
                }
            }
            
            if let edge = maxEdge {
                exactPositions.append(edge)
            } else {
                // Fallback: add model width to previous
                let prev = exactPositions.last ?? 0
                let width = document.colWidths[col] ?? TableDocument.minColumnWidth
                exactPositions.append(prev + width)
            }
        }
        
        return exactPositions
    }
    
    // Calculate cumulative row positions based on actual cell frames
    private var rowPositions: [CGFloat] {
        var exactPositions: [CGFloat] = [0]
        
        for row in 0..<document.rowCount {
            var maxEdge: CGFloat?
            
            for (coord, frame) in cellFrames {
                if let cell = document.activeCells.first(where: { $0.coordinate == coord }) {
                    let endRow = cell.coordinate.row + cell.span.rowSpan - 1
                    if endRow == row {
                        maxEdge = frame.maxY
                        break
                    }
                }
            }
            
            if let edge = maxEdge {
                exactPositions.append(edge)
            } else {
                let prev = exactPositions.last ?? 0
                let height = document.rowHeights[row] ?? TableDocument.minRowHeight
                exactPositions.append(prev + height)
            }
        }
        
        return exactPositions
    }
    
    var body: some View {
        // Calculate positions once at the start
        let colPositions = columnPositions
        let rowPositions = rowPositions
        
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Layer 1: Visual borders (Canvas - efficient, no hit testing)
                Canvas { context, size in
                    // Draw vertical borders (column boundaries)
                    for (index, x) in colPositions.enumerated() {
                        // Determine hover/drag state
                        let isDragging = if index > 0, let border = draggingBorder {
                            border.axis == .column && border.index == index - 1
                        } else {
                            false
                        }
                        
                        let isHovering = if index > 0, let border = hoveringBorder {
                            border.axis == .column && border.index == index - 1
                        } else {
                            false
                        }
                        
                        let color: Color = isDragging ? .blue.opacity(0.6) : (isHovering ? .blue.opacity(0.4) : .gray.opacity(0.3))
                        let width: CGFloat = isDragging ? 2 : (isHovering ? 1.5 : 1)
                        
                        // Calculate segments to draw (skipping parts inside merged cells)
                        var segments: [(start: CGFloat, end: CGFloat)] = []
                        var currentY: CGFloat = 0
                        
                        for row in 0..<document.rowCount {
                            let rowY = rowPositions[row]
                            let nextRowY = rowPositions[row + 1]
                            
                            // Check if this border segment is inside a merged cell
                            var isInsideMerge = false
                            
                            if index > 0 && index < colPositions.count {
                                let col = index - 1
                                let coord = GridCoordinate(row: row, column: col)
                                
                                if let cell = document.cell(at: coord) {
                                    // Skip if this border is INSIDE the cell's column span (not on edges)
                                    if cell.span.colSpan > 1 && col >= cell.coordinate.column && col < cell.coordinate.column + cell.span.colSpan - 1 {
                                        isInsideMerge = true
                                    }
                                }
                            }
                            
                            if isInsideMerge {
                                // End current segment if we have one
                                if currentY < rowY {
                                    segments.append((start: currentY, end: rowY))
                                }
                                currentY = nextRowY
                            } else {
                                // If not inside a merge, continue the current segment or start a new one
                                // No explicit action needed here, currentY will naturally advance
                            }
                        }
                        
                        // Add final segment
                        if currentY < size.height {
                            segments.append((start: currentY, end: size.height))
                        }
                        
                        // Draw all segments
                        for segment in segments {
                            context.stroke(
                                Path { path in
                                    path.move(to: CGPoint(x: x, y: segment.start))
                                    path.addLine(to: CGPoint(x: x, y: segment.end))
                                },
                                with: .color(color),
                                lineWidth: width
                            )
                        }
                    }
                    
                    // Draw horizontal borders (row boundaries)
                    for (index, y) in rowPositions.enumerated() {
                        // Determine hover/drag state
                        let isDragging = if index > 0, let border = draggingBorder {
                            border.axis == .row && border.index == index - 1
                        } else {
                            false
                        }
                        
                        let isHovering = if index > 0, let border = hoveringBorder {
                            border.axis == .row && border.index == index - 1
                        } else {
                            false
                        }
                        
                        let color: Color = isDragging ? .blue.opacity(0.6) : (isHovering ? .blue.opacity(0.4) : .gray.opacity(0.3))
                        let width: CGFloat = isDragging ? 2 : (isHovering ? 1.5 : 1)
                        
                        // Calculate segments to draw (skipping parts inside merged cells)
                        var segments: [(start: CGFloat, end: CGFloat)] = []
                        var currentX: CGFloat = 0
                        
                        for col in 0..<document.colCount {
                            let colX = colPositions[col]
                            let nextColX = colPositions[col + 1]
                            
                            // Check if this border segment is inside a merged cell
                            var isInsideMerge = false
                            
                            if index > 0 && index < rowPositions.count {
                                let row = index - 1
                                let coord = GridCoordinate(row: row, column: col)
                                
                                if let cell = document.cell(at: coord) {
                                    // Skip if this border is INSIDE the cell's row span (not on edges)
                                    if cell.span.rowSpan > 1 && row >= cell.coordinate.row && row < cell.coordinate.row + cell.span.rowSpan - 1 {
                                        isInsideMerge = true
                                    }
                                }
                            }
                            
                            if isInsideMerge {
                                // End current segment if we have one
                                if currentX < colX {
                                    segments.append((start: currentX, end: colX))
                                }
                                currentX = nextColX
                            } else {
                                // If not inside a merge, continue the current segment or start a new one
                                // No explicit action needed here, currentX will naturally advance
                            }
                        }
                        
                        // Add final segment
                        if currentX < size.width {
                            segments.append((start: currentX, end: size.width))
                        }
                        
                        // Draw all segments
                        for segment in segments {
                            context.stroke(
                                Path { path in
                                    path.move(to: CGPoint(x: segment.start, y: y))
                                    path.addLine(to: CGPoint(x: segment.end, y: y))
                                },
                                with: .color(color),
                                lineWidth: width
                            )
                        }
                    }
                }
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.15), value: draggingBorder?.index)
                .animation(.easeInOut(duration: 0.15), value: draggingBorder?.axis)
                .animation(.easeInOut(duration: 0.15), value: hoveringBorder)
                
                // Layer 2: Resize interaction zones (transparent, positioned on borders)
                
                // Column resize zones
                ForEach(0..<document.colCount, id: \.self) { col in
                    let position = colPositions[col + 1]
                    
                    ResizeZone(
                        orientation: .vertical,
                        position: position,
                        length: geo.size.height,
                        onHoverChange: { isHovering in
                            if isHovering {
                                hoveringBorder = HoveringBorderInfo(axis: .column, index: col)
                            } else if hoveringBorder?.axis == .column && hoveringBorder?.index == col {
                                hoveringBorder = nil
                            }
                        },
                        onDragStart: {
                            draggingBorder = DraggingBorderInfo(
                                axis: .column,
                                index: col,
                                initialPosition: position,
                                initialSize: document.colWidths[col] ?? TableDocument.minColumnWidth,
                                currentDelta: 0
                            )
                        },
                        onDragChange: { delta in
                            draggingBorder?.currentDelta = delta
                        },
                        onDragEnd: {
                            if let border = draggingBorder {
                                document.resizeColumn(index: border.index, width: border.initialSize + border.currentDelta)
                            }
                            draggingBorder = nil
                        }
                    )
                }
                
                // Row resize zones
                ForEach(0..<document.rowCount, id: \.self) { row in
                    let position = rowPositions[row + 1]
                    
                    ResizeZone(
                        orientation: .horizontal,
                        position: position,
                        length: geo.size.width,
                        onHoverChange: { isHovering in
                            if isHovering {
                                hoveringBorder = HoveringBorderInfo(axis: .row, index: row)
                            } else if hoveringBorder?.axis == .row && hoveringBorder?.index == row {
                                hoveringBorder = nil
                            }
                        },
                        onDragStart: {
                            draggingBorder = DraggingBorderInfo(
                                axis: .row,
                                index: row,
                                initialPosition: position,
                                initialSize: document.rowHeights[row] ?? TableDocument.minRowHeight,
                                currentDelta: 0
                            )
                        },
                        onDragChange: { delta in
                            draggingBorder?.currentDelta = delta
                        },
                        onDragEnd: {
                            if let border = draggingBorder {
                                document.resizeRow(index: border.index, height: border.initialSize + border.currentDelta)
                            }
                            draggingBorder = nil
                        }
                    )
                }
                
                // Layer 3: Refined ghost line during drag
                if let border = draggingBorder {
                    if border.axis == .column {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.6), .blue.opacity(0.8), .blue.opacity(0.6)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 2, height: geo.size.height)
                            .position(x: border.initialPosition + border.currentDelta, y: geo.size.height / 2)
                            .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 0)
                            .allowsHitTesting(false)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.6), .blue.opacity(0.8), .blue.opacity(0.6)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width, height: 2)
                            .position(x: geo.size.width / 2, y: border.initialPosition + border.currentDelta)
                            .shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 0)
                            .allowsHitTesting(false)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
            }
        }
    }
}

/// Invisible resize zone positioned on a border
private struct ResizeZone: View {
    enum Orientation {
        case horizontal, vertical
    }
    
    let orientation: Orientation
    let position: CGFloat
    let length: CGFloat
    let onHoverChange: (Bool) -> Void
    let onDragStart: () -> Void
    let onDragChange: (CGFloat) -> Void
    let onDragEnd: () -> Void
    
    @State private var isHovering = false
    @State private var isDragging = false
    
    var body: some View {
        Group {
            if orientation == .vertical {
                ZStack {
                    // Invisible interaction area
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 2, height: length)
                        .contentShape(Rectangle())
                    
                    // Subtle hover indicator
                    if isHovering || isDragging {
                        Rectangle()
                            .fill(Color.blue.opacity(isDragging ? 0.15 : 0.08))
                            .frame(width: 2, height: length)
                            .animation(.easeInOut(duration: 0.2), value: isHovering)
                            .animation(.easeInOut(duration: 0.1), value: isDragging)
                    }
                }
                .frame(width: 2, height: length)
                .offset(x: position - 1, y: 0)  // Center the 2px width on the border position
                .onHover { hovering in
                    if !isDragging {
                        isHovering = hovering
                        onHoverChange(hovering)
                    }
                }
                .highPriorityGesture(
                    DragGesture()
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                onDragStart()
                            }
                            onDragChange(value.translation.width)
                        }
                        .onEnded { _ in
                            isDragging = false
                            isHovering = false
                            onHoverChange(false)
                            onDragEnd()
                        }
                )
                .pointerStyle(.frameResize(position: .leading))
            } else {
                ZStack {
                    // Invisible interaction area
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: length, height: 2)
                        .contentShape(Rectangle())
                    
                    // Subtle hover indicator
                    if isHovering || isDragging {
                        Rectangle()
                            .fill(Color.blue.opacity(isDragging ? 0.15 : 0.08))
                            .frame(width: length, height: 2)
                            .animation(.easeInOut(duration: 0.2), value: isHovering)
                            .animation(.easeInOut(duration: 0.1), value: isDragging)
                    }
                }
                .frame(width: length, height: 2)
                .offset(x: 0, y: position - 1)  // Center the 2px height on the border position
                .onHover { hovering in
                    if !isDragging {
                        isHovering = hovering
                        onHoverChange(hovering)
                    }
                }
                .highPriorityGesture(
                    DragGesture()
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                onDragStart()
                            }
                            onDragChange(value.translation.height)
                        }
                        .onEnded { _ in
                            isDragging = false
                            isHovering = false
                            onHoverChange(false)
                            onDragEnd()
                        }
                )
                .pointerStyle(.frameResize(position: .top))
            }
        }
    }
}
