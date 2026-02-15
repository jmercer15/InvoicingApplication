//
//  ContentRectangleView.swift
//  Feature.InvoiceTemplateEditor
//
//  Leaf section view that displays components and handles drops
//

import SwiftUI
import UniformTypeIdentifiers
import Core

struct ContentRectangleView: View {
    let components: [InvoiceComponent]
    let containerSize: CGSize
    let sectionLabel: String?
    let contentAlignment: SectionSplit.LeafAlignment
    let sectionIndex: Int
    let childIndex: Int
    let leafPath: [Int]
    let currentWidthSizingMode: SectionSplit.SizingMode?
    let currentHeightSizingMode: SectionSplit.SizingMode?
    let currentRowSizingMode: SectionSplit.SizingMode?
    let currentColumnSizingMode: SectionSplit.SizingMode?
    let onAddComponent: (InvoiceComponent) -> Void
    let onSplit: (SectionSplit.SplitDirection, Int, Int?, Int?) -> Void
    let onUnsplit: (() -> Void)?
    let onSetLabel: ((String?) -> Void)?
    let onSetAlignment: ((SectionSplit.LeafAlignment) -> Void)?
    let onSetWidthSizingMode: ((SectionSplit.SizingMode) -> Void)?
    let onSetHeightSizingMode: ((SectionSplit.SizingMode) -> Void)?
    let onSetGridSizingMode: ((Bool, SectionSplit.SizingMode) -> Void)? // isRow, mode
    let onComponentSelect: (InvoiceComponent) -> Void
    let onLeafSelect: ((SectionSplitSelection) -> Void)?
    let allowDrop: Bool

    @EnvironmentObject private var document: InvoiceDocument

    @State private var hoverState = HoverState()
    @State private var splitState = SplitState()
    @State private var statusState = StatusState()

    var body: some View {
        ZStack(alignment: dynamicAlignment) {
            backgroundLayer
            componentLayer
            ContentRectangleOverlays(
                containerSize: containerSize,
                isProcessingSplit: splitState.isProcessing,
                showSuccessIndicator: statusState.showSuccess,
                showDropSuccess: statusState.showDropSuccess
            )
        }
        .frame(width: containerSize.width, height: containerSize.height)
        .clipped()
        .accessibilityLabel("Content section")
        .accessibilityHint("Tap to select, drag to drop content, or use context menu for options")
        .zIndex(CanvasZ.content)
        .sheet(isPresented: $splitState.isDialogPresented) {
            SplitConfigurationDialog(
                direction: $splitState.direction,
                splitCount: $splitState.splitCount,
                onConfirm: { direction, count, rows, columns in
                    // Show processing state
                    withAnimation(CanvasAnimation.standard) {
                        splitState.isProcessing = true
                    }

                    // Simulate processing delay for visual feedback
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onSplit(direction, count, rows, columns)

                        // Hide processing and show success
                        withAnimation(CanvasAnimation.standard) {
                            splitState.isProcessing = false
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(CanvasAnimation.selectionSpring) {
                                statusState.showSuccess = true
                            }
                        }
                    }
                    splitState.isDialogPresented = false
                },
                onCancel: {
                    splitState.isDialogPresented = false
                }
            )
        }
        .alert("Remove Section?", isPresented: $splitState.isRemoveConfirmPresented) {
            Button("Remove", role: .destructive) {
                onUnsplit?()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will remove this section from the layout.")
        }
        .onChange(of: statusState.showSuccess) { newValue in
            guard newValue else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(CanvasAnimation.deliberate) {
                    statusState.showSuccess = false
                }
            }
        }
        .onChange(of: statusState.showDropSuccess) { newValue in
            guard newValue else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(CanvasAnimation.quick) {
                    statusState.showDropSuccess = false
                }
            }
        }
    }

    private var dynamicAlignment: Alignment {
        Alignment(
            horizontal: contentAlignment.horizontal.swiftUIAlignment,
            vertical: contentAlignment.vertical.swiftUIAlignment
        )
    }

    private var normalizedSelectionPath: [Int] {
        leafPath.isEmpty ? [0] : leafPath
    }

    private var currentSelection: SectionSplitSelection {
        SectionSplitSelection(sectionIndex: sectionIndex, path: normalizedSelectionPath)
    }

    private var isSelectedLeaf: Bool {
        guard let selection = document.selectedSplitSelection else { return false }
        return selection.sectionIndex == sectionIndex && selection.path == normalizedSelectionPath
    }

    private var isHoverHighlighted: Bool {
        guard let selection = document.hoveredSplitSelection else { return false }
        return selection.sectionIndex == sectionIndex && selection.path == normalizedSelectionPath
    }

    private var isEmptyLeaf: Bool {
        components.isEmpty
    }

    private var backgroundLayer: some View {
        Rectangle()
            .fill(Color.clear)  // StateOverlay handles fills
            .frame(width: containerSize.width, height: containerSize.height)
            .contentShape(Rectangle())
            .overlay {
                // Unified state overlay for hover/selection/drop/pulse
                StateOverlay(
                    elementType: .leaf,
                    isHovered: hoverState.isHovered || isHoverHighlighted,
                    isSelected: isSelectedLeaf,
                    isDropTarget: hoverState.isTargeted && allowDrop
                )
            }
            .overlay {
                Group {
                    if isEmptyLeaf && !isSelectedLeaf && !isHoverHighlighted {
                        EmptyLeafDropFeedback(
                            isHovered: hoverState.isHovered,
                            isTargeted: hoverState.isTargeted,
                            isDropEnabled: allowDrop,
                            color: dropFeedbackColor
                        )
                        .transition(.opacity.combined(with: .scale))
                    }
                }
            }
            .animation(CanvasAnimation.standard, value: hoverState.isHovered)
            .offset(y: hoverState.isHovered ? -1 : 0)
            .animation(CanvasAnimation.quick, value: hoverState.isHovered)
            .onHover(perform: { _ in })
            .modifier(
                DropTargetModifier(
                    allowDrop: allowDrop,
                    onHoverStateChange: { hovering in
                        withAnimation(CanvasAnimation.standard) {
                            hoverState.isHovered = hovering
                        }
                    },
                    onTargetedChange: { targeted in
                        withAnimation(CanvasAnimation.quick) {
                            hoverState.isTargeted = targeted
                        }
                    },
                    handler: { providers, location in
                        handleDrop(providers: providers, at: location)
                    }
                )
            )
            .onTapGesture {
                onLeafSelect?(currentSelection)
            }
            .contextMenu {
                // Context menu visual polish with structured groups and subtle fade
                ContentRectangleContextMenu(
                    contentAlignment: contentAlignment,
                    currentWidthSizingMode: currentWidthSizingMode,
                    currentHeightSizingMode: currentHeightSizingMode,
                    currentRowSizingMode: currentRowSizingMode,
                    currentColumnSizingMode: currentColumnSizingMode,
                    onSetAlignment: onSetAlignment,
                    onSetWidthSizingMode: onSetWidthSizingMode,
                    onSetHeightSizingMode: onSetHeightSizingMode,
                    onSetGridSizingMode: onSetGridSizingMode,
                    onRequestSplit: { direction, count in
                        splitState.direction = direction
                        splitState.splitCount = count
                        splitState.isDialogPresented = true
                    },
                    onRequestRemove: onUnsplit == nil ? nil : {
                        splitState.isRemoveConfirmPresented = true
                    }
                )
            }
            .animation(CanvasAnimation.standard, value: hoverState.isHovered)
    }

    @ViewBuilder
    private var componentLayer: some View {
        if let component = components.first {
            componentView(for: component)
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.9)
                            .combined(with: .opacity)
                            .animation(CanvasAnimation.selectionSpring),
                        removal: .opacity
                            .combined(with: .scale(scale: 0.9))
                            .animation(CanvasAnimation.standard)
                    )
                )
        }
    }

    @ViewBuilder
    private func componentView(for component: InvoiceComponent) -> some View {
        // Use the fresh component from the document to ensure we have the latest style/config
        let currentComponent = document.component(component.id) ?? component
        let usesTableProperties = currentComponent.type.usesTableProperties
        
        ModernComponentView(component: currentComponent)
            .contentShape(Rectangle())
            .onTapGesture { onComponentSelect(currentComponent) }
            .draggable(currentComponent) {
                ModernComponentView(component: currentComponent)
                    .frame(
                        width: usesTableProperties ? nil : min(currentComponent.size.width, containerSize.width),
                        height: min(currentComponent.size.height, containerSize.height)
                    )
                    .padding(4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.windowBackgroundColor))
                            .shadow(radius: 3)
                    )
            }
            .frame(
                width: usesTableProperties ? nil : min(currentComponent.size.width, containerSize.width),
                height: min(currentComponent.size.height, containerSize.height)
            )
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.8)),
                removal: .scale(scale: 0.8).combined(with: .opacity).animation(CanvasAnimation.standard)
            ))
            .pointerStyle(.link)
    }
    




    private func handleDrop(providers: [NSItemProvider], at location: CGPoint) -> Bool {
        guard allowDrop else { return false }
        guard let provider = providers.first,
              provider.hasItemConformingToTypeIdentifier(UTType.invoiceComponent.identifier) else {
            return false
        }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.invoiceComponent.identifier) { data, error in
            guard error == nil, let data else { return }

            DispatchQueue.main.async {
                guard let component = try? JSONDecoder().decode(InvoiceComponent.self, from: data) else { return }
                let componentExistsElsewhere = removeComponentInstances(id: component.id)
                guard !componentStillExists(id: component.id) else { return }

                let componentToAdd: InvoiceComponent = {
                    guard componentExistsElsewhere else {
                        var newComponent = component
                        newComponent.id = UUID()
                        return newComponent
                    }
                    return component
                }()

                onAddComponent(componentToAdd)

                withAnimation(CanvasAnimation.selectionSpring) {
                    statusState.showDropSuccess = true
                }
            }
        }
        return true
    }
    
    private func removeComponentInstances(id: UUID) -> Bool {
        var removedAny = false
        for (sectionIndex, var split) in document.sectionSplits {
            var didRemove = false
            while split.removeComponent(id: id) {
                didRemove = true
                removedAny = true
            }
            if didRemove {
                document.sectionSplits[sectionIndex] = split
            }
        }
        return removedAny
    }
    
    private func componentStillExists(id: UUID) -> Bool {
        document.sectionSplits.contains { (_, split) in
            split.getAllComponents().contains(where: { $0.id == id })
        }
    }
    

private var dropFeedbackColor: Color {
    Color.orange
}
}

private struct ContentRectangleOverlays: View {
    let containerSize: CGSize
    let isProcessingSplit: Bool
    let showSuccessIndicator: Bool
    let showDropSuccess: Bool
    
    var body: some View {
        ZStack {
            if isProcessingSplit {
                ProgressView()
                    .controlSize(.small)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color(NSColor.windowBackgroundColor))
                    )
                    .shadow(radius: 3)
                    .transition(.opacity)
            }
            
            if showSuccessIndicator {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color(NSColor.systemGreen))
                    .font(.title2)
                    .background(
                        Circle()
                            .fill(Color(NSColor.windowBackgroundColor))
                            .frame(width: 32, height: 32)
                    )
                    .shadow(radius: 4)
                    .transition(.scale.combined(with: .opacity))
            }
            
            if showDropSuccess {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(CanvasColor.successFlash)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: containerSize.width, height: containerSize.height)
        .allowsHitTesting(false)
    }
}

private struct EmptyLeafDropFeedback: View {
    let isHovered: Bool
    let isTargeted: Bool
    let isDropEnabled: Bool
    let color: Color
    
    private var strokeStyle: StrokeStyle {
        // On hover or target, we hide the dashed border (stroke is clear)
        // StateOverlay handles the fills and borders for these states
        if (isHovered || isTargeted) && isDropEnabled {
            return StrokeStyle(lineWidth: 0, dash: [])
        }
        return StrokeStyle(lineWidth: 1, dash: [6, 4])
    }
    
    private var strokeColor: Color {
        if (isHovered || isTargeted) && isDropEnabled {
            return Color.clear
        }
        return Color(NSColor.separatorColor).opacity(0.55)
    }
    
    private var fillColor: Color {
        // StateOverlay handles the hover fill, so we don't need double fill here
        return Color.clear
    }
    
    var body: some View {
        Rectangle()
            .stroke(strokeColor, style: strokeStyle)
            .background(
                Rectangle()
                    .fill(fillColor)
            )
            .overlay(alignment: .center) {
                if isDropEnabled && isTargeted {
                    Image("fluent-ic_fluent_add_20_regular", bundle: .module)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(color.opacity(1.0))
                        .scaleEffect(1.0)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(CanvasAnimation.quick, value: isHovered)
    }
}

private struct DropTargetModifier: ViewModifier {
    let allowDrop: Bool
    let onHoverStateChange: (Bool) -> Void
    let onTargetedChange: (Bool) -> Void
    let handler: ([NSItemProvider], CGPoint) -> Bool
    
    @State private var isTargeted: Bool = false
    
    func body(content: Content) -> some View {
        if allowDrop {
            content
                .onHover { hovering in
                    onHoverStateChange(hovering)
                }
                .onDrop(of: [UTType.invoiceComponent], isTargeted: $isTargeted) { providers, location in
                    onTargetedChange(isTargeted)
                    return handler(providers, location)
                }
                .onChange(of: isTargeted) { _, newValue in
                    onTargetedChange(newValue)
                }
        } else {
            content
                .onHover { hovering in
                    onHoverStateChange(hovering)
                }
        }
    }
}

private struct HoverState {
    var isHovered = false
    var isTargeted = false
}

private struct SplitState {
    var isDialogPresented = false
    var direction: SectionSplit.SplitDirection = .horizontal
    var splitCount: Int = 2
    var isProcessing = false
    var isRemoveConfirmPresented = false
}

private struct StatusState {
    var showSuccess = false
    var showDropSuccess = false
}
