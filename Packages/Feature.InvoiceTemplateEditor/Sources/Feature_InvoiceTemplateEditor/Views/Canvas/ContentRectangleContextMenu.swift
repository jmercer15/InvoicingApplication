import SwiftUI

struct ContentRectangleContextMenu: View {
    let contentAlignment: SectionSplit.LeafAlignment
    let currentWidthSizingMode: SectionSplit.SizingMode?
    let currentHeightSizingMode: SectionSplit.SizingMode?
    let currentRowSizingMode: SectionSplit.SizingMode?
    let currentColumnSizingMode: SectionSplit.SizingMode?
    let onSetAlignment: ((SectionSplit.LeafAlignment) -> Void)?
    let onSetWidthSizingMode: ((SectionSplit.SizingMode) -> Void)?
    let onSetHeightSizingMode: ((SectionSplit.SizingMode) -> Void)?
    let onSetGridSizingMode: ((Bool, SectionSplit.SizingMode) -> Void)?
    let onRequestSplit: (SectionSplit.SplitDirection, Int) -> Void
    let onRequestRemove: (() -> Void)?
    
    var body: some View {
        let hasSizingMenus = onSetWidthSizingMode != nil
            || onSetHeightSizingMode != nil
            || onSetGridSizingMode != nil
        let hasAlignmentMenu = onSetAlignment != nil
        
        if let handler = onSetWidthSizingMode {
            sizingMenu(
                title: "Width Sizing",
                currentMode: currentWidthSizingMode,
                handler: handler
            )
        }
        
        if let handler = onSetHeightSizingMode {
            sizingMenu(
                title: "Height Sizing",
                currentMode: currentHeightSizingMode,
                handler: handler
            )
        }
        
        if let handler = onSetGridSizingMode {
            sizingMenu(
                title: "Row Sizing",
                currentMode: currentRowSizingMode,
                handler: { mode in handler(true, mode) }
            )
            sizingMenu(
                title: "Column Sizing",
                currentMode: currentColumnSizingMode,
                handler: { mode in handler(false, mode) }
            )
        }
        
        if hasSizingMenus && (hasAlignmentMenu || onRequestRemove != nil) {
            Divider()
        }
        
        if let handler = onSetAlignment {
            alignmentMenu(handler: handler)
        }
        
        if hasAlignmentMenu || hasSizingMenus {
            Divider()
        }
        
        Menu("Split") {
            Button("Split Horizontally") {
                onRequestSplit(.horizontal, 2)
            }
            Button("Split Vertically") {
                onRequestSplit(.vertical, 2)
            }
            Button("Split Grid") {
                onRequestSplit(.grid, 4)
            }
        }
        
        if let onRequestRemove {
            Divider()
            Button("Remove Split", role: .destructive) {
                onRequestRemove()
            }
        }
    }
    
    @ViewBuilder
    private func sizingMenu(
        title: String,
        currentMode: SectionSplit.SizingMode?,
        handler: @escaping (SectionSplit.SizingMode) -> Void
    ) -> some View {
        Menu(title) {
            ForEach(SectionSplit.SizingMode.allCases, id: \.self) { mode in
                Button(action: { handler(mode) }) {
                    Label {
                        Text(mode.displayName)
                    } icon: {
                        if currentMode == mode {
                            Image("fluent-ic_fluent_checkmark_20_regular", bundle: .module)
                                .renderingMode(.template)
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func alignmentMenu(
        handler: @escaping (SectionSplit.LeafAlignment) -> Void
    ) -> some View {
        Menu("Content Alignment") {
            Menu("Horizontal") {
                alignmentButton(
                    title: "Leading",
                    isSelected: contentAlignment.horizontal == .leading
                ) {
                    var updated = contentAlignment
                    updated.horizontal = .leading
                    handler(updated)
                }
                alignmentButton(
                    title: "Center",
                    isSelected: contentAlignment.horizontal == .center
                ) {
                    var updated = contentAlignment
                    updated.horizontal = .center
                    handler(updated)
                }
                alignmentButton(
                    title: "Trailing",
                    isSelected: contentAlignment.horizontal == .trailing
                ) {
                    var updated = contentAlignment
                    updated.horizontal = .trailing
                    handler(updated)
                }
            }
            
            Menu("Vertical") {
                alignmentButton(
                    title: "Top",
                    isSelected: contentAlignment.vertical == .top
                ) {
                    var updated = contentAlignment
                    updated.vertical = .top
                    handler(updated)
                }
                alignmentButton(
                    title: "Center",
                    isSelected: contentAlignment.vertical == .center
                ) {
                    var updated = contentAlignment
                    updated.vertical = .center
                    handler(updated)
                }
                alignmentButton(
                    title: "Bottom",
                    isSelected: contentAlignment.vertical == .bottom
                ) {
                    var updated = contentAlignment
                    updated.vertical = .bottom
                    handler(updated)
                }
            }
        }
    }
    
    private func alignmentButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                if isSelected {
                    Image("fluent-ic_fluent_checkmark_20_regular", bundle: .module)
                        .renderingMode(.template)
                }
            }
        }
    }
}
