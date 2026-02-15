import SwiftUI

struct CellFrameData: Equatable {
    let coordinate: GridCoordinate
    let frame: CGRect
}

struct CellFramePreferenceKey: PreferenceKey {
    static var defaultValue: [CellFrameData] { [] }
    
    static func reduce(value: inout [CellFrameData], nextValue: () -> [CellFrameData]) {
        value.append(contentsOf: nextValue())
    }
}

public struct SmartTable: View {
    @StateObject private var document: TableDocument
    @StateObject private var selectionManager: SelectionManager
    @StateObject private var textEditingContext = TextEditingContext()
    
    @State private var cellFrames: [GridCoordinate: CGRect] = [:]
    @FocusState private var focusedCell: GridCoordinate?
    @State private var selectionAnchor: GridCoordinate?
    @State private var editingCell: GridCoordinate?
    @State private var isDraggingSelection = false
    
    public init(rows: Int, cols: Int) {
        let doc = TableDocument(rowCount: rows, colCount: cols)
        _document = StateObject(wrappedValue: doc)
        _selectionManager = StateObject(wrappedValue: SelectionManager(document: doc))
    }
    
    public var body: some View {
        // Table
        ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    // 1. The Layout
                    TableLayout(
                        cells: document.activeCells,
                        colCount: document.colCount,
                        rowCount: document.rowCount,
                        horizontalSpacing: 0,
                        verticalSpacing: 0,
                        explicitRowHeights: document.rowHeights,
                        explicitColWidths: document.colWidths,
                        rowContentHeights: document.rowContentHeights
                    ) {
                        ForEach(document.activeCells) { (cell: CellModel) in
                            let binding = document.bindingForContent(at: cell.coordinate)
                            CellView(
                                content: binding,
                                cell: cell,
                                isSelected: selectionManager.selectedCells.contains(cell.coordinate),
                                isAlternatingRowColorsEnabled: document.isAlternatingRowColorsEnabled,
                                isHeaderRowEnabled: document.isHeaderRowEnabled,
                                isFirstColumnEnabled: document.isFirstColumnEnabled,
                                focusBinding: $focusedCell,
                                isEditing: editingCell == cell.coordinate,
                                onSelect: {
                                    handleCellTap(cell.coordinate)
                                },
                                onContentHeightChange: { height in
                                    document.updateRowContentHeight(index: cell.coordinate.row, height: height)
                                },
                                onCommit: {
                                    editingCell = nil
                                },
                                onTab: { isShift in
                                    commitAndNavigate(from: cell.coordinate, direction: isShift ? .left : .right)
                                },
                                onEnter: { isShift in
                                    if !isShift {
                                        commitAndNavigate(from: cell.coordinate, direction: .down)
                                    }
                                }
                            )
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(
                                            key: CellFramePreferenceKey.self,
                                            value: [CellFrameData(coordinate: cell.coordinate, frame: geo.frame(in: .named("TableSpace")))]
                                        )
                                }
                            )
                        }
                    }
                    .coordinateSpace(name: "TableSpace")
                    .onPreferenceChange(CellFramePreferenceKey.self) { frames in
                        var newMap: [GridCoordinate: CGRect] = [:]
                        for data in frames {
                            newMap[data.coordinate] = data.frame
                        }
                        self.cellFrames = newMap
                    }
                    
                    // 2. Unified Borders & Resize Handles
                    BordersView(document: document, cellFrames: cellFrames)
                }
                .gesture(
                    DragGesture(minimumDistance: 2, coordinateSpace: .named("TableSpace"))
                        .onChanged { value in
                            handleDrag(value)
                        }
                        .onEnded { _ in
                            handleDragEnd()
                        }
                )
                .background(
                    GridInputResponder { event in
                        handleKeyPress(event)
                    }
                )
        }
        .environmentObject(textEditingContext)
        .toolbar {
            // Table Structure
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button {
                        if let first = selectionManager.selectedCells.first {
                            document.insertRow(at: first.row)
                        }
                    } label: {
                        Label {
                            Text("Insert Row Above")
                        } icon: {
                            Image("fluent-ic_fluent_row_triple_20_regular", bundle: .module)
                                .renderingMode(.template)
                        }
                    }
                    
                    Button {
                        if let first = selectionManager.selectedCells.first {
                            document.insertRow(at: first.row + 1)
                        }
                    } label: {
                        Label {
                            Text("Insert Row Below")
                        } icon: {
                            Image("fluent-ic_fluent_table_bottom_row_20_regular", bundle: .module)
                                .renderingMode(.template)
                        }
                    }
                    
                    Button {
                        if let first = selectionManager.selectedCells.first {
                            document.deleteRow(at: first.row)
                            selectionManager.clearSelection()
                        }
                    } label: {
                        Label {
                            Text("Delete Row")
                        } icon: {
                            Image("fluent-ic_fluent_delete_20_regular", bundle: .module)
                                .renderingMode(.template)
                        }
                    }
                    .disabled(document.rowCount <= 1)
                    
                    Divider()
                    
                    Button {
                        if let first = selectionManager.selectedCells.first {
                            document.insertColumn(at: first.column)
                        }
                    } label: {
                        Label {
                            Text("Insert Column Left")
                        } icon: {
                            Image("fluent-ic_fluent_column_triple_20_regular", bundle: .module)
                                .renderingMode(.template)
                        }
                    }
                    
                    Button {
                        if let first = selectionManager.selectedCells.first {
                            document.insertColumn(at: first.column + 1)
                        }
                    } label: {
                        Label {
                            Text("Insert Column Right")
                        } icon: {
                            Image("fluent-ic_fluent_column_triple_20_regular", bundle: .module)
                                .renderingMode(.template)
                        }
                    }
                    
                    Button {
                        if let first = selectionManager.selectedCells.first {
                            document.deleteColumn(at: first.column)
                            selectionManager.clearSelection()
                        }
                    } label: {
                        Label {
                            Text("Delete Column")
                        } icon: {
                            Image("fluent-ic_fluent_delete_20_regular", bundle: .module)
                                .renderingMode(.template)
                        }
                    }
                    .disabled(document.colCount <= 1)
                } label: {
                    Label {
                        Text("Table")
                    } icon: {
                        Image("fluent-ic_fluent_table_20_regular", bundle: .module)
                            .resizable()
                            .renderingMode(.template)
                            .aspectRatio(contentMode: .fit)
                    }
                }
                .disabled(selectionManager.selectedCells.isEmpty)
                .help("Table Structure")
            }
            
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("Merge Cells") {
                        document.merge(selection: selectionManager.selectedCells)
                        selectionManager.clearSelection()
                    }
                    .disabled(!canMerge)
                    
                    Button("Unmerge Cells") {
                        if let first = selectionManager.selectedCells.first,
                           let cell = document.anchor(for: first) {
                            document.split(cell: cell)
                            selectionManager.clearSelection()
                        }
                    }
                    .disabled(!canUnmerge)
                } label: {
                    Image("fluent-ic_fluent_shape_union_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
                .help("Merge/Unmerge")
            }
            
            // Text Formatting
            ToolbarItemGroup(placement: .automatic) {
                Button(action: { toggleBold() }) {
                    Image("fluent-ic_fluent_text_bold_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
                .disabled(!canFormatText)
                .help("Bold")
                
                Button(action: { toggleItalic() }) {
                    Image("fluent-ic_fluent_text_italic_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
                .disabled(!canFormatText)
                .help("Italic")
                
                Button(action: { toggleUnderline() }) {
                    Image("fluent-ic_fluent_text_underline_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
                .disabled(!canFormatText)
                .help("Underline")
                
                Button(action: { toggleStrikethrough() }) {
                    Image("fluent-ic_fluent_text_strikethrough_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
                .disabled(!canFormatText)
                .help("Strikethrough")
            }
            
            // Horizontal Alignment
            ToolbarItemGroup(placement: .automatic) {
                Button(action: { setAlignment(.leading) }) {
                    Image("fluent-ic_fluent_text_align_left_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
                .disabled(!isEditing)
                .help("Align Left")
                
                Button(action: { setAlignment(.center) }) {
                    Image("fluent-ic_fluent_text_align_center_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
                .disabled(!isEditing)
                .help("Align Center")
                
                Button(action: { setAlignment(.trailing) }) {
                    Image("fluent-ic_fluent_text_align_right_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
                .disabled(!isEditing)
                .help("Align Right")
            }
            
            // Vertical Alignment
            ToolbarItemGroup(placement: .automatic) {
                Button(action: { setVerticalAlignment(.top) }) {
                    Image("fluent-ic_fluent_arrow_up_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
                .disabled(selectionManager.selectedCells.isEmpty)
                .help("Align Top")
                
                Button(action: { setVerticalAlignment(.center) }) {
                    Image("fluent-ic_fluent_arrow_bidirectional_up_down_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
                .disabled(selectionManager.selectedCells.isEmpty)
                .help("Align Middle")
                
                Button(action: { setVerticalAlignment(.bottom) }) {
                    Image("fluent-ic_fluent_arrow_down_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
                .disabled(selectionManager.selectedCells.isEmpty)
                .help("Align Bottom")
            }
            
            // Font Size
            ToolbarItemGroup(placement: .automatic) {
                Button(action: { makeFontBigger() }) {
                    Image("fluent-ic_fluent_add_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
                .disabled(!canFormatText)
                .help("Increase Font Size")
                
                Button(action: { makeFontSmaller() }) {
                    Image("fluent-ic_fluent_subtract_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
                .disabled(!canFormatText)
                .help("Decrease Font Size")
            }
            
            // Advanced Formatting
            ToolbarItem(placement: .automatic) {
                Menu {
                    Menu("Baseline") {
                        Button("Raise") {
                            raiseBaseline()
                        }
                        Button("Lower") {
                            lowerBaseline()
                        }
                    }
                    
                    Menu("Super/Subscript") {
                        Button("Superscript") {
                            toggleSuperscript()
                        }
                        Button("Subscript") {
                            toggleSubscript()
                        }
                    }
                    
                    Divider()
                    
                    Menu("Kerning") {
                        Button("Tighten") {
                            adjustKerning(-0.5)
                        }
                        Button("Loosen") {
                            adjustKerning(0.5)
                        }
                        Button("Use Standard") {
                            useStandardKerning()
                        }
                        Button("Turn Off") {
                            turnOffKerning()
                        }
                        Button("Reset") {
                            resetKerning()
                        }
                    }
                    
                    Menu("Ligatures") {
                        Button("Standard") {
                            useStandardLigatures()
                        }
                        Button("All") {
                            useAllLigatures()
                        }
                        Button("Off") {
                            turnOffLigatures()
                        }
                        Button("Toggle") {
                            toggleLigatures()
                        }
                    }
                } label: {
                    Image("fluent-ic_fluent_text_font_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
                .disabled(!canFormatText)
                .help("Advanced Formatting")
            }
            
            // Tools Menu
            ToolbarItem(placement: .automatic) {
                Menu {
                    Menu("Panels") {
                        Button("Link Panel...") {
                            showLinkPanel()
                        }
                        Button("List Panel...") {
                            showListPanel()
                        }
                        Button("Spacing Panel...") {
                            showSpacingPanel()
                        }
                        Button("Substitutions Panel...") {
                            showSubstitutionsPanel()
                        }
                    }
                    
                    Menu("Spell & Grammar") {
                        Button("Check Spelling") {
                            checkSpelling()
                        }
                        Toggle("Continuous Check", isOn: Binding(
                            get: { textEditingContext.currentTextView?.isContinuousSpellCheckingEnabled ?? false },
                            set: { _ in toggleContinuousSpellChecking() }
                        ))
                        Toggle("Grammar Check", isOn: Binding(
                            get: { textEditingContext.currentTextView?.isGrammarCheckingEnabled ?? false },
                            set: { _ in toggleGrammarChecking() }
                        ))
                    }
                    
                    Menu("Substitutions") {
                        Toggle("Smart Quotes", isOn: Binding(
                            get: { textEditingContext.currentTextView?.isAutomaticQuoteSubstitutionEnabled ?? false },
                            set: { _ in toggleAutomaticQuoteSubstitution() }
                        ))
                        Toggle("Smart Dashes", isOn: Binding(
                            get: { textEditingContext.currentTextView?.isAutomaticDashSubstitutionEnabled ?? false },
                            set: { _ in toggleAutomaticDashSubstitution() }
                        ))
                        Toggle("Smart Links", isOn: Binding(
                            get: { textEditingContext.currentTextView?.isAutomaticLinkDetectionEnabled ?? false },
                            set: { _ in toggleAutomaticLinkDetection() }
                        ))
                        Toggle("Data Detection", isOn: Binding(
                            get: { textEditingContext.currentTextView?.isAutomaticDataDetectionEnabled ?? false },
                            set: { _ in toggleAutomaticDataDetection() }
                        ))
                        Toggle("Text Replacement", isOn: Binding(
                            get: { textEditingContext.currentTextView?.isAutomaticTextReplacementEnabled ?? false },
                            set: { _ in toggleAutomaticTextReplacement() }
                        ))
                        Toggle("Spelling Correction", isOn: Binding(
                            get: { textEditingContext.currentTextView?.isAutomaticSpellingCorrectionEnabled ?? false },
                            set: { _ in toggleAutomaticSpellingCorrection() }
                        ))
                        Toggle("Text Completion", isOn: Binding(
                            get: { textEditingContext.currentTextView?.isAutomaticTextCompletionEnabled ?? false },
                            set: { _ in toggleAutomaticTextCompletion() }
                        ))
                    }
                    
                    Divider()
                    
                    Button("Complete Text") {
                        complete()
                    }
                    
                    Divider()
                    
                    Button("Start Speaking") {
                        startSpeaking()
                    }
                    Button("Stop Speaking") {
                        stopSpeaking()
                    }
                    
                    Divider()
                    
                    Button("QuickLook Preview") {
                        toggleQuickLook()
                    }
                } label: {
                    Image("fluent-ic_fluent_toolbox_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
                .disabled(!isEditing)
                .help("Text Tools")
            }
            
            // Colors
            ToolbarItem(placement: .automatic) {
                Menu {
                    ForEach([Color.black, .gray, .red, .green, .blue, .yellow, .orange, .purple, .white], id: \.self) { color in
                        Button(action: {
                            setTextColor(color)
                        }) {
                            HStack {
                                Circle()
                                    .fill(color)
                                    .frame(width: 12, height: 12)
                                Text(colorName(color))
                            }
                        }
                    }
                } label: {
                    Image("fluent-ic_fluent_text_color_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
                .disabled(!canFormatText)
                .help("Text Color")
            }
            
            ToolbarItem(placement: .automatic) {
                Menu {
                    ForEach([Color.white, .gray, .red, .green, .blue, .yellow, .orange, .purple], id: \.self) { color in
                        Button(action: {
                            setBackgroundColor(color)
                        }) {
                            HStack {
                                Circle()
                                    .fill(color)
                                    .frame(width: 12, height: 12)
                                Text(colorName(color))
                            }
                        }
                    }
                    Divider()
                    Button("Clear Background") {
                        clearBackgroundColor()
                    }
                } label: {
                    Image("fluent-ic_fluent_paint_brush_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                }
                .disabled(!canFormatText)
                .help("Background Color")
            }
        }
    }
    
    private func handleKeyPress(_ event: NSEvent) -> Bool {
        // Don't intercept keys if already editing
        if editingCell != nil {
            return false
        }
        
        // Handle Tab key (keyCode 48)
        if event.keyCode == 48 {
            if event.modifierFlags.contains(.shift) {
                // Shift+Tab: move left/previous
                selectionManager.moveSelection(direction: SelectionManager.MoveDirection.left, modifiers: [])
            } else {
                // Tab: move right/next
                selectionManager.moveSelection(direction: SelectionManager.MoveDirection.right, modifiers: [])
            }
            return true
        }
        
        if let specialKey = event.specialKey {
            switch specialKey {
            case .upArrow:
                selectionManager.moveSelection(direction: SelectionManager.MoveDirection.up, modifiers: event.modifierFlags)
                return true
            case .downArrow:
                selectionManager.moveSelection(direction: SelectionManager.MoveDirection.down, modifiers: event.modifierFlags)
                return true
            case .leftArrow:
                selectionManager.moveSelection(direction: SelectionManager.MoveDirection.left, modifiers: event.modifierFlags)
                return true
            case .rightArrow:
                selectionManager.moveSelection(direction: SelectionManager.MoveDirection.right, modifiers: event.modifierFlags)
                return true
            case .enter:
                if let selected = selectionManager.selectedCells.first {
                    beginEdit(selected)
                }
                return true
            default:
                break
            }
        } else if event.keyCode == 36 { // Return key
            if let selected = selectionManager.selectedCells.first {
                beginEdit(selected)
            }
            return true
        }
        
        // Type-to-edit: If alphanumeric key pressed on selected cell, enter edit mode and replace content
        if let characters = event.characters,
           !characters.isEmpty,
           !event.modifierFlags.contains(.command), // Don't intercept shortcuts
           !event.modifierFlags.contains(.control),
           let selected = selectionManager.selectedCells.first {
            
            // Check if it's a printable character (not backspace, delete, etc.)
            let allowedChars = CharacterSet.alphanumerics.union(.punctuationCharacters).union(.whitespaces)
            if characters.unicodeScalars.allSatisfy({ allowedChars.contains($0) }) {
                // Replace cell content with the typed character
                let binding = document.bindingForContent(at: selected)
                binding.wrappedValue = RichTextContent(storage: NSAttributedString(string: characters))
                
                // Enter edit mode
                beginEdit(selected)
                return true
            }
        }
        
        return false
    }
    
    private func handleDrag(_ value: DragGesture.Value) {
        let startPoint = value.startLocation
        let currentPoint = value.location
        
        // CRITICAL FIX: On first drag callback, always reset anchor to actual drag start
        // The selectionAnchor may have been set by a previous tap, but we need to use
        // the actual drag start location, not the tap location
        if !isDraggingSelection {
            isDraggingSelection = true
            
            // Clear any existing editing state when starting new drag selection
            editingCell = nil
            focusedCell = nil
            
            // ALWAYS set anchor from where the drag actually started (not from previous tap)
            selectionAnchor = hitTest(point: startPoint)
        }
        
        guard let anchor = selectionAnchor,
              let currentCoord = hitTest(point: currentPoint) else { return }
        
        selectionManager.selectRange(from: anchor, to: currentCoord)
    }
    
    private func handleDragEnd() {
        // Reset drag tracking so next gesture can set proper anchor
        isDraggingSelection = false
        // Note: We intentionally keep selectionAnchor for Shift+click range extension
    }
    
    private func hitTest(point: CGPoint) -> GridCoordinate? {
        // Iterate all visible cell frames
        for (coord, frame) in cellFrames {
            if frame.contains(point) {
                return coord
            }
        }
        return nil
    }
    
    private func handleCellTap(_ coordinate: GridCoordinate) {
        let event = NSApp.currentEvent
        let isShiftDown = event?.modifierFlags.contains(.shift) ?? false
        let alreadySelected = selectionManager.selectedCells.contains(coordinate)
        let isDoubleClick = event?.clickCount == 2
        
        if isShiftDown, let anchor = selectionAnchor ?? selectionManager.selectedCells.first {
            selectionManager.selectRange(from: anchor, to: coordinate)
            focusedCell = nil
            editingCell = nil
        } else if isDoubleClick {
            // Double-click: always enter edit mode
            beginEdit(coordinate)
        } else if alreadySelected {
            // Single click on an already-selected cell enters edit mode (Excel-like)
            beginEdit(coordinate)
        } else {
            selectionManager.selectRange(from: coordinate, to: coordinate)
            selectionAnchor = coordinate
            focusedCell = nil
            editingCell = nil
        }
    }
    
    private func beginEdit(_ coordinate: GridCoordinate) {
        // Ensure the cell is selected then focus it for editing.
        selectionManager.selectRange(from: coordinate, to: coordinate)
        selectionAnchor = coordinate
        focusedCell = coordinate
        editingCell = coordinate
    }
    
    private func commitAndNavigate(from coordinate: GridCoordinate, direction: SelectionManager.MoveDirection) {
        // Exit edit mode
        editingCell = nil
        
        // Navigate to next cell
        selectionManager.selectRange(from: coordinate, to: coordinate)
        selectionManager.moveSelection(direction: direction, modifiers: [])
        
        // Start editing the new cell automatically for fluid editing
        if let newSelection = selectionManager.selectedCells.first {
            beginEdit(newSelection)
        }
    }
    
    // MARK: - Toolbar State
    
    private var isEditing: Bool {
        editingCell != nil && textEditingContext.currentTextView != nil
    }
    
    private var hasTextSelection: Bool {
        guard let textView = textEditingContext.currentTextView else { return false }
        return textView.selectedRange().length > 0
    }
    
    private var canFormatText: Bool {
        isEditing && hasTextSelection
    }
    
    // MARK: - Formatting Actions
    
    private var canMerge: Bool {
        let count = selectionManager.selectedCells.count
        if count <= 1 { return false }
        guard let first = selectionManager.selectedCells.first,
              let anchor = document.anchor(for: first) else { return false }
        return anchor.span.rowSpan * anchor.span.colSpan != count
    }
    
    private var canUnmerge: Bool {
        let count = selectionManager.selectedCells.count
        if count == 0 { return false }
        if count == 1 {
            guard let first = selectionManager.selectedCells.first,
                  let cell = document.anchor(for: first) else { return false }
            return cell.span.rowSpan > 1 || cell.span.colSpan > 1
        }
        guard let first = selectionManager.selectedCells.first,
              let anchor = document.anchor(for: first) else { return false }
        let isSingleLogical = anchor.span.rowSpan * anchor.span.colSpan == count
        if isSingleLogical {
            return anchor.span.rowSpan > 1 || anchor.span.colSpan > 1
        }
        return false
    }
    
    private func toggleBold() {
        textEditingContext.toggleBold()
    }
    
    private func toggleItalic() {
        textEditingContext.toggleItalic()
    }
    
    private func toggleUnderline() {
        textEditingContext.toggleUnderline()
    }
    
    private func toggleStrikethrough() {
        textEditingContext.toggleStrikethrough()
    }
    
    private func setAlignment(_ alignment: TextAlignment) {
        textEditingContext.setAlignment(alignment.nsTextAlignment)
    }
    
    private func makeFontBigger() {
        textEditingContext.makeFontBigger()
    }
    
    private func makeFontSmaller() {
        textEditingContext.makeFontSmaller()
    }
    
    private func toggleSuperscript() {
        textEditingContext.toggleSuperscript()
    }
    
    private func toggleSubscript() {
        textEditingContext.toggleSubscript()
    }
    
    private func adjustKerning(_ delta: CGFloat) {
        textEditingContext.adjustKerning(delta)
    }
    
    private func resetKerning() {
        textEditingContext.resetKerning()
    }
    
    private func toggleLigatures() {
        textEditingContext.toggleLigatures()
    }
    
    private func setVerticalAlignment(_ alignment: CellVerticalAlignment) {
        document.updateStyle(for: selectionManager.selectedCells) { style in
            style.verticalAlignment = alignment
        }
    }
    
    private func setTextColor(_ color: Color) {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        textEditingContext.setTextColor(nsColor)
    }
    
    private func setBackgroundColor(_ color: Color) {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        textEditingContext.setBackgroundColor(nsColor)
    }
    
    private func clearBackgroundColor() {
        textEditingContext.clearBackgroundColor()
    }
    
    private func raiseBaseline() {
        textEditingContext.raiseBaseline()
    }
    
    private func lowerBaseline() {
        textEditingContext.lowerBaseline()
    }
    
    private func useStandardKerning() {
        textEditingContext.useStandardKerning()
    }
    
    private func turnOffKerning() {
        textEditingContext.turnOffKerning()
    }
    
    private func useStandardLigatures() {
        textEditingContext.useStandardLigatures()
    }
    
    private func useAllLigatures() {
        textEditingContext.useAllLigatures()
    }
    
    private func turnOffLigatures() {
        textEditingContext.turnOffLigatures()
    }
    
    private func showLinkPanel() {
        textEditingContext.showLinkPanel()
    }
    
    private func showListPanel() {
        textEditingContext.showListPanel()
    }
    
    private func showSpacingPanel() {
        textEditingContext.showSpacingPanel()
    }
    
    private func showSubstitutionsPanel() {
        textEditingContext.showSubstitutionsPanel()
    }
    
    private func checkSpelling() {
        textEditingContext.checkSpelling()
    }
    
    private func toggleContinuousSpellChecking() {
        textEditingContext.toggleContinuousSpellChecking()
    }
    
    private func toggleGrammarChecking() {
        textEditingContext.toggleGrammarChecking()
    }
    
    private func toggleAutomaticQuoteSubstitution() {
        textEditingContext.toggleAutomaticQuoteSubstitution()
    }
    
    private func toggleAutomaticDashSubstitution() {
        textEditingContext.toggleAutomaticDashSubstitution()
    }
    
    private func toggleAutomaticLinkDetection() {
        textEditingContext.toggleAutomaticLinkDetection()
    }
    
    private func toggleAutomaticDataDetection() {
        textEditingContext.toggleAutomaticDataDetection()
    }
    
    private func toggleAutomaticTextReplacement() {
        textEditingContext.toggleAutomaticTextReplacement()
    }
    
    private func toggleAutomaticSpellingCorrection() {
        textEditingContext.toggleAutomaticSpellingCorrection()
    }
    
    private func toggleAutomaticTextCompletion() {
        textEditingContext.toggleAutomaticTextCompletion()
    }
    
    private func complete() {
        textEditingContext.complete()
    }
    
    private func startSpeaking() {
        textEditingContext.startSpeaking()
    }
    
    private func stopSpeaking() {
        textEditingContext.stopSpeaking()
    }
    
    private func toggleQuickLook() {
        textEditingContext.toggleQuickLook()
    }
    
    private func colorName(_ color: Color) -> String {
        switch color {
        case .black: return "Black"
        case .white: return "White"
        case .gray: return "Gray"
        case .red: return "Red"
        case .green: return "Green"
        case .blue: return "Blue"
        case .yellow: return "Yellow"
        case .orange: return "Orange"
        case .purple: return "Purple"
        default: return "Color"
        }
    }
}

struct SmartTable_Previews: PreviewProvider {
    static var previews: some View {
        SmartTable(rows: 5, cols: 5)
            .frame(width: 600, height: 400)
    }
}
