import SwiftUI

// Type eraser for Shape protocol
struct AnyShape: Shape {
    private let _path: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        self._path = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        return self._path(rect)
    }
}

struct DraggableComponentView: View {
    @EnvironmentObject private var document: InvoiceDocument
    let component: InvoiceComponent
    @State private var dragStart: CGPoint = .zero
    @State private var showTextEditor = false
    @State private var isDragging = false
    @State private var isFileImporterPresented = false
    
    // Computed properties for dynamic styling
    private var borderColor: Color {
        if document.selectedComponentID == component.id {
            if document.isSnapping {
                return Color.accentColor
            } else if isDragging {
                return Color.accentColor.opacity(0.8)
            } else {
                return Color.accentColor
            }
        } else {
            return component.style.borderColorSwiftUI
        }
    }
    
    private var borderWidth: CGFloat {
        if document.selectedComponentID == component.id {
            return document.isSnapping ? 3 : 2
        } else {
            return component.style.borderWidth
        }
    }

    private var anyShape: AnyShape {
        switch component.type {
        case .rectangleShape, .companyLogo, .servicesTable, .textBox, .companyName, .companyABN, .companyEmail, 
             .invoiceNumberAndDates, .billTo, .participant, .totals, .paymentDetails,
             .paymentTerms, .invoiceTitle, .notes:
            return AnyShape(RoundedRectangle(cornerRadius: component.style.cornerRadius))
        case .ellipseShape:
            return AnyShape(Ellipse())
        case .lineShape:
            return AnyShape(Rectangle())
        case .triangleShape:
            return AnyShape(Triangle(direction: component.style.triangleDirection))
        case .starShape:
            return AnyShape(Star(points: component.style.starPoints, smoothness: component.style.starSmoothness))
        case .imagePlaceholder:
            return AnyShape(Rectangle()) // Use rectangle for background/border
        }
    }

    var body: some View {
        ZStack {
            // Main component view
            Group {
                switch component.type {
                case .companyName:
                    styledTextView(defaultText: "ACME CORPORATION", subtitle: "Professional Services")
                case .companyLogo:
                    logoView
                case .companyABN:
                    styledTextView(defaultText: "12 345 678 901", label: "ABN")
                case .companyEmail:
                    styledTextView(defaultText: "contact@company.com", label: "Email")
                case .invoiceNumberAndDates:
                    if component.children.isEmpty {
                        styledTextView(defaultText: "INV-2024-001\nIssue: Jan 15, 2024\nDue: Feb 15, 2024", label: "Invoice Details")
                    } else {
                        sectionWithChildrenView(title: "Invoice Number & Dates")
                    }
                case .billTo:
                    if component.children.isEmpty {
                        styledTextView(defaultText: "John Smith\n123 Business St\nSuite 100\nCity, State 12345", label: "Bill To:")
                    } else {
                        sectionWithChildrenView(title: "Bill To")
                    }
                case .participant:
                    if component.children.isEmpty {
                        styledTextView(defaultText: "Participant Name\nNDIS #: 4300123456\nSupport Coordinator: Jane Doe", label: "Participant Details")
                    } else {
                        sectionWithChildrenView(title: "Participant")
                    }
                case .servicesTable:
                    if component.children.isEmpty {
                        serviceTableView
                    } else {
                        sectionWithChildrenView(title: "Services Table")
                    }
                case .totals:
                    if component.children.isEmpty {
                        styledTextView(defaultText: "Subtotal: $1,500.00\nDiscount: $50.00\nTax (10%): $150.00\nTOTAL: $1,650.00", label: "Totals")
                    } else {
                        sectionWithChildrenView(title: "Totals")
                    }
                case .paymentDetails:
                    if component.children.isEmpty {
                        styledTextView(defaultText: "Commonwealth Bank\nBSB: 062-001\nAccount: 12345678\nAccount Name: ACME Corp", label: "Payment Details")
                    } else {
                        sectionWithChildrenView(title: "Payment Details")
                    }
                case .paymentTerms:
                    styledTextView(defaultText: "Payment due within 30 days", label: "Terms:")
                case .invoiceTitle:
                    styledTextView(defaultText: "TAX INVOICE", label: "")
                case .notes:
                    styledTextView(defaultText: "Payment is due within 30 days. Please include invoice number with payment.", label: "Notes:")
                case .textBox:
                    styledTextView(defaultText: component.title ?? (component.style.placeholderText.isEmpty ? "Text" : component.style.placeholderText))
                case .rectangleShape:
                    shapeView(shape: RoundedRectangle(cornerRadius: component.style.cornerRadius))
                case .ellipseShape:
                    shapeView(shape: Ellipse())
                case .lineShape:
                    Line(startDecorator: component.style.lineStartDecorator, endDecorator: component.style.lineEndDecorator, thickness: component.style.lineThickness)
                        .stroke(component.style.borderColorSwiftUI, lineWidth: component.style.lineThickness)
                        .frame(width: component.size.width, height: component.size.height)
                case .triangleShape:
                    shapeView(shape: Triangle(direction: component.style.triangleDirection))
                case .starShape:
                    shapeView(shape: Star(points: component.style.starPoints, smoothness: component.style.starSmoothness))
                case .imagePlaceholder:
                    imagePlaceholderView
                }
            }
            .frame(width: component.size.width, height: component.size.height)
            .background(anyShape.fill(component.style.backgroundColorSwiftUI.opacity(component.style.backgroundOpacity)).opacity(isDragging ? 0.9 : 1.0))
            .clipShape(anyShape)
            .overlay(
                anyShape
                    .stroke(borderColor, style: component.style.borderStrokeStyle)
                    .animation(.easeInOut(duration: 0.2), value: document.selectedComponentID)
                    .animation(.easeInOut(duration: 0.2), value: document.isSnapping)
            )
            .shadow(
                color: component.style.shadowEnabled ? component.style.shadowColorSwiftUI.opacity(component.style.shadowOpacity) : Color.clear,
                radius: component.style.shadowRadius,
                x: component.style.shadowOffsetX,
                y: component.style.shadowOffsetY
            )
            
            // Resize handles - show when selected
            if document.selectedComponentID == component.id {
                resizeHandlesOverlay
            }
            
            // Selection pulse effect (appears briefly when component is selected)
            if document.selectedComponentID == component.id {
                SelectionPulseView(cornerRadius: component.style.cornerRadius)
            }
        }
        .frame(width: component.size.width, height: component.size.height)
        .padding(component.style.margin) // Apply margin
        .position(component.position)
        .onTapGesture { 
            document.selectedComponentID = component.id 
        }
        .onTapGesture(count: 2) {
            if component.type != .companyLogo && component.type != .servicesTable && component.type != .imagePlaceholder {
                showTextEditor = true
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if dragStart == .zero { 
                        dragStart = component.position
                        document.startDragging(for: component.id)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isDragging = true
                        }
                    }
                    
                    // Update cursor position in document (using global coordinates)
                    document.cursorPosition = value.location
                    document.showCursorIndicator = true
                    
                    let proposedPosition = CGPoint(
                        x: dragStart.x + value.translation.width,
                        y: dragStart.y + value.translation.height
                    )
                    let snappedPosition = document.getSnappedPosition(
                        for: proposedPosition,
                        size: component.size,
                        excludeID: component.id
                    )
                    document.setPosition(for: component.id, to: snappedPosition)
                    
                    // Update dragged component frame (in scaled coordinates)
                    let scaledSize = CGSize(width: component.size.width * document.zoom, height: component.size.height * document.zoom)
                    let scaledOrigin = CGPoint(
                        x: (snappedPosition.x - component.size.width / 2) * document.zoom,
                        y: (snappedPosition.y - component.size.height / 2) * document.zoom
                    )
                    document.draggedComponentFrame = CGRect(origin: scaledOrigin, size: scaledSize)
                }
                .onEnded { _ in 
                    dragStart = .zero
                    document.stopDragging()
                                       withAnimation(.easeInOut(duration: 0.3)) {
                       isDragging = false
                   }
                }
        )
        .sheet(isPresented: $showTextEditor) {
            TextEditorSheet(component: component, document: document)
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                // Accessing the security-scoped resource
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    do {
                        let imageData = try Data(contentsOf: url)
                        document.updateImageData(for: component.id, data: imageData)
                    } catch {
                        print("Error reading image data: \(error)")
                    }
                }
            case .failure(let error):
                print("Error importing file: \(error)")
            }
        }
    }
    
    // MARK: - Resize Handles Overlay
    
    private var resizeHandlesOverlay: some View {
        ZStack {
            // Corner handles with enhanced styling
            
            // Top-left corner
            ResizeHandle(type: .corner, position: .topLeft)
                .position(x: 0, y: 0)
                .gesture(topLeftCornerGesture)
            
            // Top-right corner
            ResizeHandle(type: .corner, position: .topRight)
                .position(x: component.size.width, y: 0)
                .gesture(topRightCornerGesture)
            
            // Bottom-left corner
            ResizeHandle(type: .corner, position: .bottomLeft)
                .position(x: 0, y: component.size.height)
                .gesture(bottomLeftCornerGesture)
            
            // Bottom-right corner
            ResizeHandle(type: .corner, position: .bottomRight)
                .position(x: component.size.width, y: component.size.height)
                .gesture(bottomRightCornerGesture)
            
            // Edge handles with enhanced styling
            
            // Top edge handle
            ResizeHandle(type: .edge, position: .top)
                .position(x: component.size.width / 2, y: 0)
                .gesture(topEdgeGesture)
            
            // Right edge handle
            ResizeHandle(type: .edge, position: .right)
                .position(x: component.size.width, y: component.size.height / 2)
                .gesture(rightEdgeGesture)
            
            // Bottom edge handle
            ResizeHandle(type: .edge, position: .bottom)
                .position(x: component.size.width / 2, y: component.size.height)
                .gesture(bottomEdgeGesture)
            
            // Left edge handle
            ResizeHandle(type: .edge, position: .left)
                .position(x: 0, y: component.size.height / 2)
                .gesture(leftEdgeGesture)
        }
    }
    
    // MARK: - Unified Resize Gesture Handler
    
    private func resizeGesture(for handleType: ResizeHandleType) -> some Gesture {
        DragGesture()
            .onChanged { value in
                let cursorX = value.location.x
                let cursorY = value.location.y
                
                let result = calculateResizeResult(
                    handleType: handleType,
                    cursorX: cursorX,
                    cursorY: cursorY,
                    component: component
                )
                
                let snapped = document.getSnappedSizeAndPosition(
                    for: component.id,
                    proposedSize: result.size,
                    proposedPosition: result.position
                )
                
                document.setSizeAndPosition(for: component.id, size: snapped.size, position: snapped.position)
            }
    }
    
    private func calculateResizeResult(
        handleType: ResizeHandleType,
        cursorX: CGFloat,
        cursorY: CGFloat,
        component: InvoiceComponent
    ) -> (size: CGSize, position: CGPoint) {
        let currentLeft = component.position.x - component.size.width / 2
        let currentRight = component.position.x + component.size.width / 2
        let currentTop = component.position.y - component.size.height / 2
        let currentBottom = component.position.y + component.size.height / 2
        
        var newLeft = currentLeft
        var newRight = currentRight
        var newTop = currentTop
        var newBottom = currentBottom
        
        switch handleType {
        case .topLeft:
            newLeft = currentLeft + cursorX
            newTop = currentTop + cursorY
        case .topRight:
            newRight = currentLeft + cursorX
            newTop = currentTop + cursorY
        case .bottomLeft:
            newLeft = currentLeft + cursorX
            newBottom = currentTop + cursorY
        case .bottomRight:
            newRight = currentLeft + cursorX
            newBottom = currentTop + cursorY
        case .top:
            newTop = currentTop + cursorY
        case .right:
            newRight = currentLeft + cursorX
        case .bottom:
            newBottom = currentTop + cursorY
        case .left:
            newLeft = currentLeft + cursorX
        }
        
        // Apply constraints
        let minWidth: CGFloat = 50
        let maxWidth: CGFloat = 800
        let minHeight: CGFloat = 30
        let maxHeight: CGFloat = 600
        
        let proposedWidth = newRight - newLeft
        let proposedHeight = newBottom - newTop
        
        let finalWidth = max(minWidth, min(maxWidth, proposedWidth))
        let finalHeight = max(minHeight, min(maxHeight, proposedHeight))
        
        // Adjust edges if constrained
        if finalWidth != proposedWidth {
            if handleType.affectsLeft {
                newLeft = newRight - finalWidth
            } else {
                newRight = newLeft + finalWidth
            }
        }
        
        if finalHeight != proposedHeight {
            if handleType.affectsTop {
                newTop = newBottom - finalHeight
            } else {
                newBottom = newTop + finalHeight
            }
        }
        
        let finalSize = CGSize(width: finalWidth, height: finalHeight)
        let finalPosition = CGPoint(
            x: newLeft + finalWidth / 2,
            y: newTop + finalHeight / 2
        )
        
        return (finalSize, finalPosition)
    }
    
    // MARK: - Resize Handle Type
    
    private enum ResizeHandleType {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, right, bottom, left
        
        var affectsLeft: Bool {
            switch self {
            case .topLeft, .bottomLeft, .left: return true
            default: return false
            }
        }
        
        var affectsTop: Bool {
            switch self {
            case .topLeft, .topRight, .top: return true
            default: return false
            }
        }
    }
    
    // Convenience computed properties for gestures
    private var topLeftCornerGesture: some Gesture { resizeGesture(for: .topLeft) }
    private var topRightCornerGesture: some Gesture { resizeGesture(for: .topRight) }
    private var bottomLeftCornerGesture: some Gesture { resizeGesture(for: .bottomLeft) }
    private var bottomRightCornerGesture: some Gesture { resizeGesture(for: .bottomRight) }
    private var topEdgeGesture: some Gesture { resizeGesture(for: .top) }
    private var rightEdgeGesture: some Gesture { resizeGesture(for: .right) }
    private var bottomEdgeGesture: some Gesture { resizeGesture(for: .bottom) }
    private var leftEdgeGesture: some Gesture { resizeGesture(for: .left) }
    
    // MARK: - Styled Views
    
    private func styledTextView(defaultText: String, label: String? = nil, subtitle: String? = nil) -> some View {
        // Use placeholderText if available, otherwise use defaultText
        let displayText = component.style.placeholderText.isEmpty ? defaultText : component.style.placeholderText
        let fontWeight = component.style.fontWeightValue
        let alignment = component.style.textAlignment.swiftUIAlignment
        let _ = component.style.fontFamily
        
        return VStack(alignment: component.style.textAlignment.horizontalAlignment, spacing: 2) {
            if let label = label {
                Text(label)
                    .font(component.style.fontFamily(max(8, component.style.fontSize - 2), .medium))
                    .foregroundColor(component.style.textColorSwiftUI.opacity(0.7))
                    .multilineTextAlignment(alignment)
                    .lineSpacing(component.style.lineSpacing)
                    .tracking(component.style.letterSpacing)
            }
            
            Text(displayText)
                .font(component.style.fontFamily(component.style.fontSize, fontWeight))
                .foregroundColor(component.style.textColorSwiftUI)
                .multilineTextAlignment(alignment)
                .lineLimit(nil)
                .lineSpacing(component.style.lineSpacing)
                .tracking(component.style.letterSpacing)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(component.style.fontFamily(max(8, component.style.fontSize - 2), .medium))
                    .foregroundColor(component.style.textColorSwiftUI.opacity(0.7))
                    .multilineTextAlignment(alignment)
                    .lineSpacing(component.style.lineSpacing)
                    .tracking(component.style.letterSpacing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: component.style.textAlignment.frameAlignment)
        .padding(component.style.padding)
    }
    
    private func sectionWithChildrenView(title: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section title
            Text(title)
                .font(.system(size: component.style.fontSize, weight: .semibold))
                .foregroundColor(component.style.textColorSwiftUI)
                .padding(.bottom, 8)
            
            // Content area with configurable layout
            SectionContentArea(
                children: component.children,
                layout: component.style.sectionLayout,
                gridColumns: component.style.gridColumns,
                spacing: component.style.contentSpacing,
                document: document
            )
            .padding(component.style.contentPadding)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(component.style.padding)
    }
    
    private var logoView: some View {
        Group {
            if let imageData = component.style.imageData, let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: component.style.imageContentMode == .fit ? .fit : .fill)
            } else {
                VStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: min(component.size.width, component.size.height) * 0.4))
                        .foregroundColor(.gray)
                    Text("LOGO")
                        .font(.system(size: max(8, component.style.fontSize - 4), weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onTapGesture(count: 2) {
            isFileImporterPresented = true
        }
    }
    
    private var serviceTableView: some View {
        VStack(spacing: 0) {
            // Header
            if component.style.showTableHeader {
                HStack {
                    Text("Service").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Quantity").frame(width: 80)
                    Text("Rate").frame(width: 80)
                    Text("Amount").frame(width: 100, alignment: .trailing)
                }
                .font(.system(size: max(8, component.style.fontSize), weight: .bold))
                .padding(8)
                .background(Color(hex: component.style.tableHeaderColor))
                .foregroundColor(Color(hex: component.style.tableTextColor))
            }

            // Example Rows
            ForEach(0..<4) { i in
                HStack {
                    Text("Example Service Description \(i + 1)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(i % 2 == 0 ? "1.5 hr" : "45 min")")
                        .frame(width: 80)
                    Text("$\((75.50 + Double(i * 5)).formatted())")
                        .frame(width: 80)
                    Text("$\((113.25 + Double(i * 10)).formatted())")
                        .frame(width: 100, alignment: .trailing)
                }
                .font(.system(size: max(8, component.style.fontSize)))
                .padding(8)
                .background(
                    component.style.useAlternatingRows && i % 2 == 1
                        ? Color(hex: component.style.tableRowAltColor)
                        : Color(hex: component.style.tableRowColor)
                )
                .foregroundColor(Color(hex: component.style.tableTextColor))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    @ViewBuilder
    private func shapeView<S: Shape>(shape: S) -> some View {
        shape
            .fill(component.style.backgroundColorSwiftUI.opacity(component.style.backgroundOpacity))
            .overlay(shape.stroke(component.style.borderColorSwiftUI, style: component.style.borderStrokeStyle))
            .frame(width: component.size.width, height: component.size.height)
    }

    private var imagePlaceholderView: some View {
        Group {
            if let imageData = component.style.imageData, let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: component.style.imageContentMode == .fit ? .fit : .fill)
            } else {
                ImagePlaceholder()
                   .stroke(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                   .foregroundColor(component.style.borderColorSwiftUI)
            }
        }
        .onTapGesture(count: 2) {
            isFileImporterPresented = true
        }
    }
    

}

// MARK: - Section Content Area

struct SectionContentArea: View {
    let children: [InvoiceComponent]
    let layout: SectionLayout
    let gridColumns: Int
    let spacing: CGFloat
    let document: InvoiceDocument
    
    var body: some View {
        switch layout {
        case .vertical:
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(children) { childComponent in
                    InlineChildComponentView(
                        childComponent: childComponent,
                        document: document
                    )
                }
            }
        case .horizontal:
            HStack(alignment: .top, spacing: spacing) {
                ForEach(children) { childComponent in
                    InlineChildComponentView(
                        childComponent: childComponent,
                        document: document
                    )
                }
            }
        case .grid:
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: gridColumns), spacing: spacing) {
                ForEach(children) { childComponent in
                    InlineChildComponentView(
                        childComponent: childComponent,
                        document: document
                    )
                }
            }
        }
    }
}

// MARK: - Inline Child Component View

struct InlineChildComponentView: View {
    let childComponent: InvoiceComponent
    let document: InvoiceDocument
    
    var body: some View {
        // Render the child component based on its type
        Group {
            switch childComponent.type {
            case .companyName:
                Text("ACME CORPORATION")
                    .font(.system(size: childComponent.style.fontSize, weight: childComponent.style.fontWeightValue))
                    .foregroundColor(childComponent.style.textColorSwiftUI)
                    .multilineTextAlignment(childComponent.style.textAlignment.swiftUIAlignment)
                    .padding(childComponent.style.padding)
                    .background(
                        RoundedRectangle(cornerRadius: childComponent.style.cornerRadius)
                            .fill(childComponent.style.backgroundColorSwiftUI.opacity(childComponent.style.backgroundOpacity))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: childComponent.style.cornerRadius)
                            .stroke(childComponent.style.borderColorSwiftUI, style: childComponent.style.borderStrokeStyle)
                    )
            case .companyABN:
                VStack(alignment: .leading, spacing: 2) {
                    Text("ABN")
                        .font(.system(size: max(8, childComponent.style.fontSize - 2), weight: .medium))
                        .foregroundColor(childComponent.style.textColorSwiftUI.opacity(0.7))
                    Text("12 345 678 901")
                        .font(.system(size: childComponent.style.fontSize, weight: childComponent.style.fontWeightValue))
                        .foregroundColor(childComponent.style.textColorSwiftUI)
                }
                .padding(childComponent.style.padding)
                .background(
                    RoundedRectangle(cornerRadius: childComponent.style.cornerRadius)
                        .fill(childComponent.style.backgroundColorSwiftUI.opacity(childComponent.style.backgroundOpacity))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: childComponent.style.cornerRadius)
                        .stroke(childComponent.style.borderColorSwiftUI, style: childComponent.style.borderStrokeStyle)
                )
            case .companyEmail:
                VStack(alignment: .leading, spacing: 2) {
                    Text("Email")
                        .font(.system(size: max(8, childComponent.style.fontSize - 2), weight: .medium))
                        .foregroundColor(childComponent.style.textColorSwiftUI.opacity(0.7))
                    Text("contact@company.com")
                        .font(.system(size: childComponent.style.fontSize, weight: childComponent.style.fontWeightValue))
                        .foregroundColor(childComponent.style.textColorSwiftUI)
                }
                .padding(childComponent.style.padding)
                .background(
                    RoundedRectangle(cornerRadius: childComponent.style.cornerRadius)
                        .fill(childComponent.style.backgroundColorSwiftUI.opacity(childComponent.style.backgroundOpacity))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: childComponent.style.cornerRadius)
                        .stroke(childComponent.style.borderColorSwiftUI, style: childComponent.style.borderStrokeStyle)
                )
            case .textBox:
                Text(childComponent.title ?? (childComponent.style.placeholderText.isEmpty ? "Text" : childComponent.style.placeholderText))
                    .font(.system(size: childComponent.style.fontSize, weight: childComponent.style.fontWeightValue))
                    .foregroundColor(childComponent.style.textColorSwiftUI)
                    .multilineTextAlignment(childComponent.style.textAlignment.swiftUIAlignment)
                    .padding(childComponent.style.padding)
                    .background(
                        RoundedRectangle(cornerRadius: childComponent.style.cornerRadius)
                            .fill(childComponent.style.backgroundColorSwiftUI.opacity(childComponent.style.backgroundOpacity))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: childComponent.style.cornerRadius)
                            .stroke(childComponent.style.borderColorSwiftUI, style: childComponent.style.borderStrokeStyle)
                    )
            default:
                Text(childComponent.title ?? "Field")
                    .font(.system(size: childComponent.style.fontSize, weight: childComponent.style.fontWeightValue))
                    .foregroundColor(childComponent.style.textColorSwiftUI)
                    .padding(childComponent.style.padding)
                    .background(
                        RoundedRectangle(cornerRadius: childComponent.style.cornerRadius)
                            .fill(childComponent.style.backgroundColorSwiftUI.opacity(childComponent.style.backgroundOpacity))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: childComponent.style.cornerRadius)
                            .stroke(childComponent.style.borderColorSwiftUI, style: childComponent.style.borderStrokeStyle)
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .shadow(
            color: childComponent.style.shadowEnabled ? childComponent.style.shadowColorSwiftUI.opacity(childComponent.style.shadowOpacity) : .clear,
            radius: childComponent.style.shadowRadius,
            x: childComponent.style.shadowOffsetX,
            y: childComponent.style.shadowOffsetY
        )
        .overlay(
            // Selection indicator
            Group {
                if document.selectedComponentID == childComponent.id {
                    RoundedRectangle(cornerRadius: childComponent.style.cornerRadius)
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: childComponent.style.cornerRadius)
                                .stroke(Color.blue, lineWidth: 2)
                                .shadow(color: Color.blue.opacity(0.3), radius: 2, x: 0, y: 0)
                        )
                }
            }
        )
        .onTapGesture {
            document.selectedComponentID = childComponent.id
        }
        .onTapGesture(count: 2) {
            if childComponent.type == .textBox {
                // Show text editor for text boxes
                // This would need to be handled by the parent view
            }
        }
    }
}

// MARK: - Text Editor Sheet

struct TextEditorSheet: View {
    let component: InvoiceComponent
    let document: InvoiceDocument
    @Environment(\.dismiss) private var dismiss
    @State private var editText: String
    
    init(component: InvoiceComponent, document: InvoiceDocument) {
        self.component = component
        self.document = document
        self._editText = State(initialValue: component.style.placeholderText.isEmpty ? TextEditorSheet.getDefaultText(for: component.type) : component.style.placeholderText)
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Edit Text Content")
                    .font(.headline)
                
                TextEditor(text: $editText)
                    .font(.system(size: 14))
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                Spacer()
            }
            .padding()
            .navigationTitle("Edit \(component.type.rawValue)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        document.updateText(for: component.id, text: editText)
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 400, height: 300)
    }
    
    private static func getDefaultText(for type: InvoiceComponentType) -> String {
        switch type {
        case .companyName: return "ACME CORPORATION"
        case .invoiceNumberAndDates: return "INV-2024-001\nIssue: Jan 15, 2024\nDue: Feb 15, 2024"
        case .billTo: return "John Smith\n123 Business St\nSuite 100\nCity, State 12345"
        case .participant: return "Participant Name\nNDIS #: 4300123456\nSupport Coordinator: Jane Doe"
        case .totals: return "Subtotal: $1,500.00\nDiscount: $50.00\nTax (10%): $150.00\nTOTAL: $1,650.00"
        case .paymentDetails: return "Commonwealth Bank\nBSB: 062-001\nAccount: 12345678\nAccount Name: ACME Corp"
        case .paymentTerms: return "Payment due within 30 days"
        case .invoiceTitle: return "TAX INVOICE"
        case .notes: return "Payment is due within 30 days. Please include invoice number with payment."
        default: return ""
        }
    }
}

// MARK: - Resize Handle Component

struct ResizeHandle: View {
    enum HandleType {
        case corner
        case edge
    }
    
    enum HandlePosition {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, right, bottom, left
    }
    
    let type: HandleType
    let position: HandlePosition
    @State private var isHovered = false
    
    var body: some View {
        ZStack {
            // Background circle for better visibility
            Circle()
                .fill(Color.white)
                .frame(width: handleSize + 4, height: handleSize + 4)
            
            // Main handle
            Group {
                if type == .corner {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(isHovered ? 1.0 : 0.9),
                                    Color.accentColor.opacity(isHovered ? 0.8 : 0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1.5)
                        )
                } else {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(isHovered ? 1.0 : 0.9),
                                    Color.accentColor.opacity(isHovered ? 0.8 : 0.7)
                                ],
                                startPoint: isVerticalEdge ? .top : .leading,
                                endPoint: isVerticalEdge ? .bottom : .trailing
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white, lineWidth: 1.5)
                        )
                }
            }
            .frame(width: handleWidth, height: handleHeight)
            .scaleEffect(isHovered ? 1.15 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .cursor(cursorType)
    }
    
    private var handleSize: CGFloat {
        return 10
    }
    
    private var handleWidth: CGFloat {
        switch type {
        case .corner:
            return handleSize
        case .edge:
            return isVerticalEdge ? 6 : 20
        }
    }
    
    private var handleHeight: CGFloat {
        switch type {
        case .corner:
            return handleSize
        case .edge:
            return isVerticalEdge ? 20 : 6
        }
    }
    
    private var isVerticalEdge: Bool {
        switch position {
        case .left, .right:
            return true
        case .top, .bottom:
            return false
        default:
            return false
        }
    }
    
    private var cursorType: NSCursor {
        // Use pointer cursor for now - can be enhanced later with proper resize cursors
        return NSCursor.pointingHand
    }
}

// MARK: - Selection Pulse Animation
struct SelectionPulseView: View {
    let cornerRadius: CGFloat
    @State private var pulseOpacity: Double = 0.0
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(Color.accentColor, lineWidth: 3)
            .opacity(pulseOpacity)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.3)
                ) {
                    pulseOpacity = 0.7
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(
                        .easeOut(duration: 0.5)
                    ) {
                        pulseOpacity = 0.0
                    }
                }
            }
    }
}

// MARK: - Cursor Extension

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { hovering in
            if hovering {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}