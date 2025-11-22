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

struct ModernCanvasView: View {
    @EnvironmentObject private var workspace: TemplateEditorWorkspaceViewModel
    @EnvironmentObject private var editorViewModel: InvoiceTemplateEditorViewModel
    @EnvironmentObject private var document: InvoiceDocument
    @State private var isDropTargeted = false
    @State private var zoomScale: CGFloat = 1.0
    @State private var viewportOffset: CGSize = .zero
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
    
    // Track split configuration for each rectangle section
    @State private var sectionHeightRatios: [CGFloat] = [1.0] // Single root section initially
    
    // Helper function for smooth boundary resistance with exponential decay
    nonisolated private func constrainWithResistance(_ value: CGFloat, min: CGFloat, max: CGFloat, resistance: CGFloat) -> CGFloat {
        if value < min {
            let excess = min - value
            // Exponential resistance curve for more natural feel
            let resistanceFactor = 1.0 - pow(resistance, excess / 50.0)
            return min - excess * resistanceFactor
        } else if value > max {
            let excess = value - max
            // Exponential resistance curve for more natural feel
            let resistanceFactor = 1.0 - pow(resistance, excess / 50.0)
            return max + excess * resistanceFactor
        }
        return value
    }
    
    // Helper function to calculate optimal pan boundaries
    nonisolated private func calculatePanBoundaries(geometrySize: CGSize, zoomScale: CGFloat) -> (minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) {
        let canvasSize = CGSize(width: A4.width, height: A4.height)
        let scaledCanvasSize = CGSize(
            width: canvasSize.width * zoomScale,
            height: canvasSize.height * zoomScale
        )
        
        // Only apply boundaries when zoomed in enough to have overflow
        let hasOverflowX = scaledCanvasSize.width > geometrySize.width
        let hasOverflowY = scaledCanvasSize.height > geometrySize.height
        
        let maxOffsetX = hasOverflowX ? (scaledCanvasSize.width - geometrySize.width) / 2 : 0
        let maxOffsetY = hasOverflowY ? (scaledCanvasSize.height - geometrySize.height) / 2 : 0
        
        return (
            minX: hasOverflowX ? -maxOffsetX : 0,
            maxX: hasOverflowX ? maxOffsetX : 0,
            minY: hasOverflowY ? -maxOffsetY : 0,
            maxY: hasOverflowY ? maxOffsetY : 0
        )
    }
    
    // Helper function to apply momentum-based panning (simplified to avoid concurrency issues)
    private func applyMomentum(geometry: GeometryProxy) {
        // For now, just apply a small momentum offset without complex animation
        // This avoids concurrency issues while still providing some momentum feel
        let momentumFactor: CGFloat = 0.3
        let momentumOffset = CGSize(
            width: panVelocity.width * momentumFactor,
            height: panVelocity.height * momentumFactor
        )
        
        let newOffset = CGSize(
            width: viewportOffset.width + momentumOffset.width,
            height: viewportOffset.height + momentumOffset.height
        )
        
        // Apply boundary constraints
        let boundaries = calculatePanBoundaries(geometrySize: geometry.size, zoomScale: zoomScale)
        let constrainedOffsetX = constrainWithResistance(
            newOffset.width,
            min: boundaries.minX,
            max: boundaries.maxX,
            resistance: 0.1
        )
        
        let constrainedOffsetY = constrainWithResistance(
            newOffset.height,
            min: boundaries.minY,
            max: boundaries.maxY,
            resistance: 0.1
        )
        
        withAnimation(.easeOut(duration: 0.3)) {
            viewportOffset = CGSize(width: constrainedOffsetX, height: constrainedOffsetY)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                // Background
                Rectangle()
                    .fill(.windowBackground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Canvas with drop zone and zoom
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack(alignment: .topLeading) {
                        // Layer 1: Page background with shadow
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: A4.width, height: A4.height)
                            .shadow(color: Color.subtleShadow, radius: 8, x: 0, y: 4)
                        
                        // Layer 2: Margin fill overlay (background only - visual indicator, does not affect layout)
                        if workspace.showMargins {
                            MarginFillOverlay(
                                pageSize: CGSize(width: A4.width, height: A4.height),
                                margins: document.margins
                            )
                            .frame(width: A4.width, height: A4.height)
                            .allowsHitTesting(false)
                        }
                        
                        // Layer 3: Interactive sections (highest priority for interactions)
                        let margins = document.margins
                        let contentSize = CGSize(
                            width: A4.width - margins.left - margins.right,
                            height: A4.height - margins.top - margins.bottom
                        )
                        
                        RatioBasedLayout(
                            ratios: sectionHeightRatios,
                            direction: .vertical,
                            containerSize: contentSize,
                            onResize: { sectionIndex, delta in
                                guard sectionIndex < sectionHeightRatios.count - 1 else { return }
                                var updatedRatios = sectionHeightRatios
                                let (newCurrentRatio, newNextRatio) = safeResizeRatios(
                                    delta: delta,
                                    containerSize: contentSize.height,
                                    currentRatio: updatedRatios[sectionIndex],
                                    nextRatio: updatedRatios[sectionIndex + 1]
                                )
                                updatedRatios[sectionIndex] = newCurrentRatio
                                updatedRatios[sectionIndex + 1] = newNextRatio
                                sectionHeightRatios = updatedRatios
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
                                            split.unsplitChild(at: childIndex)
                                            document.sectionSplits[index] = split
                                        }
                                    },
                                    onResize: { childIndex, delta in
                                        // Top-level resize is handled by RatioBasedLayout above
                                    },
                                    onUpdateSplit: { updatedSplit in
                                        document.sectionSplits[index] = updatedSplit
                                    },
                                    onAddComponent: { childIndex, component in
                                        if var split = document.sectionSplits[index] {
                                            split.addComponent(component, toChild: childIndex)
                                            document.sectionSplits[index] = split
                                        } else {
                                            var newSplit = SectionSplit(direction: .horizontal, splitCount: 1)
                                            newSplit.addComponent(component, toChild: 0)
                                            document.sectionSplits[index] = newSplit
                                        }
                                    },
                                    onSetLabel: { childIndex, label in
                                        if var split = document.sectionSplits[index] {
                                            if let label = label {
                                                split.setLabel(label, forChild: childIndex)
                                            } else {
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
                                            split.setWidthSizingMode(mode, forChild: childIndex)
                                            document.sectionSplits[index] = split
                                        }
                                    },
                                    onSetHeightSizingMode: { childIndex, mode in
                                        if var split = document.sectionSplits[index] {
                                            split.setHeightSizingMode(mode, forChild: childIndex)
                                            document.sectionSplits[index] = split
                                        }
                                    },
                                    onSetGridSizingMode: { childIndex, isRow, mode in
                                        if var split = document.sectionSplits[index] {
                                            let (row, column) = split.rowColumn(for: childIndex)
                                            if isRow {
                                                split.setRowSizingMode(mode, forRow: row)
                                            } else {
                                                split.setColumnSizingMode(mode, forColumn: column)
                                            }
                                            document.sectionSplits[index] = split
                                        }
                                    }
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
                        .zIndex(1) // Ensure sections are above background but below components
                        
                        
                        // Layer 4: Margin guide overlay (visual guides only - does not affect layout)
                        if workspace.showMargins {
                            MarginGuideOverlay(
                                pageSize: CGSize(width: A4.width, height: A4.height),
                                margins: document.margins
                            )
                            .allowsHitTesting(false)
                            .zIndex(3) // Visual guides on top
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
                    .gesture(
                        SimultaneousGesture(
                            // Magnification gesture for zoom
                            MagnificationGesture()
                                .onChanged { value in
                                    let currentTime = Date()
                                    let timeDelta = currentTime.timeIntervalSince(lastGestureTime)
                                    
                                    // Calculate gesture velocity for adaptive dampening
                                    if timeDelta > 0 {
                                        let deltaValue = value - lastMagnificationValue
                                        gestureVelocity = abs(deltaValue) / CGFloat(timeDelta)
                                    }
                                    
                                    // Logarithmic dampening based on current zoom level
                                    let logDampening = log(zoomScale + 0.5) / log(2.0)
                                    let adaptiveDampening = max(0.1, 0.5 - logDampening * 0.2)
                                    
                                    // Velocity-based dampening (faster gestures = less dampening)
                                    let velocityDampening = min(1.0, max(0.3, 1.0 - gestureVelocity * 2.0))
                                    
                                    // Combined dampening factor
                                    let combinedDampening = adaptiveDampening * velocityDampening
                                    
                                    // Apply logarithmic scaling for more natural feel
                                    let rawDelta = value - lastMagnificationValue
                                    let dampenedDelta = rawDelta * combinedDampening
                                    let newScale = zoomScale + dampenedDelta
                                    
                                    // Apply exponential resistance near boundaries
                                    let minScale: CGFloat = 0.25
                                    let maxScale: CGFloat = 4.0
                                    let resistanceFactor: CGFloat = 0.3
                                    
                                    let finalScale: CGFloat
                                    if newScale < minScale {
                                        let excess = minScale - newScale
                                        finalScale = minScale - excess * resistanceFactor
                                    } else if newScale > maxScale {
                                        let excess = newScale - maxScale
                                        finalScale = maxScale + excess * resistanceFactor
                                    } else {
                                        finalScale = newScale
                                    }
                                    
                                    let oldScale = zoomScale
                                    zoomScale = max(minScale, min(finalScale, maxScale))
                                    
                                    // Adjust viewport offset to maintain zoom center point
                                    if zoomScale != oldScale {
                                        let scaleRatio = zoomScale / oldScale
                                        viewportOffset = CGSize(
                                            width: viewportOffset.width * scaleRatio,
                                            height: viewportOffset.height * scaleRatio
                                        )
                                    }
                                    
                                    lastMagnificationValue = value
                                    lastGestureTime = currentTime
                                }
                                .onEnded { _ in
                                    // Smart snapping to common zoom levels with hysteresis
                                    let snapThreshold: CGFloat = 0.1
                                    
                                    if abs(zoomScale - 0.5) < snapThreshold {
                                        zoomScale = 0.5
                                    } else if abs(zoomScale - 1.0) < snapThreshold {
                                        zoomScale = 1.0
                                    } else if abs(zoomScale - 1.5) < snapThreshold {
                                        zoomScale = 1.5
                                    } else if abs(zoomScale - 2.0) < snapThreshold {
                                        zoomScale = 2.0
                                    } else if abs(zoomScale - 3.0) < snapThreshold {
                                        zoomScale = 3.0
                                    }
                                    
                                    // Reset gesture tracking
                                    lastMagnificationValue = 1.0
                                    gestureVelocity = 0.0
                                },
                            
                            // Drag gesture for panning when zoomed
                            DragGesture()
                                .onChanged { value in
                                    let currentTime = Date()
                                    
                                    if !isPanning {
                                        isPanning = true
                                        panStartOffset = viewportOffset
                                        panStartTranslation = value.translation
                                        lastPanTime = currentTime
                                        lastPanTranslation = value.translation
                                        panVelocity = .zero
                                    }
                                    
                                    // Calculate velocity for momentum and feedback
                                    let timeDelta = currentTime.timeIntervalSince(lastPanTime)
                                    if timeDelta > 0 {
                                        let deltaTranslation = CGSize(
                                            width: value.translation.width - lastPanTranslation.width,
                                            height: value.translation.height - lastPanTranslation.height
                                        )
                                        panVelocity = CGSize(
                                            width: deltaTranslation.width / CGFloat(timeDelta),
                                            height: deltaTranslation.height / CGFloat(timeDelta)
                                        )
                                    }
                                    
                                    // Calculate new viewport offset based on drag translation
                                    let deltaTranslation = CGSize(
                                        width: value.translation.width - panStartTranslation.width,
                                        height: value.translation.height - panStartTranslation.height
                                    )
                                    
                                    let newOffset = CGSize(
                                        width: panStartOffset.width + deltaTranslation.width,
                                        height: panStartOffset.height + deltaTranslation.height
                                    )
                                    
                                    // Get optimized pan boundaries
                                    let boundaries = calculatePanBoundaries(geometrySize: geometry.size, zoomScale: zoomScale)
                                    
                                    // Apply constraints with refined resistance
                                    let resistance: CGFloat = 0.2 // Reduced for more responsive feel
                                    let constrainedOffsetX = constrainWithResistance(
                                        newOffset.width,
                                        min: boundaries.minX,
                                        max: boundaries.maxX,
                                        resistance: resistance
                                    )
                                    
                                    let constrainedOffsetY = constrainWithResistance(
                                        newOffset.height,
                                        min: boundaries.minY,
                                        max: boundaries.maxY,
                                        resistance: resistance
                                    )
                                    
                                    viewportOffset = CGSize(width: constrainedOffsetX, height: constrainedOffsetY)
                                    
                                    // Update tracking variables
                                    lastPanTime = currentTime
                                    lastPanTranslation = value.translation
                                }
                                .onEnded { _ in
                                    isPanning = false
                                    
                                    // Apply momentum if velocity is high enough
                                    let momentumThreshold: CGFloat = 100.0
                                    if abs(panVelocity.width) > momentumThreshold || abs(panVelocity.height) > momentumThreshold {
                                        applyMomentum(geometry: geometry)
                                    }
                                    
                                    // Reset velocity tracking
                                    panVelocity = .zero
                                }
                        )
                    )
                }
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
                
                // Zoom and Pan Controls (top-right corner)
                VStack {
                    HStack {
                        Spacer()
                        ZoomPanControlsView(
                            zoomScale: $zoomScale,
                            viewportOffset: $viewportOffset,
                            geometry: geometry
                        )
                    }
                    Spacer()
                }
                    .padding(.top, 8)
                    .padding(.trailing, 8)
                    .allowsHitTesting(true)
                
                if editorViewModel.showRulers && pageFrame != .zero {
                    RulersOverlayView(
                        containerSize: geometry.size,
                        pageFrame: pageFrame,
                        pageSize: CGSize(width: A4.width, height: A4.height),
                        zoomScale: zoomScale,
                        margins: document.margins,
                        showMargins: workspace.showMargins,
                        unit: workspace.rulerUnit
                    )
                    .allowsHitTesting(false)
                    
                    if workspace.showMargins {
                        MarginHandlesOverlay(
                            pageFrame: pageFrame,
                            zoomScale: zoomScale,
                            margins: document.margins,
                            onMarginChange: updateMargin(edge:value:commit:)
                        )
                    }
                }
            }
            .coordinateSpace(name: "canvasSpace")
            .onPreferenceChange(PageFramePreferenceKey.self) { frame in
                DispatchQueue.main.async {
                    self.pageFrame = frame
                }
            }
        }
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
        Color.hoverHighlight
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
        Color.accentColor.opacity(0.65)
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
        .stroke(guideColor, style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
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
            .fill(Color.accentColor.opacity(0.5))
            .frame(width: 4, height: 4)
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
    
    private let rulerThickness: CGFloat = 20
    
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
    let onMarginChange: (InvoiceDocument.MarginEdge, CGFloat, Bool) -> Void
    
    @State private var dragStart: [InvoiceDocument.MarginEdge: CGFloat] = [:]
    
    private let handleSize: CGFloat = 14
    
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
            
            marginHandle(
                edge: .right,
                direction: .down,
                position: CGPoint(x: rightPosition, y: yPosition),
                axis: .horizontal,
                multiplier: -1
            )
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
            
            marginHandle(
                edge: .bottom,
                direction: .right,
                position: CGPoint(x: xPosition, y: bottomPosition),
                axis: .vertical,
                multiplier: -1
            )
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
                onMarginChange(edge, initial + delta, false)
            }
            .onEnded { value in
                let initial = dragStart[edge] ?? marginValue(for: edge)
                let delta = translation(for: value.translation, axis: axis) * multiplier / zoomScale
                onMarginChange(edge, initial + delta, true)
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
