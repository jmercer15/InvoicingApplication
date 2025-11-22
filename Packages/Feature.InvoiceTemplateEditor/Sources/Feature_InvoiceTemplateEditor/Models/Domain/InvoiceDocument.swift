import SwiftUI
import CoreGraphics
import Foundation

struct SectionSplitSelection: Equatable {
    let sectionIndex: Int
    let path: [Int]
}
final class InvoiceDocument: ObservableObject, @unchecked Sendable {
    @Published var components: [InvoiceComponent] = []
    @Published var selectedComponentID: UUID? = nil
    @Published var selectedSplitSelection: SectionSplitSelection? = nil
    @Published var isSnapping: Bool = false
    @Published var isDragging: Bool = false
    @Published var draggedComponentID: UUID? = nil
    @Published var cursorPosition: CGPoint = .zero 
    @Published var showCursorIndicator = false
    @Published var draggedComponentFrame: CGRect? = nil 
    @Published var pendingScrollTargetID: UUID? = nil
    @Published var isDraggingPaletteComponent: Bool = false
    /// Update the component selection and clear any split selection
    func selectComponent(_ id: UUID?) {
        selectedComponentID = id
        if id != nil {
            selectedSplitSelection = nil
        }
    }

    private func ensureSplitContainer(for sectionIndex: Int) {
        if sectionSplits[sectionIndex] == nil {
            sectionSplits[sectionIndex] = SectionSplit(direction: .horizontal, splitCount: 1)
        }
    }

    /// Update the split selection and clear the component selection
    func selectSplitSelection(_ selection: SectionSplitSelection?) {
        selectedSplitSelection = selection
        if selection != nil {
            selectedComponentID = nil
            if let sectionIndex = selection?.sectionIndex {
                ensureSplitContainer(for: sectionIndex)
            }
        }
    }
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
        selectComponent(component.id)
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
            selectComponent(nil)
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
    func updateTableHeaderTextColor(for id: UUID, color: String) {
        updateComponent(id: id) { component in
            component.style.tableHeaderTextColor = color
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
        // Note: This method should be called through ViewModel which has access to TemplateManager
        // Keeping for backward compatibility but TemplateManager should be injected at call site
        fatalError("saveTemplate should be called through InvoiceTemplateEditorViewModel.saveTemplate() instead")
    }
    func loadTemplate(_ templateData: TemplateData) {
        components.removeAll()
        sectionSplits.removeAll() // Clear existing splits
        selectComponent(nil)
        margins = DocumentMargins(left: 36, right: 36, top: 36, bottom: 36)
        zoom = 1.0
        clearUndoRedoStacks()
        templateData.document.apply(to: self)
    }
    func createNewDocument() {
        components.removeAll()
        selectComponent(nil)
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

    private func updateSplitSelection(
        _ selection: SectionSplitSelection,
        mutate: (inout SectionSplit, Int) -> Void
    ) {
        guard !selection.path.isEmpty else { return }
        ensureSplitContainer(for: selection.sectionIndex)
        guard var rootSplit = sectionSplits[selection.sectionIndex] else { return }

        var didMutate = false

        func applyMutation(_ split: inout SectionSplit, path: ArraySlice<Int>) {
            guard let index = path.first, index < split.children.count else { return }
            if path.count == 1 {
                mutate(&split, index)
                didMutate = true
            } else {
                guard var childSplit = split.children[index] else { return }
                applyMutation(&childSplit, path: path.dropFirst())
                split.children[index] = childSplit
                didMutate = true
            }
        }

        applyMutation(&rootSplit, path: ArraySlice(selection.path))

        if didMutate {
            sectionSplits[selection.sectionIndex] = rootSplit
        }
    }

    private func updateSplit(
        at sectionIndex: Int,
        path: [Int],
        mutate: (inout SectionSplit) -> Void
    ) {
        ensureSplitContainer(for: sectionIndex)
        guard var rootSplit = sectionSplits[sectionIndex] else { return }
        var didMutate = false

        func apply(_ split: inout SectionSplit, path: ArraySlice<Int>) {
            guard let index = path.first else {
                mutate(&split)
                didMutate = true
                return
            }

            guard index < split.children.count, var childSplit = split.children[index] else { return }
            if path.count == 1 {
                mutate(&childSplit)
                split.children[index] = childSplit
                didMutate = true
            } else {
                apply(&childSplit, path: path.dropFirst())
                split.children[index] = childSplit
            }
        }

        apply(&rootSplit, path: ArraySlice(path))

        if didMutate {
            sectionSplits[sectionIndex] = rootSplit
        }
    }

    func setSplitLabel(for selection: SectionSplitSelection, label: String) {
        updateSplitSelection(selection) { split, childIndex in
            split.setLabel(label, forChild: childIndex)
        }
    }

    func setSplitAlignment(for selection: SectionSplitSelection, alignment: SectionSplit.LeafAlignment) {
        updateSplitSelection(selection) { split, childIndex in
            split.setAlignment(alignment, forChild: childIndex)
        }
    }
    
    func setSplitPadding(for selection: SectionSplitSelection, value: CGFloat) {
        updateSplit(at: selection.sectionIndex, path: Array(selection.path.dropLast())) { split in
            split.setPadding(value)
        }
    }
    
    func setSplitMargin(for selection: SectionSplitSelection, value: CGFloat) {
        updateSplit(at: selection.sectionIndex, path: Array(selection.path.dropLast())) { split in
            split.setMargin(value)
        }
    }
    
    func setSplitSpacing(for selection: SectionSplitSelection, value: CGFloat) {
        updateSplit(at: selection.sectionIndex, path: Array(selection.path.dropLast())) { split in
            split.setChildSpacing(value)
        }
    }
    
    func setChildPadding(for selection: SectionSplitSelection, value: SectionSplit.PaddingInsets) {
        updateSplitSelection(selection) { split, childIndex in
            split.setChildPadding(value, forChild: childIndex)
        }
    }

    func setSplitRatio(for selection: SectionSplitSelection, ratio: CGFloat) {
        updateSplitSelection(selection) { split, childIndex in
            split.updateRatio(at: childIndex, newRatio: ratio)
        }
    }

    func splitSelection(
        _ selection: SectionSplitSelection,
        direction: SectionSplit.SplitDirection,
        splitCount: Int,
        gridRows: Int? = nil,
        gridColumns: Int? = nil
    ) {
        updateSplitSelection(selection) { split, childIndex in
            if direction == .grid, let rows = gridRows, let columns = gridColumns {
                split.splitChild(at: childIndex, direction: direction, splitCount: splitCount, gridRows: rows, gridColumns: columns)
            } else {
                split.splitChild(at: childIndex, direction: direction, splitCount: splitCount)
            }
        }
    }

    func removeSplitContainingSelection(_ selection: SectionSplitSelection) {
        guard selection.path.count >= 2 else { return }
        var parentPath = selection.path
        parentPath.removeLast() // remove leaf index
        guard let parentIndex = parentPath.popLast() else { return }
        updateSplit(at: selection.sectionIndex, path: parentPath) { split in
            split.unsplitChild(at: parentIndex)
        }
    }

    func equalizeSplitRatios(for selection: SectionSplitSelection) {
        updateSplitSelection(selection) { split, _ in
            split.resetRatiosToEvenDistribution()
        }
    }
    
    func setWidthSizingMode(for selection: SectionSplitSelection, mode: SectionSplit.SizingMode) {
        updateSplitSelection(selection) { split, childIndex in
            split.setWidthSizingMode(mode, forChild: childIndex)
        }
    }
    
    func setHeightSizingMode(for selection: SectionSplitSelection, mode: SectionSplit.SizingMode) {
        updateSplitSelection(selection) { split, childIndex in
            split.setHeightSizingMode(mode, forChild: childIndex)
        }
    }
    
    func setGridRowSizingMode(for selection: SectionSplitSelection, row: Int, mode: SectionSplit.SizingMode) {
        updateSplit(at: selection.sectionIndex, path: Array(selection.path.dropLast())) { split in
            split.setRowSizingMode(mode, forRow: row)
        }
    }
    
    func setGridColumnSizingMode(for selection: SectionSplitSelection, column: Int, mode: SectionSplit.SizingMode) {
        updateSplit(at: selection.sectionIndex, path: Array(selection.path.dropLast())) { split in
            split.setColumnSizingMode(mode, forColumn: column)
        }
    }
}

struct SectionSplitLeafContext {
    let selection: SectionSplitSelection
    let parentSplit: SectionSplit
    let childIndex: Int
    let childComponents: [InvoiceComponent]

    var label: String {
        parentSplit.getLabel(forChild: childIndex) ?? parentSplit.getDefaultLabel(forChild: childIndex)
    }

    var alignment: SectionSplit.LeafAlignment {
        parentSplit.getAlignment(forChild: childIndex)
    }

    var ratio: CGFloat? {
        guard childIndex < parentSplit.splitRatios.count else { return nil }
        return parentSplit.splitRatios[childIndex]
    }

    var directionName: String {
        parentSplit.direction.displayName
    }

    var directionIcon: String {
        parentSplit.direction.icon
    }

    var pathDescription: String {
        guard !selection.path.isEmpty else { return "Root" }
        let indexes = selection.path.map { "\($0 + 1)" }
        return indexes.joined(separator: " → ")
    }

    var gridPositionDescription: String? {
        guard parentSplit.direction == .grid else { return nil }
        let coordinates = parentSplit.rowColumn(for: childIndex)
        return "Row \(coordinates.row + 1), Column \(coordinates.column + 1)"
    }

    var gridSizeDescription: String? {
        guard parentSplit.direction == .grid else { return nil }
        return "\(parentSplit.gridRows) × \(parentSplit.gridColumns)"
    }

    struct SiblingSummary: Identifiable {
        let id = UUID()
        let index: Int
        let label: String
    }

    var siblingSummaries: [SiblingSummary] {
        let total = parentSplit.children.count
        guard total > 1 else { return [] }
        return (0..<total).map { idx in
            let label = parentSplit.getLabel(forChild: idx) ?? parentSplit.getDefaultLabel(forChild: idx)
            return SiblingSummary(index: idx, label: label)
        }
    }

    var canNavigateToParent: Bool {
        selection.path.count > 1
    }

    var parentPath: [Int] {
        Array(selection.path.dropLast())
    }
}

extension InvoiceDocument {
    private func fallbackRootSplit(for sectionIndex: Int) -> SectionSplit {
        var split = SectionSplit(direction: .horizontal, splitCount: 1)
        split.childLabels[0] = "Section \(sectionIndex + 1)"
        return split
    }
    
    func leafContext(for selection: SectionSplitSelection?) -> SectionSplitLeafContext? {
        guard let selection,
              !selection.path.isEmpty else {
            return nil
        }
        
        var parentSplit = sectionSplits[selection.sectionIndex] ?? fallbackRootSplit(for: selection.sectionIndex)
        var pathToParent = selection.path
        guard let leafIndex = pathToParent.popLast(),
              leafIndex >= 0 else {
            return nil
        }

        for index in pathToParent {
            guard index >= 0, index < parentSplit.children.count,
                  let childSplit = parentSplit.children[index] else {
                return nil
            }
            parentSplit = childSplit
        }

        guard leafIndex < parentSplit.children.count else {
            return nil
        }

        let components = parentSplit.childComponents[leafIndex] ?? []
        return SectionSplitLeafContext(
            selection: selection,
            parentSplit: parentSplit,
            childIndex: leafIndex,
            childComponents: components
        )
    }
}
