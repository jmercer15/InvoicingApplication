import SwiftUI
import AppKit

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero
    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        // Using the latest value
        value = nextValue()
    }
}

struct InvoiceCanvasView: View {
    @EnvironmentObject private var document: InvoiceDocument
    @State private var isTargeted = false
    @State private var showRulers = true
    @State private var rulerUnit: RulerUnit = .points
    @State private var showMarginsOverlay: Bool = false
    @State private var showMarginsEditor: Bool = false
    @State private var marginLeftStr: String = ""
    @State private var marginRightStr: String = ""
    @State private var marginTopStr: String = ""
    @State private var marginBottomStr: String = ""
    @State private var scrollMonitor: Any? = nil
    @State private var magnifyStartZoom: CGFloat = 1.0
    @State private var scrollOffset: CGPoint = .zero

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let availableHeight = geometry.size.height
            let rulerThickness: CGFloat = 20
            
            ZStack(alignment: .topLeading) {
                // Background
                Color(nsColor: .windowBackgroundColor)
                
                // (margins overlay moved to top so it can render above page and components)
                
                VStack(spacing: 0) {
                    // Top ruler row
                    if showRulers {
                        HStack(spacing: 0) {
                            // Top-left corner
                            Rectangle()
                                .fill(Color.black.opacity(0.3))
                                .frame(width: rulerThickness, height: rulerThickness)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                                )
                            
                            // Top horizontal ruler
                            let topRulerWidth = max(0, availableWidth - (showRulers ? rulerThickness * 2 : 0))
                            let topHorizontalZeroOffset = max(0, (topRulerWidth - (A4.width * document.zoom)) / 2)
                            
                            RulerView(
                                orientation: .horizontal,
                                length: topRulerWidth,
                                unit: rulerUnit,
                                cursorPosition: document.showCursorIndicator ? document.cursorPosition.x : nil,
                                showCursorIndicator: document.showCursorIndicator,
                                zeroOffset: topHorizontalZeroOffset,
                                selectionStart: document.draggedComponentFrame?.minX,
                                selectionEnd: document.draggedComponentFrame?.maxX,
                                marginStart: document.margins.left,
                                marginEnd: A4.width - document.margins.right,
                                zoom: document.zoom,
                                scrollOffset: scrollOffset.x
                            )
                            
                            // Top-right corner
                            Rectangle()
                                .fill(Color.black.opacity(0.3))
                                .frame(width: rulerThickness, height: rulerThickness)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                                )
                        }
                        .frame(height: rulerThickness)
                    }
                    
                    // Middle row with left ruler, content, right ruler
                    HStack(spacing: 0) {
                        // Left vertical ruler
                        if showRulers {
                            let leftRulerHeight = max(0, availableHeight - (showRulers ? rulerThickness * 2 : 0))
                            let leftVerticalZeroOffset = max(0, (leftRulerHeight - (A4.height * document.zoom)) / 2)
                            
                            RulerView(
                                orientation: .vertical,
                                length: leftRulerHeight,
                                unit: rulerUnit,
                                cursorPosition: document.showCursorIndicator ? document.cursorPosition.y : nil,
                                showCursorIndicator: document.showCursorIndicator,
                                zeroOffset: leftVerticalZeroOffset,
                                selectionStart: document.draggedComponentFrame?.minY,
                                selectionEnd: document.draggedComponentFrame?.maxY,
                                marginStart: document.margins.top,
                                marginEnd: A4.height - document.margins.bottom,
                                zoom: document.zoom,
                                scrollOffset: scrollOffset.y
                            )
                            .frame(width: rulerThickness)
                        }
                        
                        // Main canvas area
                        ScrollView([.horizontal, .vertical]) {
                            ScrollViewReader { proxy in
                                ZStack {
                                    Color.white

                                    // Invisible overlay to handle canvas taps for deselection
                                    Color.clear
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            document.selectedComponentID = nil
                                        }

                                    // Render current components
                                    ForEach(document.components, id: \.id) { component in
                                        DraggableComponentView(component: component)
                                    }
                                    
                                    // Note: Sections are now rendered as components above (no separate rendering needed)
                                    
                                    // Snapping guides (only show when dragging is active)
                                    if document.isDragging {
                                        snappingGuides
                                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                                    }

                                    // page outline
                                    RoundedRectangle(cornerRadius: 0)
                                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                                }
                                .frame(width: A4.width, height: A4.height)
                                .scaleEffect(document.zoom, anchor: .center)
                                .compositingGroup()
                                .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 4)
                                .frame(width: A4.width * document.zoom, height: A4.height * document.zoom)
                                .id("canvas")
                                .background(
                                    GeometryReader { geo in
                                        Color.clear.preference(
                                            key: ScrollOffsetPreferenceKey.self,
                                            value: geo.frame(in: .named("scrollView")).origin
                                        )
                                    }
                                )
                                // Pinch / magnification gesture
                                .gesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            if magnifyStartZoom == 1.0 {
                                                magnifyStartZoom = document.zoom
                                            }
                                            let newZoom = magnifyStartZoom * value
                                            document.zoom = min(4.0, max(0.25, newZoom))
                                        }
                                        .onEnded { _ in
                                            magnifyStartZoom = 1.0
                                        }
                                )
                                // Hover-based scroll-wheel zoom monitor
                                .onHover { hovering in
                                    if hovering {
                                        // add local monitor
                                        if scrollMonitor == nil {
                                            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                                                // zoom when user scrolls with Command or Control pressed
                                                if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
                                                    let delta = event.scrollingDeltaY
                                                    // scrolling up (negative delta) typically zooms in on mac; invert if necessary
                                                    let factor: CGFloat = 1 + (delta * 0.002)
                                                    let newZoom = document.zoom * factor
                                                    document.zoom = min(4.0, max(0.25, newZoom))
                                                    return nil
                                                }
                                                return event
                                            }
                                        }
                                    } else {
                                        if let monitor = scrollMonitor {
                                            NSEvent.removeMonitor(monitor)
                                            scrollMonitor = nil
                                        }
                                    }
                                }
                                .overlay(
                                    // Hover feedback while dragging acceptable data
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(isTargeted ? Color.accentColor : .clear, style: StrokeStyle(lineWidth: 3, dash: [6, 6]))
                                )
                                .onContinuousHover { phase in
                                    switch phase {
                                    case .active(let location):
                                        document.cursorPosition = location
                                        document.showCursorIndicator = true
                                    case .ended:
                                        document.showCursorIndicator = false
                                    }
                                }
                                // Drop Components and Sections
                                .dropDestination(for: InvoiceComponent.self) { items, location in
                                    guard var new = items.first else { return false }
                                    new.id = UUID()
                                    // Convert drop location from view coordinates to page coordinates accounting for zoom
                                    let pageLocation = CGPoint(x: location.x / max(0.0001, document.zoom), y: location.y / max(0.0001, document.zoom))
                                    
                                    // For now, add as standalone component (sections are just components)
                                    // TODO: Later we can add logic to detect if dropping onto a section
                                    new.position = pageLocation
                                    document.add(new)
                                    return true
                                } isTargeted: { targeted in
                                    isTargeted = targeted
                                }
                            }
                        }
                        .coordinateSpace(name: "scrollView")
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                            // The origin is negative when scrolled, so we use it directly.
                            self.scrollOffset = value
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                        // Right vertical ruler
                        if showRulers {
                            let rightRulerHeight = max(0, availableHeight - (showRulers ? rulerThickness * 2 : 0))
                            let rightVerticalZeroOffset = max(0, (rightRulerHeight - (A4.height * document.zoom)) / 2)
                            
                            RulerView(
                                orientation: .vertical,
                                length: rightRulerHeight,
                                unit: rulerUnit,
                                cursorPosition: document.showCursorIndicator ? document.cursorPosition.y : nil,
                                showCursorIndicator: document.showCursorIndicator,
                                zeroOffset: rightVerticalZeroOffset,
                                selectionStart: document.draggedComponentFrame?.minY,
                                selectionEnd: document.draggedComponentFrame?.maxY,
                                marginStart: document.margins.top,
                                marginEnd: A4.height - document.margins.bottom,
                                zoom: document.zoom,
                                scrollOffset: scrollOffset.y
                            )
                            .frame(width: rulerThickness)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Bottom ruler row
                    if showRulers {
                        HStack(spacing: 0) {
                            // Bottom-left corner
                            Rectangle()
                                .fill(Color.black.opacity(0.3))
                                .frame(width: rulerThickness, height: rulerThickness)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                                )
                            
                            // Bottom horizontal ruler
                            let bottomRulerWidth = max(0, availableWidth - (showRulers ? rulerThickness * 2 : 0))
                            let bottomHorizontalZeroOffset = max(0, (bottomRulerWidth - (A4.width * document.zoom)) / 2)
                            
                            RulerView(
                                orientation: .horizontal,
                                length: bottomRulerWidth,
                                unit: rulerUnit,
                                cursorPosition: document.showCursorIndicator ? document.cursorPosition.x : nil,
                                showCursorIndicator: document.showCursorIndicator,
                                zeroOffset: bottomHorizontalZeroOffset,
                                selectionStart: document.draggedComponentFrame?.minX,
                                selectionEnd: document.draggedComponentFrame?.maxX,
                                marginStart: document.margins.left,
                                marginEnd: A4.width - document.margins.right,
                                zoom: document.zoom,
                                scrollOffset: scrollOffset.x
                            )
                            
                            // Bottom-right corner
                            Rectangle()
                                .fill(Color.black.opacity(0.3))
                                .frame(width: rulerThickness, height: rulerThickness)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                                )
                        }
                        .frame(height: rulerThickness)
                    }
                }

                // Draw margin overlay lines across the editor area when enabled
                if showMarginsOverlay {
                    // compute content area (account for rulers)
                    let contentX = showRulers ? rulerThickness : 0
                    let contentY = showRulers ? rulerThickness : 0
                    let contentWidth = max(0, availableWidth - (showRulers ? rulerThickness * 2 : 0))
                    let contentHeight = max(0, availableHeight - (showRulers ? rulerThickness * 2 : 0))

                    // page origin within editor area (centered in content area, considering scroll and zoom)
                    let zoomedA4Width = A4.width * document.zoom
                    let zoomedA4Height = A4.height * document.zoom
                    let pageOriginX = contentX + max(0, (contentWidth - zoomedA4Width) / 2) - scrollOffset.x
                    let pageOriginY = contentY + max(0, (contentHeight - zoomedA4Height) / 2) - scrollOffset.y

                    // margin positions in editor coordinates, scaled by zoom
                    let leftMarginX = pageOriginX + (document.margins.left * document.zoom)
                    let rightMarginX = pageOriginX + zoomedA4Width - (document.margins.right * document.zoom)
                    let topMarginY = pageOriginY + (document.margins.top * document.zoom)
                    let bottomMarginY = pageOriginY + zoomedA4Height - (document.margins.bottom * document.zoom)

                    let contentRight = contentX + contentWidth
                    let contentBottom = contentY + contentHeight

                    // Clamp margin positions to the content area bounds
                    let clampedLeftX = max(contentX, min(contentRight, leftMarginX))
                    let isLeftClamped = clampedLeftX != leftMarginX

                    let clampedRightX = max(contentX, min(contentRight, rightMarginX))
                    let isRightClamped = clampedRightX != rightMarginX

                    let clampedTopY = max(contentY, min(contentBottom, topMarginY))
                    let isTopClamped = clampedTopY != topMarginY

                    let clampedBottomY = max(contentY, min(contentBottom, bottomMarginY))
                    let isBottomClamped = clampedBottomY != bottomMarginY
                    
                    // Draw vertical margin lines, clamped to content area
                    Path { path in
                        path.move(to: CGPoint(x: clampedLeftX, y: contentY))
                        path.addLine(to: CGPoint(x: clampedLeftX, y: contentBottom))
                    }
                    .stroke(Color.cyan.opacity(isLeftClamped ? 0.4 : 0.9), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [6, 4]))

                    Path { path in
                        path.move(to: CGPoint(x: clampedRightX, y: contentY))
                        path.addLine(to: CGPoint(x: clampedRightX, y: contentBottom))
                    }
                    .stroke(Color.cyan.opacity(isRightClamped ? 0.4 : 0.9), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [6, 4]))

                    // Draw horizontal margin lines, clamped to content area
                    Path { path in
                        path.move(to: CGPoint(x: contentX, y: clampedTopY))
                        path.addLine(to: CGPoint(x: contentRight, y: clampedTopY))
                    }
                    .stroke(Color.cyan.opacity(isTopClamped ? 0.4 : 0.9), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [6, 4]))

                    Path { path in
                        path.move(to: CGPoint(x: contentX, y: clampedBottomY))
                        path.addLine(to: CGPoint(x: contentRight, y: clampedBottomY))
                    }
                    .stroke(Color.cyan.opacity(isBottomClamped ? 0.4 : 0.9), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [6, 4]))
                }


            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Ruler controls
                Menu {
                    Button(action: { showRulers.toggle() }) {
                        HStack {
                            Text("Show Rulers")
                            if showRulers {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Divider()
                    
                    Button(action: { rulerUnit = .points }) {
                        HStack {
                            Text("Points")
                            if rulerUnit == .points {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Button(action: { rulerUnit = .millimeters }) {
                        HStack {
                            Text("Millimeters")
                            if rulerUnit == .millimeters {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Button(action: { rulerUnit = .inches }) {
                        HStack {
                            Text("Inches")
                            if rulerUnit == .inches {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ruler")
                }
                .help("Ruler Options")

                // Margin visibility toggle
                Button(action: { showMarginsOverlay.toggle() }) {
                    Image(systemName: showMarginsOverlay ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                }
                .help("Toggle margin overlay")

                // Margin inputs inline in toolbar
                HStack(spacing: 8) {
                    Text("L")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("L", text: Binding(
                        get: { marginLeftStr.isEmpty ? String(format: "%.0f", document.margins.left) : marginLeftStr },
                        set: { marginLeftStr = $0; if let v = Double($0) { document.margins.left = CGFloat(v) } }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 56)

                    Text("R")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("R", text: Binding(
                        get: { marginRightStr.isEmpty ? String(format: "%.0f", document.margins.right) : marginRightStr },
                        set: { marginRightStr = $0; if let v = Double($0) { document.margins.right = CGFloat(v) } }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 56)

                    Text("T")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("T", text: Binding(
                        get: { marginTopStr.isEmpty ? String(format: "%.0f", document.margins.top) : marginTopStr },
                        set: { marginTopStr = $0; if let v = Double($0) { document.margins.top = CGFloat(v) } }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 56)

                    Text("B")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("B", text: Binding(
                        get: { marginBottomStr.isEmpty ? String(format: "%.0f", document.margins.bottom) : marginBottomStr },
                        set: { marginBottomStr = $0; if let v = Double($0) { document.margins.bottom = CGFloat(v) } }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 56)
                }
            }
        }
    }
    
    // MARK: - Snapping Guides
    
    private var snappingGuides: some View {
        ZStack {
            // Show snapping guides when any component is being dragged
            if document.isDragging {
                // Find the component being dragged (could be any component, not just selected)
                if let draggedComponent = getDraggedComponent() {
                    // Show guides for the closest potential snap targets
                    ForEach(getRelevantGuides(for: draggedComponent), id: \.id) { guide in
                        GuideLine(
                            isHorizontal: guide.isHorizontal,
                            position: guide.position,
                            label: guide.label
                        )
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: document.isDragging)
    }
    
    private struct GuideInfo: Identifiable {
        let id = UUID()
        let isHorizontal: Bool
        let position: CGFloat
        let label: String
    }
    
    private func getDraggedComponent() -> InvoiceComponent? {
        // Get the component that is currently being dragged
        return document.component(document.draggedComponentID)
    }
    
    private func getRelevantGuides(for selectedComponent: InvoiceComponent) -> [GuideInfo] {
        var guides: [GuideInfo] = []
        let snapDistance: CGFloat = 15 // Slightly larger distance for guide detection
        
        let otherComponents = document.components.filter { $0.id != selectedComponent.id }
        
        for component in otherComponents {
            let selectedLeft = selectedComponent.position.x - selectedComponent.size.width / 2
            let selectedRight = selectedComponent.position.x + selectedComponent.size.width / 2
            let selectedTop = selectedComponent.position.y - selectedComponent.size.height / 2
            let selectedBottom = selectedComponent.position.y + selectedComponent.size.height / 2
            let selectedCenterX = selectedComponent.position.x
            let selectedCenterY = selectedComponent.position.y
            
            let componentLeft = component.position.x - component.size.width / 2
            let componentRight = component.position.x + component.size.width / 2
            let componentTop = component.position.y - component.size.height / 2
            let componentBottom = component.position.y + component.size.height / 2
            let componentCenterX = component.position.x
            let componentCenterY = component.position.y
            
            // Check horizontal alignment possibilities
            if abs(selectedCenterY - componentCenterY) < snapDistance {
                guides.append(GuideInfo(isHorizontal: true, position: componentCenterY, label: "Center"))
            } else if abs(selectedTop - componentTop) < snapDistance {
                guides.append(GuideInfo(isHorizontal: true, position: componentTop, label: "Top"))
            } else if abs(selectedBottom - componentBottom) < snapDistance {
                guides.append(GuideInfo(isHorizontal: true, position: componentBottom, label: "Bottom"))
            } else if abs(selectedTop - componentBottom) < snapDistance {
                guides.append(GuideInfo(isHorizontal: true, position: componentBottom, label: "Edge"))
            } else if abs(selectedBottom - componentTop) < snapDistance {
                guides.append(GuideInfo(isHorizontal: true, position: componentTop, label: "Edge"))
            }
            
            // Check vertical alignment possibilities
            if abs(selectedCenterX - componentCenterX) < snapDistance {
                guides.append(GuideInfo(isHorizontal: false, position: componentCenterX, label: "Center"))
            } else if abs(selectedLeft - componentLeft) < snapDistance {
                guides.append(GuideInfo(isHorizontal: false, position: componentLeft, label: "Left"))
            } else if abs(selectedRight - componentRight) < snapDistance {
                guides.append(GuideInfo(isHorizontal: false, position: componentRight, label: "Right"))
            } else if abs(selectedLeft - componentRight) < snapDistance {
                guides.append(GuideInfo(isHorizontal: false, position: componentRight, label: "Edge"))
            } else if abs(selectedRight - componentLeft) < snapDistance {
                guides.append(GuideInfo(isHorizontal: false, position: componentLeft, label: "Edge"))
            }
        }
        
        // Check for page edge and center guide opportunities
        let selectedLeft = selectedComponent.position.x - selectedComponent.size.width / 2
        let selectedRight = selectedComponent.position.x + selectedComponent.size.width / 2
        let selectedTop = selectedComponent.position.y - selectedComponent.size.height / 2
        let selectedBottom = selectedComponent.position.y + selectedComponent.size.height / 2
        let selectedCenterX = selectedComponent.position.x
        let selectedCenterY = selectedComponent.position.y
        
        // A4 page boundaries adjusted for document margins
        let pageLeft: CGFloat = document.margins.left
        let pageRight: CGFloat = A4.width - document.margins.right
        let pageTop: CGFloat = document.margins.top
        let pageBottom: CGFloat = A4.height - document.margins.bottom
        let pageCenterX: CGFloat = (pageLeft + pageRight) / 2
        let pageCenterY: CGFloat = (pageTop + pageBottom) / 2
        
        // Check for page horizontal guides
        if abs(selectedLeft - pageLeft) < snapDistance {
            guides.append(GuideInfo(isHorizontal: false, position: pageLeft, label: "Page Left"))
        }
        if abs(selectedRight - pageRight) < snapDistance {
            guides.append(GuideInfo(isHorizontal: false, position: pageRight, label: "Page Right"))
        }
        if abs(selectedLeft - pageCenterX) < snapDistance {
            guides.append(GuideInfo(isHorizontal: false, position: pageCenterX, label: "Page Center"))
        }
        if abs(selectedRight - pageCenterX) < snapDistance {
            guides.append(GuideInfo(isHorizontal: false, position: pageCenterX, label: "Page Center"))
        }
        if abs(selectedCenterX - pageCenterX) < snapDistance {
            guides.append(GuideInfo(isHorizontal: false, position: pageCenterX, label: "Page Center"))
        }
        
        // Check for page vertical guides
        if abs(selectedTop - pageTop) < snapDistance {
            guides.append(GuideInfo(isHorizontal: true, position: pageTop, label: "Page Top"))
        }
        if abs(selectedBottom - pageBottom) < snapDistance {
            guides.append(GuideInfo(isHorizontal: true, position: pageBottom, label: "Page Bottom"))
        }
        if abs(selectedTop - pageCenterY) < snapDistance {
            guides.append(GuideInfo(isHorizontal: true, position: pageCenterY, label: "Page Center"))
        }
        if abs(selectedBottom - pageCenterY) < snapDistance {
            guides.append(GuideInfo(isHorizontal: true, position: pageCenterY, label: "Page Center"))
        }
        if abs(selectedCenterY - pageCenterY) < snapDistance {
            guides.append(GuideInfo(isHorizontal: true, position: pageCenterY, label: "Page Center"))
        }
        
        // Remove duplicate guides at the same position
        return Array(Set(guides.map { "\($0.isHorizontal)-\($0.position)" }))
            .compactMap { key in
                guides.first { "\($0.isHorizontal)-\($0.position)" == key }
            }
    }
    
    // MARK: - Guide Line Component
    
    private struct GuideLine: View {
        let isHorizontal: Bool
        let position: CGFloat
        let label: String
        @State private var isAnimating = false
        
        var body: some View {
            ZStack {
                // Simplified main guide line
                Rectangle()
                    .fill(Color.accentColor.opacity(0.7))
                    .frame(
                        width: isHorizontal ? A4.width : 1,
                        height: isHorizontal ? 1 : A4.height
                    )
                    .position(
                        x: isHorizontal ? A4.width / 2 : position,
                        y: isHorizontal ? position : A4.height / 2
                    )
                    .opacity(isAnimating ? 1.0 : 0.7)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isAnimating = true
                        }
                    }
                
                // Minimal label indicator (only for center guides)
                if label == "Center" {
                    Text(label)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(Color.accentColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.white.opacity(0.9))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(Color.accentColor.opacity(0.5), lineWidth: 0.5)
                                )
                        )
                        .position(
                            x: isHorizontal ? 30 : position,
                            y: isHorizontal ? position : 15
                        )
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    // Note: findSectionAt function removed as sections are now just components
}

