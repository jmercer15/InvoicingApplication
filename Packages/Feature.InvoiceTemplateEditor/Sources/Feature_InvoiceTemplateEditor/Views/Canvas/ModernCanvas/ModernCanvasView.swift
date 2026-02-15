//
//  ModernCanvasView.swift
//  Feature.InvoiceTemplateEditor
//
//  Main canvas view with zoom, pan, and split-based sections
//

import SwiftUI
import Core

private struct PageFramePreferenceKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero || value == .zero {
            value = next
        }
    }
}

struct ModernCanvasView<PaletteContent: View, InspectorContent: View>: View {
    @EnvironmentObject private var workspace: TemplateEditorWorkspaceViewModel
    @EnvironmentObject private var editorViewModel: InvoiceTemplateEditorViewModel
    @EnvironmentObject private var document: InvoiceDocument
    @State private var isDropTargeted = false
    @Binding var zoomScale: CGFloat
    @Binding var viewportOffset: CGSize
    @State private var lastMagnificationValue: CGFloat = 1.0
    @State private var gestureVelocity: CGFloat = 0.0
    @State private var lastGestureTime: Date = Date()
    @State private var isPanning: Bool = false
    @State private var panStartOffset: CGSize = .zero
    @State private var panStartTranslation: CGSize = .zero
    @State private var panVelocity: CGSize = .zero
    @State private var lastPanTime: Date = Date()
    @State private var lastPanTranslation: CGSize = .zero
    @State private var pageFrame: CGRect = .zero
    
    // Side panel content
    let showPalette: Bool
    let showInspector: Bool
    @ViewBuilder let paletteContent: () -> PaletteContent
    @ViewBuilder let inspectorContent: () -> InspectorContent
    
    // Track split configuration for each rectangle section is now in document.sectionHeightRatios
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Glass background
                RoundedRectangle(
                    cornerRadius: 12,
                    style: .continuous
                )
                .fill(Color.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
                
                // Canvas background
                Rectangle()
                    .fill(Color(NSColor.underPageBackgroundColor))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .backgroundExtensionEffect()
                    .padding(.top, 1)

                
                // Canvas with drop zone and zoom
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack(alignment: .center) {
                        // Spacer to force ScrollView to be at least the size of the viewport
                        Color.clear
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                document.deselectAll()
                            }
                        
                        ZStack(alignment: .topLeading) {
                            pageBackground
                            
                            if workspace.showMargins {
                                marginFill
                            }
                            
                            interactiveContent
                            
                            if workspace.showMargins {
                                marginGuides
                            }
                        }
                        .frame(width: A4.width, height: A4.height)
                        .scaleEffect(zoomScale, anchor: .center)
                        .offset(viewportOffset)
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: PageFramePreferenceKey.self,
                                    value: proxy.frame(in: .named("canvasSpace"))
                                )
                            }
                        )
                    }
                    .canvasGestures(
                        zoomScale: $zoomScale,
                        viewportOffset: $viewportOffset,
                        lastMagnificationValue: $lastMagnificationValue,
                        gestureVelocity: $gestureVelocity,
                        lastGestureTime: $lastGestureTime,
                        isPanning: $isPanning,
                        panStartOffset: $panStartOffset,
                        panStartTranslation: $panStartTranslation,
                        panVelocity: $panVelocity,
                        lastPanTime: $lastPanTime,
                        lastPanTranslation: $lastPanTranslation,
                        geometry: geometry
                    )
                }
                .coordinateSpace(name: "canvasSpace")
                .background(Color.clear)
                
                // Pan indicator overlay (subtle visual feedback)
                if isPanning {
                    VStack {
                        HStack {
                            Spacer()
                            Text("Panning")
                                .font(.caption)
                        .fontWeight(.semibold)
                .foregroundColor(Color.secondary)
                                .padding(8)
                                .background(Color.clear)
                                .cornerRadius(6)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(.top, 8)
                    .allowsHitTesting(false)
                }
                

                
                if editorViewModel.showRulers && pageFrame != .zero {
                    // Calculate the visual frame of the page (after zoom and offset)
                    // The pageFrame from GeometryReader is the layout frame (unzoomed, unoffset) relative to the canvasSpace
                    // But since we moved canvasSpace to the ScrollView content, pageFrame IS the correct layout frame.
                    // However, scaleEffect and offset are visual-only transforms that happen AFTER layout.
                    // So we need to manually apply them to get the visual frame.
                    
                    let scaledSize = CGSize(width: A4.width * zoomScale, height: A4.height * zoomScale)
                    let center = CGPoint(x: pageFrame.midX, y: pageFrame.midY)
                    let visualOrigin = CGPoint(
                        x: center.x - (scaledSize.width / 2) + viewportOffset.width,
                        y: center.y - (scaledSize.height / 2) + viewportOffset.height
                    )
                    let visualPageFrame = CGRect(origin: visualOrigin, size: scaledSize)
                    
                    RulersOverlayView(
                        containerSize: geometry.size,
                        pageFrame: visualPageFrame,
                        pageSize: CGSize(width: A4.width, height: A4.height),
                        zoomScale: zoomScale,
                        margins: document.margins,
                        showMargins: workspace.showMargins,
                        unit: workspace.rulerUnit
                    )
                    .allowsHitTesting(false)
                    
                    if workspace.showMargins {
                        MarginHandlesOverlay(
                            pageFrame: visualPageFrame,
                            zoomScale: zoomScale,
                            margins: document.margins,
                            unit: workspace.rulerUnit,
                            onMarginChange: updateMargin(edge:value:commit:)
                        )
                    }
                }
                
                // Side panels overlay
                if showPalette || showInspector {
                    let rulerPadding: CGFloat = 30 + 8 // ruler height + outer padding
                    HStack(alignment: .top, spacing: 0) {
                        if showPalette {
                            paletteContent()
                        }
                        Spacer()
                        if showInspector {
                            inspectorContent()
                        }
                    }
                    .frame(
                        maxHeight: geometry.size.height - 2 * rulerPadding,
                        alignment: .top
                    )
                    .padding(rulerPadding)
                }
            }
            .onPreferenceChange(PageFramePreferenceKey.self) { frame in
                DispatchQueue.main.async {
                    self.pageFrame = frame
                }
            }
        }
        .clipShape(
            RoundedRectangle(
                cornerRadius: 12,
                style: .continuous
            )
        )
        .padding(8)
    }
    
    private var pageBackground: some View {
        Rectangle()
            .fill(Color.white)
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 0)
            .frame(width: A4.width, height: A4.height)
            .overlay(
                GridOverlay()
                    .opacity(0.03)
            )
            .onTapGesture {
                document.deselectAll()
            }
    }
    
    private var marginFill: some View {
        MarginFillOverlay(
            pageSize: CGSize(width: A4.width, height: A4.height),
            margins: document.margins
        )
        .frame(width: A4.width, height: A4.height)
        .allowsHitTesting(false)
    }
    
    private var interactiveContent: some View {
        let margins = document.margins
        let contentSize = CGSize(
            width: A4.width - margins.left - margins.right,
            height: A4.height - margins.top - margins.bottom
        )
        
        return RatioBasedLayout(
            ratios: document.sectionHeightRatios,
            direction: .vertical,
            containerSize: contentSize,
            onResize: { sectionIndex, delta in
                guard sectionIndex < document.sectionHeightRatios.count - 1 else { return }
                var updatedRatios = document.sectionHeightRatios
                let (newCurrentRatio, newNextRatio) = safeResizeRatios(
                    delta: delta,
                    containerSize: contentSize.height,
                    currentRatio: updatedRatios[sectionIndex],
                    nextRatio: updatedRatios[sectionIndex + 1]
                )
                updatedRatios[sectionIndex] = newCurrentRatio
                updatedRatios[sectionIndex + 1] = newNextRatio
                updatedRatios[sectionIndex] = newCurrentRatio
                updatedRatios[sectionIndex + 1] = newNextRatio
                document.sectionHeightRatios = updatedRatios
            },
            onResizeStart: {
                document.saveStateForUndo(actionName: "Resize Section")
            }
        ) { index, sectionSize in
            SplittableRectangleView(
                split: document.sectionSplits[index],
                leafComponents: [],
                containerSize: sectionSize,
                sectionIndex: index,
                nodePath: [],
                childIndex: index,
                childPadding: .zero,
                parentAlignment: document.sectionSplits[index]?.getAlignment(forChild: 0) ?? .default,
                context: SplitInteractionContext(
                    onDrop: { _, _ in false },
                    onSplitChild: { childIndex, direction, count, rows, columns in
                        if var split = document.sectionSplits[index] {
                            
                            document.saveStateForUndo(actionName: "Split Section")
                            if direction == .grid, let rows = rows, let columns = columns {
                                split.splitChild(at: childIndex, direction: direction, splitCount: count, gridRows: rows, gridColumns: columns)
                            } else {
                                split.splitChild(at: childIndex, direction: direction, splitCount: count)
                            }
                            document.sectionSplits[index] = split
                        } else {
                            if direction == .grid, let rows = rows, let columns = columns {
                                let newSplit = SectionSplit(gridRows: rows, gridColumns: columns)
                                document.sectionSplits[index] = newSplit
                            } else {
                                let newSplit = SectionSplit(direction: direction, splitCount: count)
                                document.sectionSplits[index] = newSplit
                            }
                        }
                    },
                    onUnsplitChild: { childIndex in
                        if var split = document.sectionSplits[index] {
                            document.saveStateForUndo(actionName: "Unsplit Section")
                            split.unsplitChild(at: childIndex)
                            document.sectionSplits[index] = split
                        }
                    },
                    onResize: { childIndex, delta in
                        // Top-level resize is handled by RatioBasedLayout above
                    },
                    onResizeStart: { _ in
                        document.saveStateForUndo(actionName: "Resize Section")
                    },
                    onUpdateSplit: { updatedSplit, actionName in
                        if let actionName = actionName {
                            document.saveStateForUndo(actionName: actionName)
                        }
                        document.sectionSplits[index] = updatedSplit
                    },
                    onAddComponent: { childIndex, component in
                        let actionName = "Add \(component.type.rawValue)"
                        if var split = document.sectionSplits[index] {
                            document.saveStateForUndo(actionName: actionName)
                            split.addComponent(component, toChild: childIndex)
                            document.sectionSplits[index] = split
                        } else {
                            document.saveStateForUndo(actionName: actionName)
                            var newSplit = SectionSplit(direction: .horizontal, splitCount: 1)
                            newSplit.addComponent(component, toChild: 0)
                            document.sectionSplits[index] = newSplit
                        }
                    },
                    onSetLabel: { childIndex, label in
                        if var split = document.sectionSplits[index] {
                            if let label = label {
                                document.saveStateForUndo(actionName: "Change Split Label")
                                split.setLabel(label, forChild: childIndex)
                            } else {
                                document.saveStateForUndo(actionName: "Change Split Label")
                                split.removeLabel(forChild: childIndex)
                            }
                            document.sectionSplits[index] = split
                        }
                    },
                    onReorderChildren: nil,
                    onComponentSelect: { component in
                        document.selectComponent(component.id)
                    },
                    onLeafSelect: { selection in
                        document.selectSplitSelection(selection)
                    },
                    onSetWidthSizingMode: { childIndex, mode in
                        if var split = document.sectionSplits[index] {
                            document.saveStateForUndo(actionName: "Change Width Mode")
                            split.setWidthSizingMode(mode, forChild: childIndex)
                            document.sectionSplits[index] = split
                        }
                    },
                    onSetHeightSizingMode: { childIndex, mode in
                        if var split = document.sectionSplits[index] {
                            document.saveStateForUndo(actionName: "Change Height Mode")
                            split.setHeightSizingMode(mode, forChild: childIndex)
                            document.sectionSplits[index] = split
                        }
                    },
                    onSetGridSizingMode: { childIndex, isRow, mode in
                        if var split = document.sectionSplits[index] {
                            let (row, column) = split.rowColumn(for: childIndex)
                            document.saveStateForUndo(actionName: "Change Grid Sizing")
                            if isRow {
                                split.setRowSizingMode(mode, forRow: row)
                            } else {
                                split.setColumnSizingMode(mode, forColumn: column)
                            }
                            document.sectionSplits[index] = split
                        }
                    },
                    currentWidthSizingMode: nil,
                    currentHeightSizingMode: nil,
                    currentRowSizingMode: nil,
                    currentColumnSizingMode: nil,
                    showDividers: workspace.showDividers
                )
            )
            .frame(width: sectionSize.width, height: sectionSize.height)
        }
        .frame(width: contentSize.width, height: contentSize.height, alignment: .topLeading)
        .padding(.leading, margins.left)
        .padding(.trailing, margins.right)
        .padding(.top, margins.top)
        .padding(.bottom, margins.bottom)
        .clipShape(Rectangle())
        .zIndex(1)
    }
    
    private var marginGuides: some View {
        MarginGuideOverlay(
            pageSize: CGSize(width: A4.width, height: A4.height),
            margins: document.margins
        )
        .allowsHitTesting(false)
        .zIndex(3)
    }

    private func updateMargin(edge: InvoiceDocument.MarginEdge, value: CGFloat, commit: Bool) {
        document.updateMargin(edge: edge, to: value, recordUndo: commit)
        
        let updated = document.margins
        workspace.marginLeftStr = formattedMargin(updated.left)
        workspace.marginRightStr = formattedMargin(updated.right)
        workspace.marginTopStr = formattedMargin(updated.top)
        workspace.marginBottomStr = formattedMargin(updated.bottom)
    }
    
    private func formattedMargin(_ value: CGFloat) -> String {
        String(format: "%.0f", value)
    }
    
}

private struct MarginFillOverlay: View {
    let pageSize: CGSize
    let margins: InvoiceDocument.DocumentMargins
    
    private var fillColor: Color {
        Color.clear
    }
    
    var body: some View {
        let left = max(0, min(margins.left, pageSize.width))
        let right = max(0, min(margins.right, pageSize.width))
        let top = max(0, min(margins.top, pageSize.height))
        let bottom = max(0, min(margins.bottom, pageSize.height))
        let contentWidth = max(pageSize.width - left - right, 0)
        return Path { path in
            if left > 0 {
                path.addRect(CGRect(x: 0, y: 0, width: left, height: pageSize.height))
            }
            if right > 0 {
                path.addRect(CGRect(x: pageSize.width - right, y: 0, width: right, height: pageSize.height))
            }
            if top > 0 && contentWidth > 0 {
                path.addRect(CGRect(x: left, y: 0, width: contentWidth, height: top))
            }
            if bottom > 0 && contentWidth > 0 {
                path.addRect(CGRect(x: left, y: pageSize.height - bottom, width: contentWidth, height: bottom))
            }
        }
        .fill(fillColor)
    }
}

private struct MarginGuideOverlay: View {
    let pageSize: CGSize
    let margins: InvoiceDocument.DocumentMargins
    
    private var guideColor: Color {
        Color.accentColor.opacity(0.5)
    }
    
    var body: some View {
        Path { path in
            let left = max(0, min(margins.left, pageSize.width))
            let right = max(0, min(margins.right, pageSize.width))
            let top = max(0, min(margins.top, pageSize.height))
            let bottom = max(0, min(margins.bottom, pageSize.height))
            
            path.move(to: CGPoint(x: left, y: 0))
            path.addLine(to: CGPoint(x: left, y: pageSize.height))
            
            path.move(to: CGPoint(x: pageSize.width - right, y: 0))
            path.addLine(to: CGPoint(x: pageSize.width - right, y: pageSize.height))
            
            path.move(to: CGPoint(x: 0, y: top))
            path.addLine(to: CGPoint(x: pageSize.width, y: top))
            
            path.move(to: CGPoint(x: 0, y: pageSize.height - bottom))
            path.addLine(to: CGPoint(x: pageSize.width, y: pageSize.height - bottom))
        }
        .stroke(guideColor, style: StrokeStyle(lineWidth: 0.5, dash: [6, 4]))
        .overlay(
            Group {
                marker(at: CGPoint(x: max(0, min(margins.left, pageSize.width)), y: max(0, min(margins.top, pageSize.height))))
                marker(at: CGPoint(x: max(0, min(margins.left, pageSize.width)), y: pageSize.height - max(0, min(margins.bottom, pageSize.height))))
                marker(at: CGPoint(x: pageSize.width - max(0, min(margins.right, pageSize.width)), y: max(0, min(margins.top, pageSize.height))))
                marker(at: CGPoint(x: pageSize.width - max(0, min(margins.right, pageSize.width)), y: pageSize.height - max(0, min(margins.bottom, pageSize.height))))
            }
        )
    }
    
    private func marker(at point: CGPoint) -> some View {
        Circle()
            .fill(Color.accentColor.opacity(0.7))
            .frame(width: 5, height: 5)
            .shadow(color: Color.accentColor.opacity(0.25), radius: 3, x: 0, y: 1)
            .position(point)
    }
}

private struct RulersOverlayView: View {
    let containerSize: CGSize
    let pageFrame: CGRect
    let pageSize: CGSize
    let zoomScale: CGFloat
    let margins: InvoiceDocument.DocumentMargins
    let showMargins: Bool
    let unit: RulerUnit
    
    private let rulerThickness: CGFloat = 30
    
    var body: some View {
        let width = max(containerSize.width, 0)
        let height = max(containerSize.height, 0)
        let topY = rulerThickness / 2
        let bottomY = height - rulerThickness / 2
        let leftX = rulerThickness / 2
        let rightX = width - rulerThickness / 2
        let horizontalZeroOffset = pageFrame.minX
        let verticalZeroOffset = pageFrame.minY
        let horizontalMarginEnd = pageSize.width - margins.right
        let verticalMarginEnd = pageSize.height - margins.bottom
        
        return ZStack {
            // Top ruler
            RulerView(
                orientation: .horizontal,
                edge: .top,
                length: width,
                unit: unit,
                cursorPosition: nil,
                showCursorIndicator: false,
                zeroOffset: horizontalZeroOffset,
                selectionStart: nil,
                selectionEnd: nil,
                marginStart: showMargins ? margins.left : nil,
                marginEnd: showMargins ? horizontalMarginEnd : nil,
                zoom: zoomScale,
                scrollOffset: 0
            )
            .frame(width: width, height: rulerThickness)
            .position(
                x: width / 2,
                y: topY
            )
            
            // Bottom ruler
            RulerView(
                orientation: .horizontal,
                edge: .bottom,
                length: width,
                unit: unit,
                cursorPosition: nil,
                showCursorIndicator: false,
                zeroOffset: horizontalZeroOffset,
                selectionStart: nil,
                selectionEnd: nil,
                marginStart: showMargins ? margins.left : nil,
                marginEnd: showMargins ? horizontalMarginEnd : nil,
                zoom: zoomScale,
                scrollOffset: 0
            )
            .frame(width: width, height: rulerThickness)
            .position(
                x: width / 2,
                y: bottomY
            )
            
            // Left ruler
            RulerView(
                orientation: .vertical,
                edge: .leading,
                length: height,
                unit: unit,
                cursorPosition: nil,
                showCursorIndicator: false,
                zeroOffset: verticalZeroOffset,
                selectionStart: nil,
                selectionEnd: nil,
                marginStart: showMargins ? margins.top : nil,
                marginEnd: showMargins ? verticalMarginEnd : nil,
                zoom: zoomScale,
                scrollOffset: 0
            )
            .frame(width: rulerThickness, height: height)
            .position(
                x: leftX,
                y: height / 2
            )
            
            // Right ruler
            RulerView(
                orientation: .vertical,
                edge: .trailing,
                length: height,
                unit: unit,
                cursorPosition: nil,
                showCursorIndicator: false,
                zeroOffset: verticalZeroOffset,
                selectionStart: nil,
                selectionEnd: nil,
                marginStart: showMargins ? margins.top : nil,
                marginEnd: showMargins ? verticalMarginEnd : nil,
                zoom: zoomScale,
                scrollOffset: 0
            )
            .frame(width: rulerThickness, height: height)
            .position(
                x: rightX,
                y: height / 2
            )
            
            // Corner squares
            Rectangle()
                .fill(Color.elevatedSurface)
                .frame(width: rulerThickness, height: rulerThickness)
                .overlay(
                    Rectangle()
                        .stroke(Color.strongOutline, lineWidth: 0.6)
                )
                .overlay(
                    Rectangle()
                        .stroke(Color.primaryOutline.opacity(0.6), lineWidth: 1)
                        .padding(2)
                )
                .position(
                    x: leftX,
                    y: topY
                )
            
            Rectangle()
                .fill(Color.elevatedSurface)
                .frame(width: rulerThickness, height: rulerThickness)
                .overlay(
                    Rectangle()
                        .stroke(Color.strongOutline, lineWidth: 0.6)
                )
                .position(
                    x: rightX,
                    y: topY
                )
            
            Rectangle()
                .fill(Color.elevatedSurface)
                .frame(width: rulerThickness, height: rulerThickness)
                .overlay(
                    Rectangle()
                        .stroke(Color.strongOutline, lineWidth: 0.6)
                )
                .position(
                    x: leftX,
                    y: bottomY
                )
            
            Rectangle()
                .fill(Color.elevatedSurface)
                .frame(width: rulerThickness, height: rulerThickness)
                .overlay(
                    Rectangle()
                        .stroke(Color.strongOutline, lineWidth: 0.6)
                )
                .position(
                    x: rightX,
                    y: bottomY
                )
        }
    }
}

private struct MarginHandlesOverlay: View {
    let pageFrame: CGRect
    let zoomScale: CGFloat
    let margins: InvoiceDocument.DocumentMargins
    let unit: RulerUnit
    let onMarginChange: (InvoiceDocument.MarginEdge, CGFloat, Bool) -> Void
    
    @State private var dragStart: [InvoiceDocument.MarginEdge: CGFloat] = [:]
    @State private var activeValues: [InvoiceDocument.MarginEdge: CGFloat] = [:]
    
    private let handleSize: CGFloat = 16
    private let snapEnabled: Bool = true
    private let snapInterval: CGFloat = 5
    
    private enum HandleAxis {
        case horizontal
        case vertical
    }
    
    var body: some View {
        ZStack {
            horizontalHandles
            verticalHandles
        }
        .allowsHitTesting(true)
    }
    
    private var horizontalHandles: some View {
        let leftPosition = pageFrame.minX + margins.left * zoomScale
        let rightPosition = pageFrame.maxX - margins.right * zoomScale
        let yPosition = pageFrame.minY - handleSize / 2 - 2
        
        return ZStack {
            marginHandle(
                edge: .left,
                direction: .down,
                position: CGPoint(x: leftPosition, y: yPosition),
                axis: .horizontal,
                multiplier: 1
            )
            valueLabel(for: .left, at: CGPoint(x: leftPosition, y: yPosition - 18))
            
            marginHandle(
                edge: .right,
                direction: .down,
                position: CGPoint(x: rightPosition, y: yPosition),
                axis: .horizontal,
                multiplier: -1
            )
            valueLabel(for: .right, at: CGPoint(x: rightPosition, y: yPosition - 18))
        }
    }
    
    private var verticalHandles: some View {
        let xPosition = pageFrame.minX - handleSize / 2 - 2
        let topPosition = pageFrame.minY + margins.top * zoomScale
        let bottomPosition = pageFrame.maxY - margins.bottom * zoomScale
        
        return ZStack {
            marginHandle(
                edge: .top,
                direction: .right,
                position: CGPoint(x: xPosition, y: topPosition),
                axis: .vertical,
                multiplier: 1
            )
            valueLabel(for: .top, at: CGPoint(x: xPosition - 6, y: topPosition))
            
            marginHandle(
                edge: .bottom,
                direction: .right,
                position: CGPoint(x: xPosition, y: bottomPosition),
                axis: .vertical,
                multiplier: -1
            )
            valueLabel(for: .bottom, at: CGPoint(x: xPosition - 6, y: bottomPosition))
        }
    }
    
    private func marginHandle(
        edge: InvoiceDocument.MarginEdge,
        direction: MarginHandle.Direction,
        position: CGPoint,
        axis: HandleAxis,
        multiplier: CGFloat
    ) -> some View {
        MarginHandle(direction: direction)
            .frame(width: handleSize, height: handleSize)
            .position(position)
            .accessibilityLabel("\(edge.accessibilityName) margin handle")
            .accessibilityHint("Drag to adjust the \(edge.accessibilityName.lowercased()) margin")
            .gesture(dragGesture(for: edge, axis: axis, multiplier: multiplier))
    }
    
    private func dragGesture(
        for edge: InvoiceDocument.MarginEdge,
        axis: HandleAxis,
        multiplier: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let initial = dragStart[edge] ?? marginValue(for: edge)
                dragStart[edge] = initial
                let delta = translation(for: value.translation, axis: axis) * multiplier / zoomScale
                    let updated = applySnapIfNeeded(initial + delta)
                    activeValues[edge] = updated
                    onMarginChange(edge, updated, false)
            }
            .onEnded { value in
                let initial = dragStart[edge] ?? marginValue(for: edge)
                let delta = translation(for: value.translation, axis: axis) * multiplier / zoomScale
                    let updated = applySnapIfNeeded(initial + delta)
                    onMarginChange(edge, updated, true)
                    activeValues.removeValue(forKey: edge)
                dragStart[edge] = nil
            }
    }
    
    private func marginValue(for edge: InvoiceDocument.MarginEdge) -> CGFloat {
        switch edge {
        case .left:
            return margins.left
        case .right:
            return margins.right
        case .top:
            return margins.top
        case .bottom:
            return margins.bottom
        }
    }
    
    private func translation(for value: CGSize, axis: HandleAxis) -> CGFloat {
        switch axis {
        case .horizontal:
            return value.width
        case .vertical:
            return value.height
        }
    }
    
    private func applySnapIfNeeded(_ value: CGFloat) -> CGFloat {
        guard snapEnabled, snapInterval > 0 else { return value }
        let snapped = (value / snapInterval).rounded() * snapInterval
        return snapped
    }
    
    private func valueLabel(for edge: InvoiceDocument.MarginEdge, at position: CGPoint) -> some View {
        guard let value = activeValues[edge] else { return AnyView(EmptyView()) }
        let formatted = formattedMargin(value)
        return AnyView(
            Text(formatted)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
                .foregroundColor(Color(NSColor.labelColor))
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 1)
                .position(position)
                .allowsHitTesting(false)
        )
    }
    
    private func formattedMargin(_ value: CGFloat) -> String {
        switch unit {
        case .points:
            return String(format: "%.0f pt", value)
        case .millimeters:
            return String(format: "%.1f mm", value / 2.83465)
        case .inches:
            return String(format: "%.2f in", value / 72.0)
        }
    }
}

private extension InvoiceDocument.MarginEdge {
    var accessibilityName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .top: return "Top"
        case .bottom: return "Bottom"
        }
    }
}

private struct MarginHandle: View {
    enum Direction {
        case up, down, left, right
        
        var rotation: Angle {
            switch self {
            case .up: return .degrees(180)
            case .down: return .degrees(0)
            case .left: return .degrees(90)
            case .right: return .degrees(-90)
            }
        }
    }
    
    let direction: Direction
    
    var body: some View {
        TriangleHandleShape()
            .fill(Color.accentColor)
            .overlay(
                TriangleHandleShape()
                    .stroke(Color.accentColor.opacity(0.8), lineWidth: 1)
            )
            .rotationEffect(direction.rotation)
            .shadow(color: Color.primaryShadow.opacity(0.25), radius: 2, x: 0, y: 1)
            .contentShape(Rectangle())
    }
}

private struct TriangleHandleShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct GridOverlay: View {
    private let spacing: CGFloat = 20
    private let lineWidth: CGFloat = 0.5
    
    var body: some View {
        Canvas { context, size in
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(Color.primary.opacity(0.1)), lineWidth: lineWidth)
        }
    }
}
