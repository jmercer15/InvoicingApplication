import SwiftUI
import CoreGraphics
import Foundation

public struct SectionSplitSelection: Equatable, Hashable {
    public let sectionIndex: Int
    public let path: [Int]
    
    public init(sectionIndex: Int, path: [Int]) {
        self.sectionIndex = sectionIndex
        self.path = path
    }
}
public final class InvoiceDocument: ObservableObject, @unchecked Sendable {
    @Published var components: [InvoiceComponent] = []
    @Published var selectedComponentID: UUID? = nil
    @Published var selectedSplitSelection: SectionSplitSelection? = nil
    @Published var selectedTableElement: TableElementSelection? = nil
    @Published var hoveredSplitSelection: SectionSplitSelection? = nil
    @Published var isSnapping: Bool = false
    @Published var isDragging: Bool = false
    @Published var draggedComponentID: UUID? = nil
    @Published var cursorPosition: CGPoint = .zero 
    @Published var showCursorIndicator = false
    @Published var draggedComponentFrame: CGRect? = nil 
    @Published var pendingScrollTargetID: UUID? = nil
    @Published var isDraggingPaletteComponent: Bool = false
    /// Update the component selection and clear any split/table element selection
    func selectComponent(_ id: UUID?) {
        selectedComponentID = id
        if id != nil {
            selectedSplitSelection = nil
            selectedTableElement = nil
        }
    }
    
    /// Update the table element selection (keeps component context)
    func selectTableElement(_ element: TableElementSelection?, in componentID: UUID) {
        selectedTableElement = element
        if element != nil {
            selectedComponentID = componentID  // Keep component context for inspector
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
    
    /// Clear all selections (components, splits, and table elements)
    func deselectAll() {
        selectedComponentID = nil
        selectedSplitSelection = nil
        selectedTableElement = nil
    }
    
    /// Public initializer for creating new InvoiceDocument instances
    public init() {
        // Default initialization - all @Published properties have default values
    }
    public struct DocumentMargins: Codable, Equatable {
        public var left: CGFloat
        public var right: CGFloat
        public var top: CGFloat
        public var bottom: CGFloat
        
        public init(left: CGFloat, right: CGFloat, top: CGFloat, bottom: CGFloat) {
            self.left = left
            self.right = right
            self.top = top
            self.bottom = bottom
        }
    }
    @Published public var pageSize: CGSize = CGSize(width: 595.2, height: 841.8) 
    @Published public var margins: DocumentMargins = DocumentMargins(left: 36, right: 36, top: 36, bottom: 36)
    @Published public var zoom: CGFloat = 1.0
    @Published public var sectionSplits: [Int: SectionSplit] = [:]
    // Track split configuration for each rectangle section (moved from view state for persistence/undo)
    @Published public var sectionHeightRatios: [CGFloat] = [1.0]

    // System UndoManager integration
    weak var undoManager: UndoManager?
    

    
    enum MarginEdge {
        case left, right, top, bottom
    }
    
    struct DocumentState {
        let components: [InvoiceComponent]
        let sectionSplits: [Int: SectionSplit]
        let margins: DocumentMargins
        let sectionHeightRatios: [CGFloat]
        let selectedComponentID: UUID?
        let selectedSplitSelection: SectionSplitSelection?
        let selectedTableElement: TableElementSelection?
    }
    
    func add(_ component: InvoiceComponent, actionName: String = "Add Component") {
        saveStateForUndo(actionName: actionName)
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
        add(newComponent) // uses default action name
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
    func setSizeAndPosition(for id: UUID, size: CGSize, position: CGPoint, recordUndo: Bool = false, actionName: String? = nil) {
        if recordUndo {
            saveStateForUndo(actionName: actionName ?? "Move/Resize Component")
        }
        updateComponent(id: id) { component in
            component.size = size
            component.position = position
        }
    }

    
    func updateComponentStyle(for id: UUID, actionName: String = "Change Style", transform: (inout ComponentStyle) -> Void) {
        saveStateForUndo(actionName: actionName)
        updateComponent(id: id) { component in
            transform(&component.style)
        }
    }

    func updateStyle(for id: UUID, style: ComponentStyle) {
        for i in 0..<components.count {
            if components[i].id == id {
                components[i].style = style
                break
            }
        }
    }
    
    // MARK: - Column & Row Configurations (Complex Updates)
    
    func updateAxisSize(for id: UUID, axis: ComponentStyle.TableAxis, index: Int, size: CGFloat, actionName: String = "Resize Table Column/Row") {
        saveStateForUndo(actionName: actionName)
        updateComponent(id: id) { component in
            component.style.updateAxisSize(for: axis, at: index, size: size)
        }
    }
    
    func updateAxisIsFlexible(for id: UUID, axis: ComponentStyle.TableAxis, index: Int, isFlexible: Bool, actionName: String = "Change Column/Row Flexibility") {
        saveStateForUndo(actionName: actionName)
        updateComponent(id: id) { component in
            component.style.updateAxisIsFlexible(for: axis, at: index, isFlexible: isFlexible)
        }
    }
    
    func updateAxisAutoSizing(for id: UUID, axis: ComponentStyle.TableAxis, index: Int, isAutoSized: Bool, actionName: String = "Toggle Auto-Sizing") {
        saveStateForUndo(actionName: actionName)
        updateComponent(id: id) { component in
            component.style.updateAxisAutoSizing(for: axis, at: index, isAutoSized: isAutoSized)
        }
    }
    
    func updateAxisAlignment(for id: UUID, axis: ComponentStyle.TableAxis, index: Int, alignment: TextAlignment, actionName: String = "Change Column/Row Alignment") {
        saveStateForUndo(actionName: actionName)
        updateComponent(id: id) { component in
            component.style.updateAxisAlignment(for: axis, at: index, alignment: alignment)
        }
    }
    
    func updateAxisVerticalAlignment(for id: UUID, axis: ComponentStyle.TableAxis, index: Int, verticalAlignment: VerticalAlignment, actionName: String = "Change Vertical Alignment") {
        saveStateForUndo(actionName: actionName)
        updateComponent(id: id) { component in
            component.style.updateAxisVerticalAlignment(for: axis, at: index, verticalAlignment: verticalAlignment)
        }
    }
    
    func updateAxisHeaderAlignment(for id: UUID, axis: ComponentStyle.TableAxis, index: Int, alignment: TextAlignment, actionName: String = "Change Header Alignment") {
        saveStateForUndo(actionName: actionName)
        updateComponent(id: id) { component in
            component.style.updateAxisHeaderAlignment(for: axis, at: index, alignment: alignment)
        }
    }
    
    func updateAxisHeaderVerticalAlignment(for id: UUID, axis: ComponentStyle.TableAxis, index: Int, verticalAlignment: VerticalAlignment, actionName: String = "Change Header Vertical Alignment") {
        saveStateForUndo(actionName: actionName)
        updateComponent(id: id) { component in
            component.style.updateAxisHeaderVerticalAlignment(for: axis, at: index, verticalAlignment: verticalAlignment)
        }
    }
    
    func updateAxisLineLimit(for id: UUID, axis: ComponentStyle.TableAxis, index: Int, lineLimit: Int, actionName: String = "Change Line Limit") {
        saveStateForUndo(actionName: actionName)
        updateComponent(id: id) { component in
            component.style.updateAxisLineLimit(for: axis, at: index, lineLimit: lineLimit)
        }
    }
    
    func initializeAxisConfigurations(for id: UUID, axis: ComponentStyle.TableAxis, count: Int, actionName: String = "Reset Table Layout") {
        saveStateForUndo(actionName: actionName)
        updateComponent(id: id) { component in
            switch axis {
            case .column:
                component.style.initializeColumnConfigurations(for: count)
            case .row:
                component.style.initializeRowConfigurations(for: count)
            }
        }
    }
    func initializeRowConfigurations(for id: UUID, rowCount: Int, actionName: String = "Reset Rows") {
        saveStateForUndo(actionName: actionName)
        updateComponent(id: id) { component in
            component.style.initializeRowConfigurations(for: rowCount)
        }
    }

    // Component management helpers moved to InvoiceDocument+Components.swift


    
    // MARK: - Advanced Typography Updates
    

    


    // Component management operations moved to InvoiceDocument+Components.swift
    @available(*, unavailable, message: "Use InvoiceTemplateEditorViewModel.saveTemplate() instead.")
    func saveAsTemplate(
        name: String,
        description: String = "",
        author: String = "",
        tags: [String] = []
    ) async -> Bool {
        // Note: This method should be called through ViewModel which has access to TemplateManager
        // Keeping for backward compatibility but TemplateManager should be injected at call site
        fatalError("Use InvoiceTemplateEditorViewModel.saveTemplate() instead")
    }
    public func loadTemplate(_ templateData: TemplateData) {
        components.removeAll()
        sectionSplits.removeAll() // Clear existing splits
        selectComponent(nil)
        margins = DocumentMargins(left: 36, right: 36, top: 36, bottom: 36)
        zoom = 1.0
        clearUndoRedoStacks()
        templateData.document.apply(to: self)
    }
    public func createNewDocument() {
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
            saveStateForUndo(actionName: "Change Margin")
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
        actionName: String? = nil,
        mutate: (inout SectionSplit, Int) -> Void
    ) {
        if let actionName = actionName {
            saveStateForUndo(actionName: actionName)
        } else {
             saveStateForUndo(actionName: "Update Split")
        }
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
        actionName: String? = nil,
        mutate: (inout SectionSplit) -> Void
    ) {
        if let actionName = actionName {
            saveStateForUndo(actionName: actionName)
        } else {
             saveStateForUndo(actionName: "Update Split")
        }
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
        updateSplitSelection(selection, actionName: "Change Split Label") { split, childIndex in
            split.setLabel(label, forChild: childIndex)
        }
    }

    func setSplitAlignment(for selection: SectionSplitSelection, alignment: SectionSplit.LeafAlignment) {
        updateSplitSelection(selection, actionName: "Change Split Alignment") { split, childIndex in
            split.setAlignment(alignment, forChild: childIndex)
        }
    }
    
    func setSplitPadding(for selection: SectionSplitSelection, value: CGFloat) {
        updateSplit(at: selection.sectionIndex, path: Array(selection.path.dropLast()), actionName: "Change Split Padding") { split in
            split.setPadding(value)
        }
    }
    
    func setSplitMargin(for selection: SectionSplitSelection, value: CGFloat) {
        updateSplit(at: selection.sectionIndex, path: Array(selection.path.dropLast()), actionName: "Change Split Margin") { split in
            split.setMargin(value)
        }
    }
    
    func setSplitSpacing(for selection: SectionSplitSelection, value: CGFloat) {
        updateSplit(at: selection.sectionIndex, path: Array(selection.path.dropLast()), actionName: "Change Split Spacing") { split in
            split.setChildSpacing(value)
        }
    }
    
    func setChildPadding(for selection: SectionSplitSelection, value: SectionSplit.PaddingInsets) {
        updateSplitSelection(selection, actionName: "Change Padding") { split, childIndex in
            split.setChildPadding(value, forChild: childIndex)
        }
    }
    
    func setUniformChildPadding(for selection: SectionSplitSelection, value: CGFloat) {
        updateSplitSelection(selection, actionName: "Change Padding") { split, childIndex in
            split.setUniformChildPadding(value, forChild: childIndex)
        }
    }

    func setSplitRatio(for selection: SectionSplitSelection, ratio: CGFloat) {
        updateSplitSelection(selection, actionName: "Resize Section") { split, childIndex in
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
        updateSplitSelection(selection, actionName: "Split Section") { split, childIndex in
            if direction == .grid, let rows = gridRows, let columns = gridColumns {
                split.splitChild(at: childIndex, direction: direction, splitCount: splitCount, gridRows: rows, gridColumns: columns)
            } else {
                split.splitChild(at: childIndex, direction: direction, splitCount: splitCount)
            }
        }
    }

    func insertChildInSplit(for selection: SectionSplitSelection, at childIndex: Int) {
        updateSplit(at: selection.sectionIndex, path: Array(selection.path.dropLast()), actionName: "Insert Child") { split in
            split.insertChild(at: childIndex)
        }
    }
    
    func deleteChildFromSplit(for selection: SectionSplitSelection, at childIndex: Int) {
        updateSplit(at: selection.sectionIndex, path: Array(selection.path.dropLast()), actionName: "Delete Child") { split in
            _ = split.deleteChild(at: childIndex)
        }
    }
    
    func insertGridRow(for selection: SectionSplitSelection, at rowIndex: Int) {
        updateSplit(at: selection.sectionIndex, path: Array(selection.path.dropLast()), actionName: "Insert Row") { split in
            split.insertGridRow(at: rowIndex)
        }
    }
    
    func insertGridColumn(for selection: SectionSplitSelection, at columnIndex: Int) {
        updateSplit(at: selection.sectionIndex, path: Array(selection.path.dropLast()), actionName: "Insert Column") { split in
            split.insertGridColumn(at: columnIndex)
        }
    }
    
    func deleteGridRow(for selection: SectionSplitSelection, at rowIndex: Int) {
        updateSplit(at: selection.sectionIndex, path: Array(selection.path.dropLast()), actionName: "Delete Row") { split in
            _ = split.deleteGridRow(at: rowIndex)
        }
    }
    
    func deleteGridColumn(for selection: SectionSplitSelection, at columnIndex: Int) {
        updateSplit(at: selection.sectionIndex, path: Array(selection.path.dropLast()), actionName: "Delete Column") { split in
            _ = split.deleteGridColumn(at: columnIndex)
        }
    }

    func removeSplitContainingSelection(_ selection: SectionSplitSelection) {
        guard selection.path.count >= 2 else { return }
        var parentPath = selection.path
        parentPath.removeLast() // remove leaf index
        guard let parentIndex = parentPath.popLast() else { return }
        updateSplit(at: selection.sectionIndex, path: parentPath, actionName: "Merge Split") { split in
            split.unsplitChild(at: parentIndex)
        }
    }

    func equalizeSplitRatios(for selection: SectionSplitSelection) {
        updateSplitSelection(selection, actionName: "Equalize Sections") { split, _ in
            split.resetRatiosToEvenDistribution()
        }
    }
    
    func setWidthSizingMode(for selection: SectionSplitSelection, mode: SectionSplit.SizingMode) {
        updateSplitSelection(selection, actionName: "Change Width Mode") { split, childIndex in
            split.setWidthSizingMode(mode, forChild: childIndex)
        }
    }
    
    func setHeightSizingMode(for selection: SectionSplitSelection, mode: SectionSplit.SizingMode) {
        updateSplitSelection(selection, actionName: "Change Height Mode") { split, childIndex in
            split.setHeightSizingMode(mode, forChild: childIndex)
        }
    }
    
    func setGridRowSizingMode(for selection: SectionSplitSelection, row: Int, mode: SectionSplit.SizingMode) {
        updateSplit(at: selection.sectionIndex, path: Array(selection.path.dropLast()), actionName: "Change Row Sizing") { split in
            split.setRowSizingMode(mode, forRow: row)
        }
    }
    
    func setGridColumnSizingMode(for selection: SectionSplitSelection, column: Int, mode: SectionSplit.SizingMode) {
        updateSplit(at: selection.sectionIndex, path: Array(selection.path.dropLast()), actionName: "Change Column Sizing") { split in
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
