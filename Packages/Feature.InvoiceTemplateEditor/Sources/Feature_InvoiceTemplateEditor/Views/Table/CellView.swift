import SwiftUI

public struct CellView: View {
    @Binding var content: RichTextContent
    public let cell: CellModel
    public let isSelected: Bool
    public let isAlternatingRowColorsEnabled: Bool
    let isHeaderRowEnabled: Bool
    let isFirstColumnEnabled: Bool
    let focusBinding: FocusState<GridCoordinate?>.Binding
    let isEditing: Bool
    let onSelect: () -> Void
    let onContentHeightChange: ((CGFloat) -> Void)?
    let onCommit: (() -> Void)?
    let onTab: ((Bool) -> Void)?
    let onEnter: ((Bool) -> Void)?
    
    public init(
        content: Binding<RichTextContent>,
        cell: CellModel,
        isSelected: Bool,
        isAlternatingRowColorsEnabled: Bool = false,
        isHeaderRowEnabled: Bool = false,
        isFirstColumnEnabled: Bool = false,
        focusBinding: FocusState<GridCoordinate?>.Binding,
        isEditing: Bool,
        onSelect: @escaping () -> Void,
        onContentHeightChange: ((CGFloat) -> Void)? = nil,
        onCommit: (() -> Void)? = nil,
        onTab: ((Bool) -> Void)? = nil,
        onEnter: ((Bool) -> Void)? = nil
    ) {
        self._content = content
        self.cell = cell
        self.isSelected = isSelected
        self.isAlternatingRowColorsEnabled = isAlternatingRowColorsEnabled
        self.isHeaderRowEnabled = isHeaderRowEnabled
        self.isFirstColumnEnabled = isFirstColumnEnabled
        self.focusBinding = focusBinding
        self.isEditing = isEditing
        self.onSelect = onSelect
        self.onContentHeightChange = onContentHeightChange
        self.onCommit = onCommit
        self.onTab = onTab
        self.onEnter = onEnter
    }
    
    @State private var isHovering = false
    
    public var body: some View {
        let isHeaderRow = isHeaderRowEnabled && cell.coordinate.row == 0
        let isFirstColumn = isFirstColumnEnabled && cell.coordinate.column == 0
        
        let backgroundColor: Color
        if let bg = cell.style.backgroundColor {
            backgroundColor = bg.swiftUIColor
        } else if isHeaderRow {
            backgroundColor = Color.gray.opacity(0.2)
        } else if isFirstColumn {
            backgroundColor = Color.gray.opacity(0.15)
        } else if isAlternatingRowColorsEnabled && cell.coordinate.row % 2 == 1 {
            backgroundColor = Color.gray.opacity(0.1)
        } else {
            backgroundColor = .clear
        }
        
        return ZStack {
            // Background
            backgroundColor
                .allowsHitTesting(false)
            
            // Subtle hover feedback (only when not selected or editing)
            if isHovering && !isSelected && !isEditing {
                Color.blue.opacity(0.05)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            
            // Selection Overlay with smooth animation
            if isSelected {
                Color.blue.opacity(0.2)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            
            // Subtle editing indicator
            if isEditing {
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(Color.blue.opacity(0.5), lineWidth: 2)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            
            // Layer 1: Display Mode (Navigation)
            if !isEditing {
                RichTextDisplay(
                    content: $content,
                    style: cell.style,
                    onHeightChange: onContentHeightChange
                )
                .padding(cell.style.padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment(for: cell.style.textAlignment, vertical: cell.style.verticalAlignment))
            }
            
            // Layer 2: Edit Mode
            if isEditing {
                RichTextEditor(
                    content: $content,
                    style: cell.style,
                    onHeightChange: onContentHeightChange,
                    onCommit: onCommit,
                    onTab: onTab,
                    onEnter: onEnter
                )
                .padding(cell.style.padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment(for: cell.style.textAlignment, vertical: cell.style.verticalAlignment))
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onTapGesture(count: 2) {
            // Double-click: Directly triggers edit mode via coordinate
            // Just call onSelect, and SmartTable's handleCellTap will detect double-click pattern
            onSelect()
        }
        .onTapGesture(count: 1) {
            // Single click: select
            onSelect()
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isEditing)
        // Border is now handled by GridLinesCanvas
        // Note: Double-click to edit, or press Enter/Return on selected cell
    }
    
    private func alignment(for textAlignment: TextAlignment, vertical: CellVerticalAlignment) -> Alignment {
        let horizontal: HorizontalAlignment
        switch textAlignment {
        case .leading: horizontal = .leading
        case .center: horizontal = .center
        case .trailing: horizontal = .trailing
        }
        
        let vert: VerticalAlignment
        switch vertical {
        case .top: vert = .top
        case .center: vert = .center
        case .bottom: vert = .bottom
        }
        
        return Alignment(horizontal: horizontal, vertical: vert)
    }
    
    private func textAlignment(for textAlignment: Feature_InvoiceTemplateEditor.TextAlignment) -> SwiftUI.TextAlignment {
        switch textAlignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}
