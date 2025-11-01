import SwiftUI
import CoreGraphics
import Foundation
final class InvoiceDocument: ObservableObject, @unchecked Sendable {
    @Published var components: [InvoiceComponent] = []
    @Published var selectedComponentID: UUID? = nil
    @Published var isSnapping: Bool = false
    @Published var isDragging: Bool = false
    @Published var draggedComponentID: UUID? = nil
    @Published var cursorPosition: CGPoint = .zero 
    @Published var showCursorIndicator = false
    @Published var draggedComponentFrame: CGRect? = nil 
    @Published var pendingScrollTargetID: UUID? = nil
    struct DocumentMargins: Codable, Equatable {
        var left: CGFloat
        var right: CGFloat
        var top: CGFloat
        var bottom: CGFloat
    }
    @Published var pageSize: CGSize = CGSize(width: 595.2, height: 841.8) 
    @Published var margins: DocumentMargins = DocumentMargins(left: 36, right: 36, top: 36, bottom: 36)
    @Published var zoom: CGFloat = 1.0
    @Published var sectionSplits: [Int: SectionSplit] = [:]
    var undoStack: [DocumentState] = []
    var redoStack: [DocumentState] = []
    var isUndoRedoOperation = false
    enum MarginEdge {
        case left, right, top, bottom
    }
    struct DocumentState {
        let components: [InvoiceComponent]
    }
    func add(_ component: InvoiceComponent) {
        saveStateForUndo()
        components.append(component)
        selectedComponentID = component.id
    }
    func component(_ id: UUID?) -> InvoiceComponent? {
        guard let id else { return nil }
        
        // First try the document's components (legacy system)
        if let component = components.first(where: { $0.id == id }) {
            return component
        }
        
        // Then try the split system
        let splits = Array(sectionSplits.values)
        for split in splits {
            let allComponents = split.getAllComponents()
            if let component = allComponents.first(where: { $0.id == id }) {
                return component
            }
        }
        
        return nil
    }
    
    // Get all components from both systems
    func getAllComponents() -> [InvoiceComponent] {
        var allComponents = components
        
        // Add components from split system
        for split in sectionSplits.values {
            allComponents.append(contentsOf: split.getAllComponents())
        }
        
        return allComponents
    }
    func add(_ component: InvoiceComponent, at location: CGPoint) {
        var newComponent = component
        newComponent.position = location
        add(newComponent)
    }
    func setPosition(for id: UUID, to newPosition: CGPoint) {
        guard let component = component(id) else { return }
        setSizeAndPosition(for: id, size: component.size, position: newPosition, recordUndo: false)
    }
    func startDragging(for componentID: UUID) {
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
        showCursorIndicator = false 
        draggedComponentFrame = nil
    }
    // Snapping functionality moved to InvoiceDocument+Snapping.swift
    func setSize(for id: UUID, to newSize: CGSize) {
        guard let component = component(id) else { return }
        setSizeAndPosition(for: id, size: newSize, position: component.position, recordUndo: true)
    }
    func setSizeAndPosition(for id: UUID, size: CGSize, position: CGPoint, recordUndo: Bool = false) {
        guard let idx = components.firstIndex(where: { $0.id == id }) else { return }
        if recordUndo {
            saveStateForUndo()
        }
        components[idx].size = size
        components[idx].position = position
    }
    func setResizing(for id: UUID, isResizing: Bool) {
        guard let idx = components.firstIndex(where: { $0.id == id }) else { return }
        components[idx].isResizing = isResizing
    }
    func updateStyle(for id: UUID, style: ComponentStyle) {
        for i in 0..<components.count {
            if components[i].id == id {
                components[i].style = style
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
    // Component management helpers moved to InvoiceDocument+Components.swift
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
    func updateText(for id: UUID, text: String) {
        updateComponent(id: id) { component in
            component.style.placeholderText = text
        }
    }
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
    func updateImageOpacity(for id: UUID, opacity: CGFloat) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.imageOpacity = opacity
        }
    }
    func updateLineStyle(for id: UUID, style: LineStyle) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.lineStyle = style
        }
    }
    func updateStarInnerRatio(for id: UUID, ratio: CGFloat) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.starInnerRatio = ratio
        }
    }
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
    func updateTableDirection(for id: UUID, direction: TableDirection) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.tableDirection = direction
        }
    }
    func updateTableBorderWidth(for id: UUID, width: CGFloat) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.tableBorderWidth = width
        }
    }
    func updateTableBorderColor(for id: UUID, color: String) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.tableBorderColor = color
        }
    }
    func updateTableHeaderBorderWidth(for id: UUID, width: CGFloat) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.tableHeaderBorderWidth = width
        }
    }
    func updateTableHeaderBorderColor(for id: UUID, color: String) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.tableHeaderBorderColor = color
        }
    }
    func updateTableRowBorderWidth(for id: UUID, width: CGFloat) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.tableRowBorderWidth = width
        }
    }
    func updateTableRowBorderColor(for id: UUID, color: String) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.tableRowBorderColor = color
        }
    }
    func updateTableCellPadding(for id: UUID, padding: CGFloat) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.tableCellPadding = padding
        }
    }
    func updateTableHeaderPadding(for id: UUID, padding: CGFloat) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.tableHeaderPadding = padding
        }
    }
    func updateShowTableBorders(for id: UUID, show: Bool) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.showTableBorders = show
        }
    }
    func updateShowHeaderBorder(for id: UUID, show: Bool) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.showHeaderBorder = show
        }
    }
    func updateShowRowBorders(for id: UUID, show: Bool) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.showRowBorders = show
        }
    }
    func updateShowCellBorders(for id: UUID, show: Bool) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.showCellBorders = show
        }
    }
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
    func updateColumnWidth(for id: UUID, columnIndex: Int, width: CGFloat) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.updateColumnWidth(for: columnIndex, width: width)
        }
    }
    func updateColumnIsFlexible(for id: UUID, columnIndex: Int, isFlexible: Bool) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.updateColumnIsFlexible(for: columnIndex, isFlexible: isFlexible)
        }
    }
    func updateColumnAutoSizing(for id: UUID, columnIndex: Int, isAutoSized: Bool) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.updateColumnAutoSizing(for: columnIndex, isAutoSized: isAutoSized)
        }
    }
    func updateColumnAlignment(for id: UUID, columnIndex: Int, alignment: TextAlignment) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.updateColumnAlignment(for: columnIndex, alignment: alignment)
        }
    }
    func updateColumnVerticalAlignment(for id: UUID, columnIndex: Int, verticalAlignment: VerticalAlignment) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.updateColumnVerticalAlignment(for: columnIndex, verticalAlignment: verticalAlignment)
        }
    }
    func updateColumnHeaderAlignment(for id: UUID, columnIndex: Int, alignment: TextAlignment) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.updateColumnHeaderAlignment(for: columnIndex, alignment: alignment)
        }
    }
    func updateColumnHeaderVerticalAlignment(for id: UUID, columnIndex: Int, verticalAlignment: VerticalAlignment) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.updateColumnHeaderVerticalAlignment(for: columnIndex, verticalAlignment: verticalAlignment)
        }
    }
    func updateColumnLineLimit(for id: UUID, columnIndex: Int, lineLimit: Int) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.updateColumnLineLimit(for: columnIndex, lineLimit: lineLimit)
        }
    }
    func initializeColumnConfigurations(for id: UUID, columnCount: Int) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.initializeColumnConfigurations(for: columnCount)
        }
    }
    func updateRowHeight(for id: UUID, rowIndex: Int, height: CGFloat) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.updateRowHeight(for: rowIndex, height: height)
        }
    }
    func updateRowIsFlexible(for id: UUID, rowIndex: Int, isFlexible: Bool) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.updateRowIsFlexible(for: rowIndex, isFlexible: isFlexible)
        }
    }
    func updateRowAutoSizing(for id: UUID, rowIndex: Int, isAutoSized: Bool) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.updateRowAutoSizing(for: rowIndex, isAutoSized: isAutoSized)
        }
    }
    func updateRowAlignment(for id: UUID, rowIndex: Int, alignment: TextAlignment) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.updateRowAlignment(for: rowIndex, alignment: alignment)
        }
    }
    func updateRowVerticalAlignment(for id: UUID, rowIndex: Int, verticalAlignment: VerticalAlignment) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.updateRowVerticalAlignment(for: rowIndex, verticalAlignment: verticalAlignment)
        }
    }
    func updateRowHeaderAlignment(for id: UUID, rowIndex: Int, alignment: TextAlignment) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.updateRowHeaderAlignment(for: rowIndex, alignment: alignment)
        }
    }
    func updateRowHeaderVerticalAlignment(for id: UUID, rowIndex: Int, verticalAlignment: VerticalAlignment) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.updateRowHeaderVerticalAlignment(for: rowIndex, verticalAlignment: verticalAlignment)
        }
    }
    func updateRowLineLimit(for id: UUID, rowIndex: Int, lineLimit: Int) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.updateRowLineLimit(for: rowIndex, lineLimit: lineLimit)
        }
    }
    func initializeRowConfigurations(for id: UUID, rowCount: Int) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.initializeRowConfigurations(for: rowCount)
        }
    }
    func updateCellPadding(for id: UUID, padding: CGFloat) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.cellPadding = padding
        }
    }
    private func sanitizedHex(_ hex: String) -> String {
        let cleaned = hex.replacingOccurrences(of: "#", with: "").uppercased()
        return cleaned
    }
    func updateTextUnderline(for id: UUID, underline: Bool) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.textUnderline = underline
        }
    }
    func updateTextStrikethrough(for id: UUID, strikethrough: Bool) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.textStrikethrough = strikethrough
        }
    }
    func updateTextTransform(for id: UUID, transform: TextTransform) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.textTransform = transform
        }
    }
    func updateTextOpacity(for id: UUID, opacity: CGFloat) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.textOpacity = opacity
        }
    }
    func updateAspectRatio(for id: UUID, ratio: CGFloat) {
        saveStateForUndo()
        updateComponent(id: id) { component in
            component.style.aspectRatio = ratio
        }
    }
    // Component management operations moved to InvoiceDocument+Components.swift
    func saveAsTemplate(
        name: String,
        description: String = "",
        author: String = "",
        tags: [String] = []
    ) async -> Bool {
        let thumbnailData = await MainActor.run {
            TemplateManager.shared.generateThumbnail(from: self)
        }
        return await TemplateManager.shared.saveTemplate(
            document: self,
            name: name,
            description: description,
            author: author,
            tags: tags,
            thumbnailData: thumbnailData
        ) != nil
    }
    func loadTemplate(_ templateData: TemplateData) {
        components.removeAll()
        selectedComponentID = nil
        margins = DocumentMargins(left: 36, right: 36, top: 36, bottom: 36)
        zoom = 1.0
        clearUndoRedoStacks()
        templateData.document.apply(to: self)
    }
    func createNewDocument() {
        components.removeAll()
        selectedComponentID = nil
        margins = DocumentMargins(left: 36, right: 36, top: 36, bottom: 36)
        zoom = 1.0
        clearUndoRedoStacks()
    }
    // Undo/Redo functionality moved to InvoiceDocument+UndoRedo.swift
    // Component removal moved to InvoiceDocument+Components.swift
    func updateMargin(edge: MarginEdge, to newValue: CGFloat, recordUndo: Bool = true) {
        let pageWidth = pageSize.width
        let pageHeight = pageSize.height
        let minContentWidth: CGFloat = 120
        let minContentHeight: CGFloat = 120
        func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
            guard maxValue >= minValue else { return minValue }
            return min(max(value, minValue), maxValue)
        }
        var updatedMargins = margins
        switch edge {
        case .left:
            let maxLeft = clamp(pageWidth - updatedMargins.right - minContentWidth, min: 0, max: pageWidth)
            updatedMargins.left = clamp(newValue, min: 0, max: maxLeft)
        case .right:
            let maxRight = clamp(pageWidth - updatedMargins.left - minContentWidth, min: 0, max: pageWidth)
            updatedMargins.right = clamp(newValue, min: 0, max: maxRight)
        case .top:
            let maxTop = clamp(pageHeight - updatedMargins.bottom - minContentHeight, min: 0, max: pageHeight)
            updatedMargins.top = clamp(newValue, min: 0, max: maxTop)
        case .bottom:
            let maxBottom = clamp(pageHeight - updatedMargins.top - minContentHeight, min: 0, max: pageHeight)
            updatedMargins.bottom = clamp(newValue, min: 0, max: maxBottom)
        }
        guard updatedMargins != margins else { return }
        if recordUndo {
            saveStateForUndo()
        }
        margins = updatedMargins
    }
    // Component layer operations moved to InvoiceDocument+Components.swift
    func generatePDFData() async throws -> Data {
        return try await ExportService.shared.generatePDFData(from: self)
    }
    func exportToPDF(fileName: String) async throws -> URL {
        return try await ExportService.shared.exportToPDF(document: self, fileName: fileName)
    }
    func exportToImage(format: ExportService.ImageFormat = .png, fileName: String) async throws -> URL {
        return try await ExportService.shared.exportToImage(document: self, format: format, fileName: fileName)
    }
    func printDocument() {
        ExportService.shared.printDocument(document: self)
    }
}


