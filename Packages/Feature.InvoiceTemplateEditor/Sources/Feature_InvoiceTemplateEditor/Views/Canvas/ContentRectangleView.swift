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

    @State private var isHovered = false
    @State private var showingSplitDialog = false
    @State private var selectedSplitDirection: SectionSplit.SplitDirection = .horizontal
    @State private var splitCount: Int = 2
    @State private var isProcessingSplit = false
    @State private var showSuccessIndicator = false
    @State private var isTargeted = false

    var body: some View {
        let dynamicAlignment = Alignment(
            horizontal: contentAlignment.horizontal.swiftUIAlignment,
            vertical: contentAlignment.vertical.swiftUIAlignment
        )

        let normalizedSelectionPath = leafPath.isEmpty ? [0] : leafPath
        let isSelectedLeaf: Bool = {
            guard let selection = document.selectedSplitSelection else { return false }
            return selection.sectionIndex == sectionIndex && selection.path == normalizedSelectionPath
        }()
        
        let isEmpty = components.isEmpty
        let baseBackgroundColor = isSelectedLeaf
            ? Color(NSColor.controlAccentColor).opacity(0.18)
            : dropHighlightColor

        ZStack(alignment: dynamicAlignment) {
            // Background rectangle with drop destination, constrained to container size
            Rectangle()
                .fill(baseBackgroundColor)
                .frame(width: containerSize.width, height: containerSize.height)
                .contentShape(Rectangle())
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.controlAccentColor), lineWidth: isSelectedLeaf ? 1.5 : 0)
                        .opacity(isSelectedLeaf ? 1 : 0)
                )
                .overlay(
                    // Empty state dashed border
                    Group {
                        if isEmpty && !isSelectedLeaf && !isTargeted {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                .foregroundColor(Color(NSColor.separatorColor))
                                .padding(2)
                        }
                    }
                )
                .animation(.easeInOut(duration: 0.2), value: isHovered)
                .overlay(alignment: .center) {
                    if allowDrop {
                        if isTargeted {
                            Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color.accentColor)
                            .transition(.scale.combined(with: .opacity))
                            .animation(.easeInOut(duration: 0.2), value: isTargeted)
                        } else if isEmpty && !isHovered {
                            Text("Drop Content")
                                .font(.caption)
                                .foregroundColor(Color(NSColor.tertiaryLabelColor))
                        }
                    }
                }
                .modifier(
                    DropTargetModifier(
                        allowDrop: allowDrop,
                        onHoverStateChange: { hovering in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isHovered = hovering
                            }
                        },
                        onTargetedChange: { targeted in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                isTargeted = targeted
                            }
                        },
                        handler: { providers, location in
                            handleDrop(providers: providers, at: location)
                        }
                    )
                )
                .onTapGesture {
                    onLeafSelect?(SectionSplitSelection(sectionIndex: sectionIndex, path: normalizedSelectionPath))
                }
                .contextMenu {
                    // Sizing Submenu - separate Width and Height controls
                    if onSetWidthSizingMode != nil || onSetHeightSizingMode != nil || onSetGridSizingMode != nil {
                        if let onSetWidthSizingMode = onSetWidthSizingMode {
                            // For linear splits - show Width and Height separately
                            Menu("Width Sizing") {
                                ForEach(SectionSplit.SizingMode.allCases, id: \.self) { mode in
                                    Button(action: { onSetWidthSizingMode(mode) }) {
                                        Label(mode.displayName, systemImage: mode.icon)
                                    }
                                }
                            }
                        }
                        if let onSetHeightSizingMode = onSetHeightSizingMode {
                            Menu("Height Sizing") {
                                ForEach(SectionSplit.SizingMode.allCases, id: \.self) { mode in
                                    Button(action: { onSetHeightSizingMode(mode) }) {
                                        Label(mode.displayName, systemImage: mode.icon)
                                    }
                                }
                            }
                        }
                        
                        if let onSetGridSizingMode = onSetGridSizingMode {
                            Menu("Row Sizing") {
                                ForEach(SectionSplit.SizingMode.allCases, id: \.self) { mode in
                                    Button(action: { onSetGridSizingMode(true, mode) }) {
                                        Label(mode.displayName, systemImage: mode.icon)
                                    }
                                }
                            }
                            Menu("Column Sizing") {
                                ForEach(SectionSplit.SizingMode.allCases, id: \.self) { mode in
                                    Button(action: { onSetGridSizingMode(false, mode) }) {
                                        Label(mode.displayName, systemImage: mode.icon)
                                    }
                                }
                            }
                        }
                        Divider()
                    }
                    
                    // Alignment submenu
                    if onSetAlignment != nil {
                        Menu("Content Alignment") {
                            // Horizontal alignment
                            Menu("Horizontal") {
                                Button(action: {
                                    var newAlignment = contentAlignment
                                    newAlignment.horizontal = .leading
                                    onSetAlignment?(newAlignment)
                                }) {
                                    Label("Leading", systemImage: contentAlignment.horizontal == .leading ? "checkmark" : "")
                                }
                                Button(action: {
                                    var newAlignment = contentAlignment
                                    newAlignment.horizontal = .center
                                    onSetAlignment?(newAlignment)
                                }) {
                                    Label("Center", systemImage: contentAlignment.horizontal == .center ? "checkmark" : "")
                                }
                                Button(action: {
                                    var newAlignment = contentAlignment
                                    newAlignment.horizontal = .trailing
                                    onSetAlignment?(newAlignment)
                                }) {
                                    Label("Trailing", systemImage: contentAlignment.horizontal == .trailing ? "checkmark" : "")
                                }
                            }

                            // Vertical alignment
                            Menu("Vertical") {
                                Button(action: {
                                    var newAlignment = contentAlignment
                                    newAlignment.vertical = .top
                                    onSetAlignment?(newAlignment)
                                }) {
                                    Label("Top", systemImage: contentAlignment.vertical == .top ? "checkmark" : "")
                                }
                                Button(action: {
                                    var newAlignment = contentAlignment
                                    newAlignment.vertical = .center
                                    onSetAlignment?(newAlignment)
                                }) {
                                    Label("Center", systemImage: contentAlignment.vertical == .center ? "checkmark" : "")
                                }
                                Button(action: {
                                    var newAlignment = contentAlignment
                                    newAlignment.vertical = .bottom
                                    onSetAlignment?(newAlignment)
                                }) {
                                    Label("Bottom", systemImage: contentAlignment.vertical == .bottom ? "checkmark" : "")
                                }
                            }
                        }

                        Divider()
                    }

                    // Split options
                    Menu("Split") {
                        ForEach(SectionSplit.commonSplits, id: \.id) { splitOption in
                            Button(action: {
                                selectedSplitDirection = splitOption.direction
                                splitCount = splitOption.splitCount
                                showingSplitDialog = true
                            }) {
                                Label(splitOption.direction.displayName, systemImage: splitOption.direction.icon)
                            }
                        }
                    }
                    
                    if let onUnsplit = onUnsplit {
                        Divider()
                        Button(role: .destructive, action: onUnsplit) {
                            Label("Remove Section", systemImage: "trash")
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isHovered)

            // Render the single component allowed per leaf using the outer ZStack's alignment
            if let component = components.first {
                componentView(for: component)
            }


            // Processing overlay
            if isProcessingSplit {
                Rectangle()
                    .fill(Color(NSColor.shadowColor).opacity(0.3))
                    .frame(width: containerSize.width, height: containerSize.height)
                    .overlay(
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(NSColor.labelColor)))
                            Text("Creating Split...")
                                .font(.caption)
                                .foregroundColor(Color(NSColor.labelColor))
                        }
                    )
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: isProcessingSplit)
            }

            // Success indicator
            if showSuccessIndicator {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color(NSColor.systemGreen))
                            .font(.title2)
                            .background(
                                Circle()
                                    .fill(Color(NSColor.windowBackgroundColor))
                                    .frame(width: 32, height: 32)
                            )
                            .shadow(radius: 4)
                        Spacer()
                    }
                    Spacer()
                }
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showSuccessIndicator)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            showSuccessIndicator = false
                        }
                    }
                }
            }
        }
        .frame(width: containerSize.width, height: containerSize.height)
        .clipped()
        .sheet(isPresented: $showingSplitDialog) {
            SplitConfigurationDialog(
                direction: $selectedSplitDirection,
                splitCount: $splitCount,
                onConfirm: { direction, count, rows, columns in
                    // Show processing state
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isProcessingSplit = true
                    }

                    // Simulate processing delay for visual feedback
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onSplit(direction, count, rows, columns)

                        // Hide processing and show success
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isProcessingSplit = false
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                showSuccessIndicator = true
                            }
                        }
                    }
                    showingSplitDialog = false
                },
                onCancel: {
                    showingSplitDialog = false
                }
            )
        }
    }

    @ViewBuilder
    private func componentView(for component: InvoiceComponent) -> some View {
        ModernComponentView(component: component)
            .frame(
                width: min(component.size.width, containerSize.width),
                height: min(component.size.height, containerSize.height)
            )
            .overlay(selectionIndicator(for: component))
            .contentShape(Rectangle())
            .onTapGesture { onComponentSelect(component) }
            .draggable(component)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.4, dampingFraction: 0.8)),
                removal: .scale(scale: 0.8).combined(with: .opacity).animation(.easeInOut(duration: 0.2))
            ))
    }

    private func selectionIndicator(for component: InvoiceComponent) -> some View {
        Group {
            if document.selectedComponentID == component.id {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor.opacity(0.1))
                    )
                    .animation(.easeInOut(duration: 0.2), value: document.selectedComponentID)
            }
        }
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

                var componentExistsElsewhere = false
                for (sectionIndex, var split) in document.sectionSplits {
                    var removed = true
                    var iterations = 0
                    while removed && iterations < 10 {
                        removed = split.removeComponent(id: component.id)
                        if removed {
                            document.sectionSplits[sectionIndex] = split
                            componentExistsElsewhere = true
                            split = document.sectionSplits[sectionIndex] ?? split
                        }
                        iterations += 1
                    }
                }

                let componentStillExists = document.sectionSplits.contains { (_, split) in
                    split.getAllComponents().contains(where: { $0.id == component.id })
                }
                guard !componentStillExists else { return }

                if componentExistsElsewhere {
                    onAddComponent(component)
                } else {
                    var newComponent = component
                    newComponent.id = UUID()
                    onAddComponent(newComponent)
                }
            }
        }
        return true
    }
    
    private var dropHighlightColor: Color {
        guard allowDrop else { return Color.clear }
        if isTargeted {
            return Color.accentColor.opacity(0.25)
        }
        if isHovered {
            return Color.accentColor.opacity(0.12)
        }
        return Color.clear
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