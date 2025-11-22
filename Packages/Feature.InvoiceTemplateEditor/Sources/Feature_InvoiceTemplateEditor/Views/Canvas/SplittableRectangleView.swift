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

    @State private var isHovered = false
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
        Group {
            if let split {
                splitContent(for: split)
            } else {
                leafContent
            }
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95)),
            removal: .opacity.combined(with: .scale(scale: 0.95))
        ))
        .animation(.easeInOut(duration: 0.25), value: split?.id)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
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
                        context.onUpdateSplit(updated)
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
    private var leafContent: some View {
        let marginInset = split?.margin ?? 0
        let totalHorizontal = max(0, marginInset * 2 + childPadding.leading + childPadding.trailing)
        let totalVertical = max(0, marginInset * 2 + childPadding.top + childPadding.bottom)
        let innerSize = CGSize(
            width: max(0, containerSize.width - totalHorizontal),
            height: max(0, containerSize.height - totalVertical)
        )
        
        LeafContentView(
            components: leafComponents,
            containerSize: innerSize,
            sectionIndex: sectionIndex,
            childIndex: childIndex,
            nodePath: nodePath,
            parentAlignment: parentAlignment,
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
                context.onUpdateSplit(alignmentOnlySplit)
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
        .frame(width: innerSize.width, height: innerSize.height)
        .frame(width: containerSize.width, height: containerSize.height)
    }
    
    @ViewBuilder
    private func splitContent(for split: SectionSplit) -> some View {
        let innerSize = CGSize(
            width: max(0, containerSize.width - (split.margin * 2) - childPadding.leading - childPadding.trailing),
            height: max(0, containerSize.height - (split.margin * 2) - childPadding.top - childPadding.bottom)
        )
        let selection = currentSelection
        let isSelected = selection.map { $0 == document.selectedSplitSelection } ?? false
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
        .overlay(alignment: .topLeading) {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.controlAccentColor), lineWidth: 1.5)
                    .padding(2)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let selection,
               let onLeafSelect = context.onLeafSelect,
               (isHovered || isSelected) {
                Button(action: { onLeafSelect(selection) }) {
                    Image(systemName: "cursorarrow.square")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(6)
                }
                .buttonStyle(.plain)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color(NSColor.separatorColor).opacity(0.4))
                )
                .help("Focus this split in the inspector")
                .padding(6)
            }
        }
        .contentShape(Rectangle())
        
        if shouldShowContextMenu, let selection {
            baseLayout
                .padding(EdgeInsets(
                    top: split.margin + childPadding.top,
                    leading: split.margin + childPadding.leading,
                    bottom: split.margin + childPadding.bottom,
                    trailing: split.margin + childPadding.trailing
                ))
                .frame(width: containerSize.width, height: containerSize.height, alignment: .center)
                .contextMenu {
                splitContextMenu(selection: selection)
            }
        } else {
            baseLayout
                .padding(EdgeInsets(
                    top: split.margin + childPadding.top,
                    leading: split.margin + childPadding.leading,
                    bottom: split.margin + childPadding.bottom,
                    trailing: split.margin + childPadding.trailing
                ))
                .frame(width: containerSize.width, height: containerSize.height, alignment: .center)
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
                        Label(mode.displayName, systemImage: mode.icon)
                    }
                }
            }
        }
        
        if let handler = context.onSetHeightSizingMode {
            Menu("Height Sizing") {
                ForEach(SectionSplit.SizingMode.allCases, id: \.self) { mode in
                    Button(action: { handler(childIndex, mode) }) {
                        Label(mode.displayName, systemImage: mode.icon)
                    }
                }
            }
        }
        
        if let handler = context.onSetGridSizingMode {
            Menu("Row Sizing") {
                ForEach(SectionSplit.SizingMode.allCases, id: \.self) { mode in
                    Button(action: { handler(childIndex, true, mode) }) {
                        Label(mode.displayName, systemImage: mode.icon)
                    }
                }
            }
            Menu("Column Sizing") {
                ForEach(SectionSplit.SizingMode.allCases, id: \.self) { mode in
                    Button(action: { handler(childIndex, false, mode) }) {
                        Label(mode.displayName, systemImage: mode.icon)
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
                Label("Select Section", systemImage: "cursorarrow.square")
            }
        }
    }
    
    private var currentSelection: SectionSplitSelection? {
        guard !nodePath.isEmpty else { return nil }
        return SectionSplitSelection(sectionIndex: sectionIndex, path: nodePath)
    }
}
