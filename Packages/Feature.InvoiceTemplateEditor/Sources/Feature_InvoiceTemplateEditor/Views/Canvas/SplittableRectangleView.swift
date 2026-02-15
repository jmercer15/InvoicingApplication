//
//  SplittableRectangleView.swift
//  Feature.InvoiceTemplateEditor
//
//  Recursive view for rendering splittable sections with nested splits
//

import SwiftUI
import Core

struct SplittableRectangleView: View {
    let split: SectionSplit?
    let leafComponents: [InvoiceComponent]
    let containerSize: CGSize
    let sectionIndex: Int
    let nodePath: [Int]
    let childIndex: Int
    let childPadding: SectionSplit.PaddingInsets
    let parentAlignment: SectionSplit.LeafAlignment
    let context: SplitInteractionContext
    
    @EnvironmentObject private var document: InvoiceDocument

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHandleHovered = false  // For highlight overlay (handle hover only)
    @State private var isContentHovered = false  // For showing handles (content hover)
    @State private var showingSplitDialog = false
    @State private var selectedSplitDirection: SectionSplit.SplitDirection = .horizontal
    @State private var splitCount: Int = 2

    init(
        split: SectionSplit?,
        leafComponents: [InvoiceComponent] = [],
        containerSize: CGSize,
        sectionIndex: Int,
        nodePath: [Int] = [],
        childIndex: Int = 0,
        childPadding: SectionSplit.PaddingInsets = .zero,
        parentAlignment: SectionSplit.LeafAlignment = .default,
        context: SplitInteractionContext
    ) {
        self.split = split
        self.leafComponents = leafComponents
        self.containerSize = containerSize
        self.sectionIndex = sectionIndex
        self.nodePath = nodePath
        self.childIndex = childIndex
        self.childPadding = childPadding
        self.parentAlignment = parentAlignment
        self.context = context
    }

    var body: some View {
        let innerSize = CGSize(
            width: max(0, containerSize.width - childPadding.leading - childPadding.trailing),
            height: max(0, containerSize.height - childPadding.top - childPadding.bottom)
        )
        
        Group {
            if let split {
                splitContent(for: split, size: innerSize)
            } else {
                leafContent(size: innerSize)
            }
        }
        .frame(width: innerSize.width, height: innerSize.height)
        .padding(EdgeInsets(
            top: childPadding.top,
            leading: childPadding.leading,
            bottom: childPadding.bottom,
            trailing: childPadding.trailing
        ))
        .frame(width: containerSize.width, height: containerSize.height)
        .contentShape(Rectangle()) // Ensure reliable hover detection
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95)),
            removal: .opacity.combined(with: .scale(scale: 0.95))
        ))
        .animation(reduceMotion ? nil : CanvasAnimation.quick, value: isContentHovered && split == nil)
        .animation(reduceMotion ? nil : CanvasAnimation.selectionSpring, value: isSelected())
        .animation(reduceMotion ? nil : CanvasAnimation.hoverSpring, value: split?.id)
        .zIndex(CanvasZ.content)
        .onKeyPress(.space) {
            presentSplitDialog(.horizontal, count: 2)
            return .handled
        }
        .onKeyPress(.init("h")) {
            presentSplitDialog(.horizontal, count: 2)
            return .handled
        }
        .onKeyPress(.init("v")) {
            presentSplitDialog(.vertical, count: 2)
            return .handled
        }
        .onKeyPress(.init("g")) {
            presentSplitDialog(.grid, count: 4)
            return .handled
        }
        .onKeyPress(.delete) {
            if split != nil {
                context.onUnsplitChild(childIndex)
            }
            return .handled
        }
        .sheet(isPresented: $showingSplitDialog) {
            SplitConfigurationDialog(
                direction: $selectedSplitDirection,
                splitCount: $splitCount,
                onConfirm: { direction, count, rows, columns in
                    if let split = split, direction == .grid, let rows, let columns {
                        var updated = split
                        updated.splitChild(at: childIndex, direction: direction, splitCount: count, gridRows: rows, gridColumns: columns)
                        context.onUpdateSplit(updated, "Split Section")
                    } else {
                        context.onSplitChild(childIndex, direction, count, nil, nil)
                    }
                    showingSplitDialog = false
                },
                onCancel: { showingSplitDialog = false }
            )
        }
    }

    private func presentSplitDialog(_ direction: SectionSplit.SplitDirection, count: Int) {
        guard split == nil else { return }
        selectedSplitDirection = direction
        splitCount = count
        showingSplitDialog = true
    }
    
    // MARK: - Leaf & Split Builders
    
    @ViewBuilder
    private func leafContent(size: CGSize) -> some View {
        LeafContentView(
            components: leafComponents,
            containerSize: size,
            sectionIndex: sectionIndex,
            childIndex: childIndex,
            nodePath: nodePath,
            parentAlignment: parentAlignment,
            currentWidthSizingMode: context.currentWidthSizingMode,
            currentHeightSizingMode: context.currentHeightSizingMode,
            currentRowSizingMode: context.currentRowSizingMode,
            currentColumnSizingMode: context.currentColumnSizingMode,
            onAddComponent: { component in
                context.onAddComponent(childIndex, component)
            },
            onSplit: { direction, count, rows, columns in
                if direction == .grid, let rows, let columns {
                    context.onSplitChild(childIndex, direction, count, rows, columns)
                } else {
                    context.onSplitChild(childIndex, direction, count, nil, nil)
                }
            },
            onUnsplit: {
                context.onUnsplitChild(childIndex)
            },
            onSetLabel: { label in
                context.onSetLabel?(childIndex, label)
            },
            onSetAlignment: { alignment in
                var alignmentOnlySplit = SectionSplit(direction: .horizontal, splitCount: 1)
                alignmentOnlySplit.setAlignment(alignment, forChild: 0)
                alignmentOnlySplit.childComponents = [:]
                context.onUpdateSplit(alignmentOnlySplit, "Change Alignment")
            },
            onSetWidthSizingMode: { mode in
                context.onSetWidthSizingMode?(childIndex, mode)
            },
            onSetHeightSizingMode: { mode in
                context.onSetHeightSizingMode?(childIndex, mode)
            },
            onSetGridSizingMode: { isRow, mode in
                context.onSetGridSizingMode?(childIndex, isRow, mode)
            },
            onComponentSelect: context.onComponentSelect,
            onLeafSelect: context.onLeafSelect
        )
        .frame(width: size.width, height: size.height)
    }
    
    @ViewBuilder
    private func splitContent(for split: SectionSplit, size: CGSize) -> some View {
        let innerSize = CGSize(
            width: max(0, size.width - (split.margin * 2)),
            height: max(0, size.height - (split.margin * 2))
        )
        let selection = currentSelection
        let isSelected = selection.map { $0 == document.selectedSplitSelection } ?? false
        let isHoverHighlighted = selection.map { $0 == document.hoveredSplitSelection } ?? false
        let hasSizingMenus = context.onSetWidthSizingMode != nil ||
            context.onSetHeightSizingMode != nil ||
            context.onSetGridSizingMode != nil
        let canSelect = selection != nil && context.onLeafSelect != nil
        let shouldShowContextMenu = selection != nil && (hasSizingMenus || canSelect)
        
        let baseLayout = Group {
            switch split.direction {
            case .horizontal:
                LinearSplitView(
                    split: split,
                    direction: .horizontal,
                    containerSize: innerSize,
                    sectionIndex: sectionIndex,
                    nodePath: nodePath,
                    context: context
                )
            case .vertical:
                LinearSplitView(
                    split: split,
                    direction: .vertical,
                    containerSize: innerSize,
                    sectionIndex: sectionIndex,
                    nodePath: nodePath,
                    context: context
                )
            case .grid:
                GridSplitView(
                    split: split,
                    containerSize: innerSize,
                    sectionIndex: sectionIndex,
                    nodePath: nodePath,
                    context: context
                )
            }
        }
        .padding(split.margin)
        .frame(width: size.width, height: size.height, alignment: .center)
        .overlay {
            // Unified state overlay for hover/selection - applied AFTER padding
            // Show hover highlight from either: handle hover OR panel row hover (isHoverHighlighted)
            StateOverlay(
                elementType: .split,
                isHovered: isHandleHovered || isHoverHighlighted,
                isSelected: isSelected,
                isDropTarget: false
            )
        }
        .overlay(alignment: .topLeading) {
            // Selection handle - only show on direct canvas hover, NOT panel hover
            // Offset based on nesting depth to prevent overlap
            if let selection,
               let onLeafSelect = context.onLeafSelect,
               (isContentHovered || isSelected) {
                let depthOffset = CGFloat(nodePath.count) * 20 // Offset by depth
                SelectionHandle(
                    elementType: .split,
                    isSelected: isSelected,
                    action: { onLeafSelect(selection) },
                    onHover: { hovering in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isHandleHovered = hovering
                        }
                    }
                )
                .padding(.leading, 4 + depthOffset)
                .padding(.top, 4)
                .help("Select this split section")
                .zIndex(CanvasZ.handles)
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                if !isContentHovered {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isContentHovered = true
                    }
                }
            case .ended:
                withAnimation(.easeInOut(duration: 0.1)) {
                    isContentHovered = false
                    isHandleHovered = false
                }
            }
        }
        
        if shouldShowContextMenu, let selection {
            baseLayout
                .contextMenu {
                    splitContextMenu(selection: selection)
                }
                .transition(.opacity)
        } else {
            baseLayout
        }
    }
    
    @ViewBuilder
    private func splitContextMenu(selection: SectionSplitSelection) -> some View {
        let hasWidthControl = context.onSetWidthSizingMode != nil
        let hasHeightControl = context.onSetHeightSizingMode != nil
        let hasGridControl = context.onSetGridSizingMode != nil
        let hasSizingMenus = hasWidthControl || hasHeightControl || hasGridControl
        
        if let handler = context.onSetWidthSizingMode {
            Menu("Width Sizing") {
                ForEach(SectionSplit.SizingMode.allCases, id: \.self) { mode in
                    Button(action: { handler(childIndex, mode) }) {
                        Label {
                            Text(mode.displayName)
                        } icon: {
                            if context.currentWidthSizingMode == mode {
                                Image("fluent-ic_fluent_checkmark_20_regular", bundle: .module)
                                    .renderingMode(.template)
                            }
                        }
                    }
                }
            }
        }
        
        if let handler = context.onSetHeightSizingMode {
            Menu("Height Sizing") {
                ForEach(SectionSplit.SizingMode.allCases, id: \.self) { mode in
                    Button(action: { handler(childIndex, mode) }) {
                        Label {
                            Text(mode.displayName)
                        } icon: {
                            if context.currentHeightSizingMode == mode {
                                Image("fluent-ic_fluent_checkmark_20_regular", bundle: .module)
                                    .renderingMode(.template)
                            }
                        }
                    }
                }
            }
        }
        
        if let handler = context.onSetGridSizingMode {
            Menu("Row Sizing") {
                ForEach(SectionSplit.SizingMode.allCases, id: \.self) { mode in
                    Button(action: { handler(childIndex, true, mode) }) {
                        Label {
                            Text(mode.displayName)
                        } icon: {
                            if context.currentRowSizingMode == mode {
                                Image("fluent-ic_fluent_checkmark_20_regular", bundle: .module)
                                    .renderingMode(.template)
                            }
                        }
                    }
                }
            }
            Menu("Column Sizing") {
                ForEach(SectionSplit.SizingMode.allCases, id: \.self) { mode in
                    Button(action: { handler(childIndex, false, mode) }) {
                        Label {
                            Text(mode.displayName)
                        } icon: {
                            if context.currentColumnSizingMode == mode {
                                Image("fluent-ic_fluent_checkmark_20_regular", bundle: .module)
                                    .renderingMode(.template)
                            }
                        }
                    }
                }
            }
        }
        
        if hasSizingMenus && context.onLeafSelect != nil {
            Divider()
        }
        
        if let onLeafSelect = context.onLeafSelect {
            Button {
                onLeafSelect(selection)
            } label: {
                Label {
                    Text("Select Section")
                } icon: {
                    Image("fluent-ic_fluent_target_20_regular", bundle: .module)
                        .renderingMode(.template)
                }
            }
        }
    }
    
    private var currentSelection: SectionSplitSelection? {
        guard !nodePath.isEmpty else { return nil }
        return SectionSplitSelection(sectionIndex: sectionIndex, path: nodePath)
    }
    
    private func isSelected() -> Bool {
        guard let selection = currentSelection else { return false }
        return selection == document.selectedSplitSelection
    }
}
