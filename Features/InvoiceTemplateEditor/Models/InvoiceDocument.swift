import SwiftUI
import CoreGraphics

final class InvoiceDocument: ObservableObject {
    @Published var components: [InvoiceComponent] = []
    @Published var selectedComponentID: UUID? = nil
    @Published var isSnapping: Bool = false
    @Published var isDragging: Bool = false
    @Published var draggedComponentID: UUID? = nil
    @Published var cursorPosition: CGPoint = .zero // now stores SCALED coordinates
    @Published var showCursorIndicator = false
    @Published var draggedComponentFrame: CGRect? = nil // now stores SCALED coordinates

    // Document-level margins (points)
    struct DocumentMargins {
        var left: CGFloat
        var right: CGFloat
        var top: CGFloat
        var bottom: CGFloat
    }

    // Default margins: 0.5 inch (~36 points)
    @Published var margins: DocumentMargins = DocumentMargins(left: 36, right: 36, top: 36, bottom: 36)
    
    // Document zoom (1.0 = 100%)
    @Published var zoom: CGFloat = 1.0
    
    // Undo/Redo support
    private var undoStack: [DocumentState] = []
    private var redoStack: [DocumentState] = []
    private var isUndoRedoOperation = false
    
    // Document state for undo/redo
    struct DocumentState {
        let components: [InvoiceComponent]
    }

    // MARK: - Add
    func add(_ component: InvoiceComponent) {
        saveStateForUndo()
        components.append(component)
    }
    

    
    // MARK: - Get All Components (including children in sections)
    var allComponents: [InvoiceComponent] {
        var all: [InvoiceComponent] = []
        
        func addComponentAndChildren(_ component: InvoiceComponent) {
            all.append(component)
            for child in component.children {
                addComponentAndChildren(child)
            }
        }
        
        for component in components {
            addComponentAndChildren(component)
        }
        
        return all
    }
    
    // MARK: - Get Component by ID (including children in sections)
    func component(_ id: UUID?) -> InvoiceComponent? {
        guard let id else { return nil }
        
        // Check standalone components
        if let component = components.first(where: { $0.id == id }) {
            return component
        }
        
        // Check children in components (sections are now components with children)
        for component in components where component.type.isSection {
            if let child = component.children.first(where: { $0.id == id }) {
                return child
            }
        }
        
        return nil
    }
    
    // MARK: - Get Section by ID (sections are now components with type.isSection == true)
    func section(_ id: UUID?) -> InvoiceComponent? {
        guard let id else { return nil }
        return allComponents.first(where: { $0.id == id && $0.type.isSection })
    }
    
    // MARK: - Get Section containing component
    func sectionContaining(_ componentId: UUID) -> InvoiceComponent? {
        return allComponents.first { component in
            component.type.isSection && component.children.contains { $0.id == componentId }
        }
    }
    
    // MARK: - Position
    func setPosition(for id: UUID, to newPosition: CGPoint) {
        // Update position recursively through the component hierarchy
        func updateComponentPosition(_ component: inout InvoiceComponent) -> Bool {
            if component.id == id {
                component.position = newPosition
                return true
            }
            for i in 0..<component.children.count {
                if updateComponentPosition(&component.children[i]) {
                    return true
                }
            }
            return false
        }
        
        for i in 0..<components.count {
            if updateComponentPosition(&components[i]) {
                break
            }
        }
    }
    

    

    
    // MARK: - Dragging State
    func startDragging(for componentID: UUID) {
        // If a different component is being dragged, deselect the currently selected one
        if selectedComponentID != componentID {
            selectedComponentID = nil
        }
        
        isDragging = true
        draggedComponentID = componentID
    }
    
    func stopDragging() {
        isDragging = false
        isSnapping = false
        draggedComponentID = nil
        showCursorIndicator = false // Hide indicator when drag ends
        draggedComponentFrame = nil
    }
    

    
    func getSnappedPosition(for proposedPosition: CGPoint, size: CGSize, excludeID: UUID? = nil) -> CGPoint {
        let snapDistance: CGFloat = 10 // Distance within which snapping occurs
        var snappedPosition = proposedPosition
        var hasSnapped = false
        
        // Get all components for snapping (sections are now just components)
        let allItems = allComponents.map { component in
            (id: component.id, position: component.position, size: component.size)
        }
        
        let otherItems = allItems.filter { $0.id != excludeID }
        
        for otherItem in otherItems {
            // Snap to horizontal edges (left, center, right)
            let currentLeft = proposedPosition.x - size.width / 2
            let currentRight = proposedPosition.x + size.width / 2
            let currentCenter = proposedPosition.x
            
            let otherLeft = otherItem.position.x - otherItem.size.width / 2
            let otherRight = otherItem.position.x + otherItem.size.width / 2
            let otherCenter = otherItem.position.x
            
            // Snap left edge to left edge
            if abs(currentLeft - otherLeft) < snapDistance {
                snappedPosition.x = otherLeft + size.width / 2
                hasSnapped = true
            }
            // Snap left edge to right edge
            else if abs(currentLeft - otherRight) < snapDistance {
                snappedPosition.x = otherRight + size.width / 2
                hasSnapped = true
            }
            // Snap right edge to left edge
            else if abs(currentRight - otherLeft) < snapDistance {
                snappedPosition.x = otherLeft - size.width / 2
                hasSnapped = true
            }
            // Snap right edge to right edge
            else if abs(currentRight - otherRight) < snapDistance {
                snappedPosition.x = otherRight - size.width / 2
                hasSnapped = true
            }
            // Snap center to center
            else if abs(currentCenter - otherCenter) < snapDistance {
                snappedPosition.x = otherCenter
                hasSnapped = true
            }
            
            // Snap to vertical edges (top, center, bottom)
            let currentTop = proposedPosition.y - size.height / 2
            let currentBottom = proposedPosition.y + size.height / 2
            let currentVCenter = proposedPosition.y
            
            let otherTop = otherItem.position.y - otherItem.size.height / 2
            let otherBottom = otherItem.position.y + otherItem.size.height / 2
            let otherVCenter = otherItem.position.y
            
            // Snap top edge to top edge
            if abs(currentTop - otherTop) < snapDistance {
                snappedPosition.y = otherTop + size.height / 2
                hasSnapped = true
            }
            // Snap top edge to bottom edge
            else if abs(currentTop - otherBottom) < snapDistance {
                snappedPosition.y = otherBottom + size.height / 2
                hasSnapped = true
            }
            // Snap bottom edge to top edge
            else if abs(currentBottom - otherTop) < snapDistance {
                snappedPosition.y = otherTop - size.height / 2
                hasSnapped = true
            }
            // Snap bottom edge to bottom edge
            else if abs(currentBottom - otherBottom) < snapDistance {
                snappedPosition.y = otherBottom - size.height / 2
                hasSnapped = true
            }
            // Snap center to center
            else if abs(currentVCenter - otherVCenter) < snapDistance {
                snappedPosition.y = otherVCenter
                hasSnapped = true
            }
        }
        
        // Snap to A4 page edges and midpoints
        let currentLeft = snappedPosition.x - size.width / 2
        let currentRight = snappedPosition.x + size.width / 2
        let currentTop = snappedPosition.y - size.height / 2
        let currentBottom = snappedPosition.y + size.height / 2
        
        // A4 page boundaries adjusted for document margins
        let pageLeft: CGFloat = margins.left
        let pageRight: CGFloat = A4.width - margins.right
        let pageTop: CGFloat = margins.top
        let pageBottom: CGFloat = A4.height - margins.bottom
        let pageCenterX: CGFloat = (pageLeft + pageRight) / 2
        let pageCenterY: CGFloat = (pageTop + pageBottom) / 2
        
        // Document margin positions (outer page edges)
        let marginLeft: CGFloat = 0
        let marginRight: CGFloat = A4.width
        let marginTop: CGFloat = 0
        let marginBottom: CGFloat = A4.height
        
        // Snap to page horizontal edges and center
        // Component left edge to page left edge
        if abs(currentLeft - pageLeft) < snapDistance {
            snappedPosition.x = pageLeft + size.width / 2
            hasSnapped = true
        }
        // Component right edge to page right edge
        else if abs(currentRight - pageRight) < snapDistance {
            snappedPosition.x = pageRight - size.width / 2
            hasSnapped = true
        }
        // Component left edge to page center
        else if abs(currentLeft - pageCenterX) < snapDistance {
            snappedPosition.x = pageCenterX + size.width / 2
            hasSnapped = true
        }
        // Component right edge to page center
        else if abs(currentRight - pageCenterX) < snapDistance {
            snappedPosition.x = pageCenterX - size.width / 2
            hasSnapped = true
        }
        // Component center to page center
        else if abs(snappedPosition.x - pageCenterX) < snapDistance {
            snappedPosition.x = pageCenterX
            hasSnapped = true
        }
        
        // Snap to document margins (outer page edges)
        // Component left edge to margin left edge
        else if abs(currentLeft - marginLeft) < snapDistance {
            snappedPosition.x = marginLeft + size.width / 2
            hasSnapped = true
        }
        // Component right edge to margin right edge
        else if abs(currentRight - marginRight) < snapDistance {
            snappedPosition.x = marginRight - size.width / 2
            hasSnapped = true
        }
        
        // Snap to page vertical edges and center
        // Component top edge to page top edge
        if abs(currentTop - pageTop) < snapDistance {
            snappedPosition.y = pageTop + size.height / 2
            hasSnapped = true
        }
        // Component bottom edge to page bottom edge
        else if abs(currentBottom - pageBottom) < snapDistance {
            snappedPosition.y = pageBottom - size.height / 2
            hasSnapped = true
        }
        // Component top edge to page center
        else if abs(currentTop - pageCenterY) < snapDistance {
            snappedPosition.y = pageCenterY + size.height / 2
            hasSnapped = true
        }
        // Component bottom edge to page center
        else if abs(currentBottom - pageCenterY) < snapDistance {
            snappedPosition.y = pageCenterY - size.height / 2
            hasSnapped = true
        }
        // Component center to page center
        else if abs(snappedPosition.y - pageCenterY) < snapDistance {
            snappedPosition.y = pageCenterY
            hasSnapped = true
        }
        
        // Snap component center to page edge midpoints
        // Horizontal midpoint of top edge
        else if abs(snappedPosition.x - pageCenterX) < snapDistance && abs(currentTop - pageTop) < snapDistance {
            snappedPosition.x = pageCenterX
            snappedPosition.y = pageTop + size.height / 2
            hasSnapped = true
        }
        // Horizontal midpoint of bottom edge
        else if abs(snappedPosition.x - pageCenterX) < snapDistance && abs(currentBottom - pageBottom) < snapDistance {
            snappedPosition.x = pageCenterX
            snappedPosition.y = pageBottom - size.height / 2
            hasSnapped = true
        }
        // Vertical midpoint of left edge
        else if abs(currentLeft - pageLeft) < snapDistance && abs(snappedPosition.y - pageCenterY) < snapDistance {
            snappedPosition.x = pageLeft + size.width / 2
            snappedPosition.y = pageCenterY
            hasSnapped = true
        }
        // Vertical midpoint of right edge
        else if abs(currentRight - pageRight) < snapDistance && abs(snappedPosition.y - pageCenterY) < snapDistance {
            snappedPosition.x = pageRight - size.width / 2
            snappedPosition.y = pageCenterY
            hasSnapped = true
        }
        
        // Component top edge to margin top edge
        else if abs(currentTop - marginTop) < snapDistance {
            snappedPosition.y = marginTop + size.height / 2
            hasSnapped = true
        }
        // Component bottom edge to margin bottom edge
        else if abs(currentBottom - marginBottom) < snapDistance {
            snappedPosition.y = marginBottom - size.height / 2
            hasSnapped = true
        }
        
        // Update snapping state for visual feedback
        DispatchQueue.main.async {
            self.isSnapping = hasSnapped
        }
        
        return snappedPosition
    }

    // MARK: - Size
    func setSize(for id: UUID, to newSize: CGSize) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.size = newSize
        }
    }
    
    // MARK: - Snapped Resize
    func getSnappedSizeAndPosition(for id: UUID, proposedSize: CGSize, proposedPosition: CGPoint) -> (size: CGSize, position: CGPoint) {
        guard component(id) != nil else { return (proposedSize, proposedPosition) }
        
        let snapDistance: CGFloat = 10 // Distance within which snapping occurs
        var snappedSize = proposedSize
        var snappedPosition = proposedPosition
        var hasSnapped = false
        
        // Calculate component edges based on proposed size and position
        let componentLeft = proposedPosition.x - proposedSize.width / 2
        let componentRight = proposedPosition.x + proposedSize.width / 2
        let componentTop = proposedPosition.y - proposedSize.height / 2
        let componentBottom = proposedPosition.y + proposedSize.height / 2
        
        // Get all other components for snapping
        let otherComponents = allComponents.filter { $0.id != id }
        
        // Try to snap to other components
        for otherComponent in otherComponents {
            let otherLeft = otherComponent.position.x - otherComponent.size.width / 2
            let otherRight = otherComponent.position.x + otherComponent.size.width / 2
            let otherTop = otherComponent.position.y - otherComponent.size.height / 2
            let otherBottom = otherComponent.position.y + otherComponent.size.height / 2
            
            // Snap width to other component widths
            if abs(proposedSize.width - otherComponent.size.width) < snapDistance {
                snappedSize.width = otherComponent.size.width
                hasSnapped = true
            }
            
            // Snap height to other component heights
            if abs(proposedSize.height - otherComponent.size.height) < snapDistance {
                snappedSize.height = otherComponent.size.height
                hasSnapped = true
            }
            
            // Snap right edge to other component edges
            if abs(componentRight - otherLeft) < snapDistance {
                let newWidth = otherLeft - componentLeft
                if newWidth > 50 && newWidth < 800 {
                    snappedSize.width = newWidth
                    snappedPosition.x = componentLeft + newWidth / 2
                    hasSnapped = true
                }
            }
            if abs(componentRight - otherRight) < snapDistance {
                let newWidth = otherRight - componentLeft
                if newWidth > 50 && newWidth < 800 {
                    snappedSize.width = newWidth
                    snappedPosition.x = componentLeft + newWidth / 2
                    hasSnapped = true
                }
            }
            
            // Snap left edge to other component edges
            if abs(componentLeft - otherLeft) < snapDistance {
                let newWidth = componentRight - otherLeft
                if newWidth > 50 && newWidth < 800 {
                    snappedSize.width = newWidth
                    snappedPosition.x = otherLeft + newWidth / 2
                    hasSnapped = true
                }
            }
            if abs(componentLeft - otherRight) < snapDistance {
                let newWidth = componentRight - otherRight
                if newWidth > 50 && newWidth < 800 {
                    snappedSize.width = newWidth
                    snappedPosition.x = otherRight + newWidth / 2
                    hasSnapped = true
                }
            }
            
            // Snap bottom edge to other component edges
            if abs(componentBottom - otherTop) < snapDistance {
                let newHeight = otherTop - componentTop
                if newHeight > 30 && newHeight < 600 {
                    snappedSize.height = newHeight
                    snappedPosition.y = componentTop + newHeight / 2
                    hasSnapped = true
                }
            }
            if abs(componentBottom - otherBottom) < snapDistance {
                let newHeight = otherBottom - componentTop
                if newHeight > 30 && newHeight < 600 {
                    snappedSize.height = newHeight
                    snappedPosition.y = componentTop + newHeight / 2
                    hasSnapped = true
                }
            }
            
            // Snap top edge to other component edges
            if abs(componentTop - otherTop) < snapDistance {
                let newHeight = componentBottom - otherTop
                if newHeight > 30 && newHeight < 600 {
                    snappedSize.height = newHeight
                    snappedPosition.y = otherTop + newHeight / 2
                    hasSnapped = true
                }
            }
            if abs(componentTop - otherBottom) < snapDistance {
                let newHeight = componentBottom - otherBottom
                if newHeight > 30 && newHeight < 600 {
                    snappedSize.height = newHeight
                    snappedPosition.y = otherBottom + newHeight / 2
                    hasSnapped = true
                }
            }
        }
        
        // Snap to page boundaries, midpoints, and margins
        let pageLeft: CGFloat = margins.left
        let pageRight: CGFloat = A4.width - margins.right
        let pageTop: CGFloat = margins.top
        let pageBottom: CGFloat = A4.height - margins.bottom
        let pageCenterX: CGFloat = (pageLeft + pageRight) / 2
        let pageCenterY: CGFloat = (pageTop + pageBottom) / 2
        
        // Margin positions (for snapping to margin edges)
        let marginLeft: CGFloat = 0
        let marginRight: CGFloat = A4.width
        let marginTop: CGFloat = 0
        let marginBottom: CGFloat = A4.height
        
        // Recalculate edges with snapped size
        let newComponentLeft = snappedPosition.x - snappedSize.width / 2
        let newComponentRight = snappedPosition.x + snappedSize.width / 2
        let newComponentTop = snappedPosition.y - snappedSize.height / 2
        let newComponentBottom = snappedPosition.y + snappedSize.height / 2
        let newComponentCenterX = snappedPosition.x
        let newComponentCenterY = snappedPosition.y
        
        // Snap to page width
        if abs(snappedSize.width - (pageRight - pageLeft)) < snapDistance {
            snappedSize.width = pageRight - pageLeft
            snappedPosition.x = pageLeft + snappedSize.width / 2
            hasSnapped = true
        }
        
        // Snap to page height
        if abs(snappedSize.height - (pageBottom - pageTop)) < snapDistance {
            snappedSize.height = pageBottom - pageTop
            snappedPosition.y = pageTop + snappedSize.height / 2
            hasSnapped = true
        }
        
        // Snap component center to page center (horizontal)
        if abs(newComponentCenterX - pageCenterX) < snapDistance {
            snappedPosition.x = pageCenterX
            hasSnapped = true
        }
        
        // Snap component center to page center (vertical)
        if abs(newComponentCenterY - pageCenterY) < snapDistance {
            snappedPosition.y = pageCenterY
            hasSnapped = true
        }
        
        // Snap component center to page edge midpoints
        // Horizontal midpoint of top edge
        let topEdgeMidpointX = pageCenterX
        let topEdgeMidpointY = pageTop
        if abs(newComponentCenterX - topEdgeMidpointX) < snapDistance {
            snappedPosition.x = topEdgeMidpointX
            hasSnapped = true
        }
        if abs(newComponentCenterY - topEdgeMidpointY) < snapDistance {
            snappedPosition.y = topEdgeMidpointY
            hasSnapped = true
        }
        
        // Horizontal midpoint of bottom edge
        let bottomEdgeMidpointX = pageCenterX
        let bottomEdgeMidpointY = pageBottom
        if abs(newComponentCenterX - bottomEdgeMidpointX) < snapDistance {
            snappedPosition.x = bottomEdgeMidpointX
            hasSnapped = true
        }
        if abs(newComponentCenterY - bottomEdgeMidpointY) < snapDistance {
            snappedPosition.y = bottomEdgeMidpointY
            hasSnapped = true
        }
        
        // Vertical midpoint of left edge
        let leftEdgeMidpointX = pageLeft
        let leftEdgeMidpointY = pageCenterY
        if abs(newComponentCenterX - leftEdgeMidpointX) < snapDistance {
            snappedPosition.x = leftEdgeMidpointX
            hasSnapped = true
        }
        if abs(newComponentCenterY - leftEdgeMidpointY) < snapDistance {
            snappedPosition.y = leftEdgeMidpointY
            hasSnapped = true
        }
        
        // Vertical midpoint of right edge
        let rightEdgeMidpointX = pageRight
        let rightEdgeMidpointY = pageCenterY
        if abs(newComponentCenterX - rightEdgeMidpointX) < snapDistance {
            snappedPosition.x = rightEdgeMidpointX
            hasSnapped = true
        }
        if abs(newComponentCenterY - rightEdgeMidpointY) < snapDistance {
            snappedPosition.y = rightEdgeMidpointY
            hasSnapped = true
        }
        
        // Snap edges to page boundaries
        if abs(newComponentLeft - pageLeft) < snapDistance {
            let newWidth = newComponentRight - pageLeft
            if newWidth > 50 && newWidth < 800 {
                snappedSize.width = newWidth
                snappedPosition.x = pageLeft + newWidth / 2
                hasSnapped = true
            }
        }
        if abs(newComponentRight - pageRight) < snapDistance {
            let newWidth = pageRight - newComponentLeft
            if newWidth > 50 && newWidth < 800 {
                snappedSize.width = newWidth
                snappedPosition.x = newComponentLeft + newWidth / 2
                hasSnapped = true
            }
        }
        if abs(newComponentTop - pageTop) < snapDistance {
            let newHeight = newComponentBottom - pageTop
            if newHeight > 30 && newHeight < 600 {
                snappedSize.height = newHeight
                snappedPosition.y = pageTop + newHeight / 2
                hasSnapped = true
            }
        }
        if abs(newComponentBottom - pageBottom) < snapDistance {
            let newHeight = pageBottom - newComponentTop
            if newHeight > 30 && newHeight < 600 {
                snappedSize.height = newHeight
                snappedPosition.y = newComponentTop + newHeight / 2
                hasSnapped = true
            }
        }
        
        // Snap edges to document margins (outer page edges)
        if abs(newComponentLeft - marginLeft) < snapDistance {
            let newWidth = newComponentRight - marginLeft
            if newWidth > 50 && newWidth < 800 {
                snappedSize.width = newWidth
                snappedPosition.x = marginLeft + newWidth / 2
                hasSnapped = true
            }
        }
        if abs(newComponentRight - marginRight) < snapDistance {
            let newWidth = marginRight - newComponentLeft
            if newWidth > 50 && newWidth < 800 {
                snappedSize.width = newWidth
                snappedPosition.x = newComponentLeft + newWidth / 2
                hasSnapped = true
            }
        }
        if abs(newComponentTop - marginTop) < snapDistance {
            let newHeight = newComponentBottom - marginTop
            if newHeight > 30 && newHeight < 600 {
                snappedSize.height = newHeight
                snappedPosition.y = marginTop + newHeight / 2
                hasSnapped = true
            }
        }
        if abs(newComponentBottom - marginBottom) < snapDistance {
            let newHeight = marginBottom - newComponentTop
            if newHeight > 30 && newHeight < 600 {
                snappedSize.height = newHeight
                snappedPosition.y = newComponentTop + newHeight / 2
                hasSnapped = true
            }
        }
        
        // Update snapping state for visual feedback
        DispatchQueue.main.async {
            self.isSnapping = hasSnapped
        }
        
        return (snappedSize, snappedPosition)
    }
    
    func setSizeAndPosition(for id: UUID, size: CGSize, position: CGPoint) {
        guard let idx = components.firstIndex(where: { $0.id == id }) else { return }
        components[idx].size = size
        components[idx].position = position
    }
    
    // MARK: - Resize State
    func setResizing(for id: UUID, isResizing: Bool) {
        guard let idx = components.firstIndex(where: { $0.id == id }) else { return }
        components[idx].isResizing = isResizing
    }
    
    // MARK: - Style Updates
    func updateStyle(for id: UUID, style: ComponentStyle) {
        // Update style recursively through the component hierarchy
        func updateComponentStyle(_ component: inout InvoiceComponent) -> Bool {
            if component.id == id {
                component.style = style
                return true
            }
            for i in 0..<component.children.count {
                if updateComponentStyle(&component.children[i]) {
                    return true
                }
            }
            return false
        }
        
        for i in 0..<components.count {
            if updateComponentStyle(&components[i]) {
                break
            }
        }
    }
    
    func updateFontSize(for id: UUID, fontSize: CGFloat) {
        updateComponent(id: id) { component in
            component.style.fontSize = fontSize
        }
    }
    
    func updateTextColor(for id: UUID, color: String) {
        updateComponent(id: id) { component in
            component.style.textColor = color
        }
    }
    
    func updateBackgroundColor(for id: UUID, color: String) {
        updateComponent(id: id) { component in
            component.style.backgroundColor = color
        }
    }
    
    func updateTextAlignment(for id: UUID, alignment: TextAlignment) {
        updateComponent(id: id) { component in
            component.style.textAlignment = alignment
        }
    }
    
    func updateFontWeight(for id: UUID, weight: String) {
        updateComponent(id: id) { component in
            component.style.fontWeight = weight
        }
    }
    
    // Generic update method that works recursively for child components
    private func updateComponent(id: UUID, update: (inout InvoiceComponent) -> Void) {
        func updateComponentRecursively(_ component: inout InvoiceComponent) -> Bool {
            if component.id == id {
                update(&component)
                return true
            }
            for i in 0..<component.children.count {
                if updateComponentRecursively(&component.children[i]) {
                    return true
                }
            }
            return false
        }
        
        for i in 0..<components.count {
            if updateComponentRecursively(&components[i]) {
                break
            }
        }
    }
    
    func updateBorderWidth(for id: UUID, width: CGFloat) {
        updateComponent(id: id) { component in
            component.style.borderWidth = width
        }
    }
    
    func updateBorderColor(for id: UUID, color: String) {
        updateComponent(id: id) { component in
            component.style.borderColor = color
        }
    }
    
    func updateCornerRadius(for id: UUID, radius: CGFloat) {
        updateComponent(id: id) { component in
            component.style.cornerRadius = radius
        }
    }
    
    // MARK: - Enhanced Style Updates
    
    func updateFontFamily(for id: UUID, family: String) {
        updateComponent(id: id) { component in
            component.style.fontFamily = family
        }
    }
    
    func updateLineSpacing(for id: UUID, spacing: CGFloat) {
        updateComponent(id: id) { component in
            component.style.lineSpacing = spacing
        }
    }
    
    func updateLetterSpacing(for id: UUID, spacing: CGFloat) {
        updateComponent(id: id) { component in
            component.style.letterSpacing = spacing
        }
    }
    
    func updateBackgroundOpacity(for id: UUID, opacity: CGFloat) {
        updateComponent(id: id) { component in
            component.style.backgroundOpacity = opacity
        }
    }
    
    func updateBorderStyle(for id: UUID, style: BorderStyle) {
        updateComponent(id: id) { component in
            component.style.borderStyle = style
        }
    }
    
    // MARK: - Text Updates
    func updateText(for id: UUID, text: String) {
        updateComponent(id: id) { component in
            component.style.placeholderText = text
        }
    }
    
    // MARK: - Title Updates (for child components)
    func updateTitle(for id: UUID, title: String?) {
        updateComponent(id: id) { component in
            component.title = title
        }
    }
    
    // MARK: - Layout Updates
    func updatePadding(for id: UUID, padding: CGFloat) {
        updateComponent(id: id) { component in
            component.style.padding = padding
        }
    }
    
    func updateMargin(for id: UUID, margin: CGFloat) {
        updateComponent(id: id) { component in
            component.style.margin = margin
        }
    }
    
    func updateShadowEnabled(for id: UUID, enabled: Bool) {
        updateComponent(id: id) { component in
            component.style.shadowEnabled = enabled
        }
    }
    
    func updateShadowColor(for id: UUID, color: String) {
        updateComponent(id: id) { component in
            component.style.shadowColor = color
        }
    }
    
    func updateShadowOpacity(for id: UUID, opacity: CGFloat) {
        updateComponent(id: id) { component in
            component.style.shadowOpacity = opacity
        }
    }
    
    func updateShadowRadius(for id: UUID, radius: CGFloat) {
        updateComponent(id: id) { component in
            component.style.shadowRadius = radius
        }
    }
    
    func updateShadowOffset(for id: UUID, x: CGFloat, y: CGFloat) {
        updateComponent(id: id) { component in
            component.style.shadowOffsetX = x
            component.style.shadowOffsetY = y
        }
    }
    
    func updatePlaceholderText(for id: UUID, text: String) {
        updateComponent(id: id) { component in
            component.style.placeholderText = text
        }
    }

    func updateStarPoints(for id: UUID, points: Int) {
        updateComponent(id: id) { component in
            component.style.starPoints = points
        }
    }

    func updateStarSmoothness(for id: UUID, smoothness: CGFloat) {
        updateComponent(id: id) { component in
            component.style.starSmoothness = smoothness
        }
    }

    func updateTriangleDirection(for id: UUID, direction: TriangleDirection) {
        updateComponent(id: id) { component in
            component.style.triangleDirection = direction
        }
    }

    func updateLineThickness(for id: UUID, thickness: CGFloat) {
        updateComponent(id: id) { component in
            component.style.lineThickness = thickness
        }
    }

    func updateLineStartDecorator(for id: UUID, decorator: LineDecorator) {
        updateComponent(id: id) { component in
            component.style.lineStartDecorator = decorator
        }
    }

    func updateLineEndDecorator(for id: UUID, decorator: LineDecorator) {
        updateComponent(id: id) { component in
            component.style.lineEndDecorator = decorator
        }
    }

    func updateImageData(for id: UUID, data: Data?) {
        updateComponent(id: id) { component in
            component.style.imageData = data
        }
    }

    func updateImageContentMode(for id: UUID, mode: ImageContentMode) {
        updateComponent(id: id) { component in
            component.style.imageContentMode = mode
        }
    }
    
    // MARK: - Table Style Updates
    
    func updateTableHeaderColor(for id: UUID, color: String) {
        updateComponent(id: id) { component in
            component.style.tableHeaderColor = color
        }
    }
    
    func updateTableRowColor(for id: UUID, color: String) {
        updateComponent(id: id) { component in
            component.style.tableRowColor = color
        }
    }
    
    func updateTableRowAltColor(for id: UUID, color: String) {
        updateComponent(id: id) { component in
            component.style.tableRowAltColor = color
        }
    }
    
    func updateTableTextColor(for id: UUID, color: String) {
        updateComponent(id: id) { component in
            component.style.tableTextColor = color
        }
    }
    
    func updateShowTableHeader(for id: UUID, show: Bool) {
        updateComponent(id: id) { component in
            component.style.showTableHeader = show
        }
    }
    
    func updateUseAlternatingRows(for id: UUID, use: Bool) {
        updateComponent(id: id) { component in
            component.style.useAlternatingRows = use
        }
    }
    
    // MARK: - Section Layout Updates
    
    func updateSectionLayout(for id: UUID, layout: SectionLayout) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.sectionLayout = layout
        }
    }
    
    func updateGridColumns(for id: UUID, columns: Int) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.gridColumns = columns
        }
    }
    
    func updateContentSpacing(for id: UUID, spacing: CGFloat) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.contentSpacing = spacing
        }
    }
    
    func updateContentPadding(for id: UUID, padding: CGFloat) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.contentPadding = padding
        }
    }
    
    // MARK: - Reset to Defaults
    func resetComponentToDefaults(for id: UUID) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            // Reset to default style values
            component.style = ComponentStyle()
            
            // Reset position and size to defaults for the component type
            let defaultSize = component.type.defaultSize
            component.size = defaultSize
            
            // Reset position to center of page (using A4 dimensions)
            component.position = CGPoint(x: 595 / 2, y: 842 / 2)
            
            // Reset title to default
            component.title = nil
            
            // Reset children if it's a section
            if component.type.isSection {
                component.children = InvoiceComponent.defaultChildren(for: component.type, parentId: component.id)
            }
        }
    }
    
    func copyComponent(_ id: UUID) {
        guard let originalComponent = component(id) else { return }
        
        // Create a copy with a new ID and slightly offset position
        var copiedComponent = originalComponent
        copiedComponent.id = UUID()
        copiedComponent.position = CGPoint(
            x: originalComponent.position.x + 20,
            y: originalComponent.position.y + 20
        )
        
        // Add the copy to the document
        components.append(copiedComponent)
        
        // Select the new component
        selectedComponentID = copiedComponent.id
    }
    


    // MARK: - Remove
    func removeComponent(with id: UUID) {
        saveStateForUndo()
        components.removeAll { $0.id == id }
        if selectedComponentID == id {
            selectedComponentID = nil
        }
    }
    
    func removeSection(with id: UUID) {
        // Remove from components array (sections are now just components)
        func removeComponent(_ component: inout [InvoiceComponent]) -> Bool {
            if let index = component.firstIndex(where: { $0.id == id }) {
                component.remove(at: index)
                return true
            }
            for i in 0..<component.count {
                if removeComponent(&component[i].children) {
                    return true
                }
            }
            return false
        }
        
        if removeComponent(&components) {
            if selectedComponentID == id {
                selectedComponentID = nil
            }
        }
    }
    
    // MARK: - Template Save/Load
    
    func saveAsTemplate(
        name: String,
        description: String = "",
        author: String = "",
        tags: [String] = []
    ) async -> Bool {
        // Generate thumbnail on main actor
        let thumbnailData = await MainActor.run {
            TemplateManager.shared.generateThumbnail(from: self)
        }
        
        // Save template
        return await TemplateManager.shared.saveTemplate(
            document: self,
            name: name,
            description: description,
            author: author,
            tags: tags,
            thumbnailData: thumbnailData
        )
    }
    
    func loadTemplate(_ templateData: TemplateData) {
        // Clear current document
        components.removeAll()
        selectedComponentID = nil
        margins = DocumentMargins(left: 36, right: 36, top: 36, bottom: 36)
        zoom = 1.0
        clearUndoRedoStacks()
        
        // Apply template data
        templateData.document.apply(to: self)
    }
    
    func createNewDocument() {
        // Clear current document and reset to defaults
        components.removeAll()
        selectedComponentID = nil
        margins = DocumentMargins(left: 36, right: 36, top: 36, bottom: 36)
        zoom = 1.0
        clearUndoRedoStacks()
    }
    
    // MARK: - Undo/Redo
    
    var canUndo: Bool {
        return !undoStack.isEmpty
    }
    
    var canRedo: Bool {
        return !redoStack.isEmpty
    }
    
    func undo() {
        guard canUndo else { return }
        
        isUndoRedoOperation = true
        
        // Save current state to redo stack
        redoStack.append(DocumentState(components: components))
        
        // Restore previous state
        let previousState = undoStack.removeLast()
        components = previousState.components
        
        isUndoRedoOperation = false
    }
    
    func redo() {
        guard canRedo else { return }
        
        isUndoRedoOperation = true
        
        // Save current state to undo stack
        undoStack.append(DocumentState(components: components))
        
        // Restore next state
        let nextState = redoStack.removeLast()
        components = nextState.components
        
        isUndoRedoOperation = false
    }
    
    private func saveStateForUndo() {
        guard !isUndoRedoOperation else { return }
        
        // Save current state to undo stack
        undoStack.append(DocumentState(components: components))
        
        // Clear redo stack when new action is performed
        redoStack.removeAll()
        
        // Limit undo stack size to prevent memory issues
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }
    
    private func clearUndoRedoStacks() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
