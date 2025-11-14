import Foundation
import CoreGraphics
import PDFKit
import AppKit
import SwiftUI
import SharedUI



// MARK: - Export Service (Apple Guidelines Compliant)

/// Thread-safe PDF export service following Apple's Core Graphics and PDFKit best practices
class ExportService: ObservableObject, @unchecked Sendable {
    static let shared = ExportService()

    private init() {}

    // MARK: - Enums and Types
    
    /// Supported image formats for export
    enum ImageFormat {
        case png
        case jpeg
    }
    
    /// Export-related errors
    enum ExportError: Error {
        case contextCreationFailed
        case renderingFailed
        case fileCreationFailed
    }
    
    // MARK: - Public Export Methods
    
    /// Exports document to PDF file
    func exportToPDF(document: InvoiceDocument, fileName: String) async throws -> URL {
        let pdfData = try await generatePDFData(from: document)

        return try await MainActor.run {
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.pdf]
            savePanel.nameFieldStringValue = fileName
            
            guard let url = savePanel.url else {
                throw ExportError.fileCreationFailed
            }
            
            try pdfData.write(to: url)
            return url
        }
    }
    
    /// Exports document to image file
    func exportToImage(document: InvoiceDocument, format: ImageFormat, fileName: String) async throws -> URL {
        let imageData = try await generateImageData(from: document, format: format)

        return try await MainActor.run {
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [format == .png ? .png : .jpeg]
            savePanel.nameFieldStringValue = fileName
            
            guard let url = savePanel.url else {
                throw ExportError.fileCreationFailed
            }
            
            try imageData.write(to: url)
            return url
        }
    }
    
    /// Prints the document
    func printDocument(document: InvoiceDocument) {
        Task { @MainActor in
            do {
                _ = try await generatePDFData(from: document)
                let printInfo = NSPrintInfo.shared
                let printOperation = NSPrintOperation(view: PDFView(), printInfo: printInfo)
                printOperation.run()
            } catch {
                print("Print failed: \(error)")
            }
        }
    }
    
    // MARK: - PDF Generation (Core Graphics + PDFKit)
    
    /// Generates PDF data using Core Graphics with proper coordinate system handling
    /// - Parameter document: The invoice document to render
    /// - Returns: PDF data following Apple's PDFKit guidelines
    func generatePDFData(from document: InvoiceDocument) async throws -> Data {
        return try await Task.detached(priority: .userInitiated) { @Sendable in
            try await self.generatePDFDataInternal(from: document)
        }.value
    }
    

    
    /// Internal PDF generation with proper Core Graphics context management
    private func generatePDFDataInternal(from document: InvoiceDocument) async throws -> Data {
        // Create PDF context with proper coordinate system
        var pageRect = CGRect(x: 0, y: 0, width: document.pageSize.width, height: document.pageSize.height)
        
        // Create a mutable data object to hold the PDF
        let pdfData = NSMutableData()
        
        // Create PDF context using the correct API
        guard let pdfContext = CGContext(consumer: CGDataConsumer(data: pdfData)!, mediaBox: &pageRect, nil) else {
            throw ExportError.contextCreationFailed
        }
        
        // Begin PDF page with proper coordinate system
        pdfContext.beginPDFPage(nil as CFDictionary?)
        
        // Calculate content area in UI coordinates using consistent utilities
        let uiMarginRect = CoordinateCalculator.contentArea(pageSize: pageRect.size, margins: document.margins)
        
        // Convert to PDF coordinates for rendering
        let marginRect = CoordinateConverter.uiToPDF(uiMarginRect, pageHeight: pageRect.height)
        
        // Render document background
        self.renderDocumentBackground(in: pdfContext, rect: pageRect, document: document)
        
        // Render only top-level components (sections will render their children)
        for component in document.components {
            try await self.renderComponentThreadSafe(component, in: pdfContext, within: marginRect, pageHeight: pageRect.height)
        }
        
        // End PDF page and finalize
        pdfContext.endPDFPage()
        pdfContext.closePDF()
        
        return pdfData as Data
    }
    

    
    // MARK: - Thread-Safe Component Rendering
    
    /// Thread-safe component rendering with proper Core Graphics state management
    private func renderComponentThreadSafe(_ component: InvoiceComponent, in context: CGContext, within bounds: CGRect, pageHeight: CGFloat? = nil) async throws {
        // Render directly since we're already on a background thread
        self.renderComponentInternal(component, in: context, within: bounds, pageHeight: pageHeight)
    }
    
    /// Internal component rendering with proper Core Graphics practices
    private func renderComponentInternal(_ component: InvoiceComponent, in context: CGContext, within bounds: CGRect, pageHeight: CGFloat? = nil) {
        // Save graphics state for proper restoration
        context.saveGState()
        
        // Calculate component position using consistent utilities
        let componentRect: CGRect
        if let pageHeight = pageHeight {
            // PDF rendering: Convert UI coordinates to PDF coordinates
            let uiComponentRect = CoordinateCalculator.componentRect(component, within: bounds)
            componentRect = CoordinateConverter.uiToPDF(uiComponentRect, pageHeight: pageHeight)
        } else {
            // Image rendering: Use UI coordinates directly
            componentRect = CoordinateCalculator.componentRect(component, within: bounds)
        }
        
        // Apply component transformations
        context.translateBy(x: componentRect.midX, y: componentRect.midY)
        
        // Render based on component type using Core Graphics best practices
        switch component.type {
        case .textBox, .companyName, .companyABN, .companyEmail, .invoiceTitle, .notes, .paymentTerms:
            self.renderTextComponentCoreGraphics(component, in: context, rect: componentRect)
        case .rectangleShape:
            self.renderRectangleCoreGraphics(component, in: context, rect: componentRect)
        case .ellipseShape:
            self.renderEllipseCoreGraphics(component, in: context, rect: componentRect)
        case .lineShape:
            self.renderLineCoreGraphics(component, in: context, rect: componentRect)
        case .triangleShape:
            self.renderTriangleCoreGraphics(component, in: context, rect: componentRect)
        case .starShape:
            self.renderStarCoreGraphics(component, in: context, rect: componentRect)
        case .companyLogo, .imagePlaceholder:
            self.renderImageCoreGraphics(component, in: context, rect: componentRect)
        case .invoiceNumberAndDates, .billTo, .participant, .servicesTable, .documentGrid, .totals, .paymentDetails:
            self.renderSectionCoreGraphics(component, in: context, rect: componentRect)
        }
        
        // Restore graphics state
        context.restoreGState()
    }
    
    // MARK: - Core Graphics Text Rendering (Apple Guidelines)
    
    /// Renders text components using Core Graphics best practices
    private func renderTextComponentCoreGraphics(_ component: InvoiceComponent, in context: CGContext, rect: CGRect) {
        // Set up text attributes following Core Graphics guidelines
        let text = component.style.placeholderText.isEmpty ? "Sample Text" : component.style.placeholderText
        let font = self.createFontForCoreGraphics(for: component.style)
        
        // Create attributed string with proper Core Graphics attributes
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: component.style.textColorSwiftUI.cgColor as Any
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        
        // Calculate text bounds using Core Graphics
        let textBounds = attributedString.boundingRect(with: rect.size, options: [], context: nil)
        
        // Create drawing rectangle with proper coordinate system
        let drawRect = CGRect(
            x: -rect.width / 2,
            y: -rect.height / 2,
            width: rect.width,
            height: rect.height
        )
        
        // Draw background if needed
        if component.style.backgroundOpacity > 0 {
            if let cgColor = component.style.backgroundColorSwiftUI.cgColor {
                context.setFillColor(cgColor)
                context.fill(drawRect)
            }
        }
        
        // Draw text using Core Graphics text rendering
        let textPoint = CGPoint(
            x: drawRect.minX + (drawRect.width - textBounds.width) / 2,
            y: drawRect.minY + (drawRect.height - textBounds.height) / 2
        )
        
        // Use Core Graphics text drawing
        context.textPosition = textPoint
        let line = CTLineCreateWithAttributedString(attributedString)
        context.textMatrix = CGAffineTransform.identity
        CTLineDraw(line, context)
        
        // Draw border if needed
        if component.style.borderWidth > 0 {
            if let cgColor = component.style.borderColorSwiftUI.cgColor {
                context.setStrokeColor(cgColor)
                context.setLineWidth(component.style.borderWidth)
                context.stroke(drawRect)
            }
        }
    }
    
    // MARK: - Core Graphics Shape Rendering (Apple Guidelines)
    
    /// Renders rectangle shapes using Core Graphics paths
    private func renderRectangleCoreGraphics(_ component: InvoiceComponent, in context: CGContext, rect: CGRect) {
        let drawRect = CGRect(
            x: -rect.width / 2,
            y: -rect.height / 2,
            width: rect.width,
            height: rect.height
        )
        
        // Create path using Core Graphics
        let path = CGPath(rect: drawRect, transform: nil)
        
        // Fill if background color is set
        if let cgColor = component.style.backgroundColorSwiftUI.cgColor {
            context.setFillColor(cgColor)
            context.addPath(path)
            context.fillPath()
        }
        
        // Stroke if border is set
        if component.style.borderWidth > 0 {
            if let cgColor = component.style.borderColorSwiftUI.cgColor {
                context.setStrokeColor(cgColor)
                context.setLineWidth(component.style.borderWidth)
                context.addPath(path)
                context.strokePath()
            }
        }
    }
    
    /// Renders ellipse shapes using Core Graphics paths
    private func renderEllipseCoreGraphics(_ component: InvoiceComponent, in context: CGContext, rect: CGRect) {
        let drawRect = CGRect(
            x: -rect.width / 2,
            y: -rect.height / 2,
            width: rect.width,
            height: rect.height
        )
        
        // Create elliptical path using Core Graphics
        let path = CGPath(ellipseIn: drawRect, transform: nil)
        
        // Fill if background color is set
        if let cgColor = component.style.backgroundColorSwiftUI.cgColor {
            context.setFillColor(cgColor)
            context.addPath(path)
            context.fillPath()
        }
        
        // Stroke if border is set
        if component.style.borderWidth > 0 {
            if let cgColor = component.style.borderColorSwiftUI.cgColor {
                context.setStrokeColor(cgColor)
                context.setLineWidth(component.style.borderWidth)
                context.addPath(path)
                context.strokePath()
            }
        }
    }
    
    /// Renders line shapes using Core Graphics paths
    private func renderLineCoreGraphics(_ component: InvoiceComponent, in context: CGContext, rect: CGRect) {
        let drawRect = CGRect(
            x: -rect.width / 2,
            y: -rect.height / 2,
            width: rect.width,
            height: rect.height
        )
        
        // Create line path using Core Graphics
        let path = CGMutablePath()
        path.move(to: CGPoint(x: drawRect.minX, y: drawRect.midY))
        path.addLine(to: CGPoint(x: drawRect.maxX, y: drawRect.midY))
        
        // Set line properties
        if let cgColor = component.style.borderColorSwiftUI.cgColor {
            context.setStrokeColor(cgColor)
        }
        context.setLineWidth(component.style.borderWidth)
        
        // Draw the line
        context.addPath(path)
        context.strokePath()
    }
    
    /// Renders triangle shapes using Core Graphics paths
    private func renderTriangleCoreGraphics(_ component: InvoiceComponent, in context: CGContext, rect: CGRect) {
        let drawRect = CGRect(
            x: -rect.width / 2,
            y: -rect.height / 2,
            width: rect.width,
            height: rect.height
        )
        
        // Create triangle path using Core Graphics
        let path = CGMutablePath()
        let direction = component.style.triangleDirection
        
        switch direction {
        case .up:
            path.move(to: CGPoint(x: drawRect.midX, y: drawRect.maxY))
            path.addLine(to: CGPoint(x: drawRect.minX, y: drawRect.minY))
            path.addLine(to: CGPoint(x: drawRect.maxX, y: drawRect.minY))
        case .down:
            path.move(to: CGPoint(x: drawRect.midX, y: drawRect.minY))
            path.addLine(to: CGPoint(x: drawRect.minX, y: drawRect.maxY))
            path.addLine(to: CGPoint(x: drawRect.maxX, y: drawRect.maxY))
        case .left:
            path.move(to: CGPoint(x: drawRect.maxX, y: drawRect.midY))
            path.addLine(to: CGPoint(x: drawRect.minX, y: drawRect.minY))
            path.addLine(to: CGPoint(x: drawRect.minX, y: drawRect.maxY))
        case .right:
            path.move(to: CGPoint(x: drawRect.minX, y: drawRect.midY))
            path.addLine(to: CGPoint(x: drawRect.maxX, y: drawRect.minY))
            path.addLine(to: CGPoint(x: drawRect.maxX, y: drawRect.maxY))
        }
        
        path.closeSubpath()
        
        // Fill if background color is set
        if let cgColor = component.style.backgroundColorSwiftUI.cgColor {
            context.setFillColor(cgColor)
            context.addPath(path)
            context.fillPath()
        }
        
        // Stroke if border is set
        if component.style.borderWidth > 0 {
            if let cgColor = component.style.borderColorSwiftUI.cgColor {
                context.setStrokeColor(cgColor)
                context.setLineWidth(component.style.borderWidth)
                context.addPath(path)
                context.strokePath()
            }
        }
    }
    
    /// Renders star shapes using Core Graphics paths
    private func renderStarCoreGraphics(_ component: InvoiceComponent, in context: CGContext, rect: CGRect) {
        let drawRect = CGRect(
            x: -rect.width / 2,
            y: -rect.height / 2,
            width: rect.width,
            height: rect.height
        )
        
        // Create star path using Core Graphics
        let path = self.createStarPathCoreGraphics(
            points: component.style.starPoints,
            smoothness: component.style.starSmoothness,
            size: drawRect.size
        )
        
        // Apply transformation to center the star
        context.translateBy(x: drawRect.midX, y: drawRect.midY)
        
        // Fill if background color is set
        if let cgColor = component.style.backgroundColorSwiftUI.cgColor {
            context.setFillColor(cgColor)
            context.addPath(path)
            context.fillPath()
        }
        
        // Stroke if border is set
        if component.style.borderWidth > 0 {
            if let cgColor = component.style.borderColorSwiftUI.cgColor {
                context.setStrokeColor(cgColor)
                context.setLineWidth(component.style.borderWidth)
                context.addPath(path)
                context.strokePath()
            }
        }
        
        // Reset transformation
        context.translateBy(x: -drawRect.midX, y: -drawRect.midY)
    }
    
    /// Renders image components using Core Graphics
    private func renderImageCoreGraphics(_ component: InvoiceComponent, in context: CGContext, rect: CGRect) {
        let drawRect = CGRect(
            x: -rect.width / 2,
            y: -rect.height / 2,
            width: rect.width,
            height: rect.height
        )
        
        // For now, render as placeholder rectangle
        // In a full implementation, you would load and draw the actual image
        if let cgColor = component.style.backgroundColorSwiftUI.cgColor {
            context.setFillColor(cgColor)
            context.fill(drawRect)
        }
        
        if component.style.borderWidth > 0 {
            if let cgColor = component.style.borderColorSwiftUI.cgColor {
                context.setStrokeColor(cgColor)
                context.setLineWidth(component.style.borderWidth)
                context.stroke(drawRect)
            }
        }
    }
    
    // MARK: - Core Graphics Section Rendering (Apple Guidelines)
    
    /// Renders sections using Core Graphics with proper layout algorithms
    private func renderSectionCoreGraphics(_ component: InvoiceComponent, in context: CGContext, rect: CGRect) {
        let drawRect = CGRect(
            x: -rect.width / 2,
            y: -rect.height / 2,
            width: rect.width,
            height: rect.height
        )
        
        // Draw section background
        if let cgColor = component.style.backgroundColorSwiftUI.cgColor {
            context.setFillColor(cgColor)
            context.fill(drawRect)
        }
        
        // Section components now use DocumentGrid internally
        // No need for separate title or child rendering
    }
    
    /// Renders section title using Core Graphics
    private func renderSectionTitleCoreGraphics(_ title: String, component: InvoiceComponent, in context: CGContext, rect: CGRect) {
        let font = self.createFontForCoreGraphics(for: component.style)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: component.style.textColorSwiftUI.cgColor as Any
        ]
        
        let attributedString = NSAttributedString(string: title, attributes: attributes)
        let textBounds = attributedString.boundingRect(with: rect.size, options: [], context: nil)
        
        let textPoint = CGPoint(
            x: rect.minX + 10,
            y: rect.minY + (30 - textBounds.height) / 2
        )
        
        context.textPosition = textPoint
        let line = CTLineCreateWithAttributedString(attributedString)
        context.textMatrix = CGAffineTransform.identity
        CTLineDraw(line, context)
    }
    
    // MARK: - Core Graphics Layout Algorithms (Apple Guidelines)
    
    /// Renders vertical layout using Core Graphics
    private func renderVerticalLayoutCoreGraphics(children: [InvoiceComponent], in context: CGContext, rect: CGRect, spacing: CGFloat) {
        var currentY: CGFloat = rect.minY
        let availableWidth = rect.width
        
        for child in children {
            let childHeight = min(child.size.height, rect.height - currentY + rect.minY)
            let childRect = CGRect(
                x: rect.minX,
                y: currentY,
                width: availableWidth,
                height: childHeight
            )
            
            // Save context state for child rendering
            context.saveGState()
            
            // Transform to child's coordinate system
            context.translateBy(x: childRect.midX, y: childRect.midY)
            
            // Render child component at the calculated position
            self.renderChildComponentCoreGraphics(child, in: context, rect: childRect)
            
            context.restoreGState()
            
            currentY += childHeight + spacing
        }
    }
    
    /// Renders horizontal layout using Core Graphics
    private func renderHorizontalLayoutCoreGraphics(children: [InvoiceComponent], in context: CGContext, rect: CGRect, spacing: CGFloat) {
        var currentX: CGFloat = rect.minX
        let availableHeight = rect.height
        
        for child in children {
            let childWidth = min(child.size.width, rect.width - currentX + rect.minX)
            let childRect = CGRect(
                x: currentX,
                y: rect.minY,
                width: childWidth,
                height: availableHeight
            )
            
            // Save context state for child rendering
            context.saveGState()
            
            // Transform to child's coordinate system
            context.translateBy(x: childRect.midX, y: childRect.midY)
            
            // Render child component at the calculated position
            self.renderChildComponentCoreGraphics(child, in: context, rect: childRect)
            
            context.restoreGState()
            
            currentX += childWidth + spacing
        }
    }
    
    /// Renders grid layout using Core Graphics
    private func renderGridLayoutCoreGraphics(children: [InvoiceComponent], in context: CGContext, rect: CGRect, columns: Int, spacing: CGFloat) {
        guard columns > 0 else { return }
        
        let rows = (children.count + columns - 1) / columns // Ceiling division
        let cellWidth = (rect.width - (spacing * CGFloat(columns - 1))) / CGFloat(columns)
        let cellHeight = (rect.height - (spacing * CGFloat(rows - 1))) / CGFloat(rows)
        
        for (index, child) in children.enumerated() {
            let row = index / columns
            let col = index % columns
            
            let cellX = rect.minX + CGFloat(col) * (cellWidth + spacing)
            let cellY = rect.minY + CGFloat(row) * (cellHeight + spacing)
            
            let childRect = CGRect(
                x: cellX,
                y: cellY,
                width: cellWidth,
                height: cellHeight
            )
            
            // Save context state for child rendering
            context.saveGState()
            
            // Transform to child's coordinate system
            context.translateBy(x: childRect.midX, y: childRect.midY)
            
            // Render child component at the calculated position
            self.renderChildComponentCoreGraphics(child, in: context, rect: childRect)
            
            context.restoreGState()
        }
    }
    
    /// Renders child components using Core Graphics
    private func renderChildComponentCoreGraphics(_ component: InvoiceComponent, in context: CGContext, rect: CGRect) {
        // Render based on component type (without using component.position)
        switch component.type {
        case .textBox, .companyName, .companyABN, .companyEmail, .invoiceTitle, .notes, .paymentTerms:
            self.renderTextComponentCoreGraphics(component, in: context, rect: rect)
        case .rectangleShape:
            self.renderRectangleCoreGraphics(component, in: context, rect: rect)
        case .ellipseShape:
            self.renderEllipseCoreGraphics(component, in: context, rect: rect)
        case .lineShape:
            self.renderLineCoreGraphics(component, in: context, rect: rect)
        case .triangleShape:
            self.renderTriangleCoreGraphics(component, in: context, rect: rect)
        case .starShape:
            self.renderStarCoreGraphics(component, in: context, rect: rect)
        case .companyLogo, .imagePlaceholder:
            self.renderImageCoreGraphics(component, in: context, rect: rect)
        case .invoiceNumberAndDates, .billTo, .participant, .servicesTable, .documentGrid, .totals, .paymentDetails:
            // Child sections are not supported - just render as a container
            self.renderRectangleCoreGraphics(component, in: context, rect: rect)
        }
    }
    
    // MARK: - Core Graphics Helper Methods (Apple Guidelines)
    
    /// Creates font for Core Graphics rendering
    private func createFontForCoreGraphics(for style: ComponentStyle) -> CTFont {
        let fontSize = style.fontSize
        let fontName = style.fontFamily.isEmpty ? "Helvetica" : style.fontFamily
        
        let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        return font
    }
    
    /// Creates star path using Core Graphics
    private func createStarPathCoreGraphics(points: Int, smoothness: CGFloat, size: CGSize) -> CGPath {
        let path = CGMutablePath()
        let radius = min(size.width, size.height) / 2
        let center = CGPoint.zero
        
        let outerRadius = radius
        let innerRadius = radius * smoothness
        
        for i in 0..<points * 2 {
            let angle = CGFloat(i) * .pi / CGFloat(points)
            let currentRadius = i % 2 == 0 ? outerRadius : innerRadius
            let point = CGPoint(
                x: center.x + cos(angle) * currentRadius,
                y: center.y + sin(angle) * currentRadius
            )
            
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        
        path.closeSubpath()
        return path
    }
    
    /// Creates PDF metadata following Apple's guidelines
    private func createPDFMetadata(for document: InvoiceDocument) -> CFDictionary {
        return [
            kCGPDFContextTitle: "Invoice Template",
            kCGPDFContextAuthor: "Invoice Application",
            kCGPDFContextCreator: "InvoiceTemplateEditor v1.0",
            kCGPDFContextSubject: "Invoice Template",
            kCGPDFContextKeywords: "invoice, template, business"
        ] as CFDictionary
    }
    
    /// Renders document background using Core Graphics
    private func renderDocumentBackground(in context: CGContext, rect: CGRect, document: InvoiceDocument) {
        // Set background color
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        context.fill(rect)
    }
    
    // MARK: - Image Generation (Core Graphics)
    
    /// Generates image data using Core Graphics with proper thread safety
    func generateImageData(from document: InvoiceDocument, format: ImageFormat) async throws -> Data {
        return try await Task.detached(priority: .userInitiated) { @Sendable in
            try self.generateImageDataInternal(from: document, format: format)
        }.value
    }
    
    /// Internal image generation with proper Core Graphics context management
    private func generateImageDataInternal(from document: InvoiceDocument, format: ImageFormat) throws -> Data {
        let size = document.pageSize
        
        // Create bitmap context with proper color space
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ExportError.contextCreationFailed
        }
        
        // Set up context for proper rendering
        context.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        context.fill(CGRect(origin: .zero, size: size))
        
        // Calculate margins and content area using consistent utilities
        let marginRect = CoordinateCalculator.contentArea(pageSize: size, margins: document.margins)
        
        // Render only top-level components (sections will render their children)
        for component in document.components {
            self.renderComponentInternal(component, in: context, within: marginRect)
        }
        
        guard let cgImage = context.makeImage() else {
            throw ExportError.renderingFailed
        }
        
        let nsImage = NSImage(cgImage: cgImage, size: size)
        
        switch format {
        case .png:
            guard let tiffData = nsImage.tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmapImage.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
                throw ExportError.renderingFailed
            }
            return pngData
        case .jpeg:
            guard let tiffData = nsImage.tiffRepresentation,
                  let bitmapImage = NSBitmapImageRep(data: tiffData),
                  let jpegData = bitmapImage.representation(using: NSBitmapImageRep.FileType.jpeg, properties: [:]) else {
                throw ExportError.renderingFailed
            }
            return jpegData
        }
    }
}

// MARK: - Document Renderer (SwiftUI Integration)

struct DocumentRenderer: View {
    let document: InvoiceDocument

    var body: some View {
        ZStack {
            ForEach(document.components) { component in
                ComponentView(component: component)
            }
        }
        .frame(width: document.pageSize.width, height: document.pageSize.height)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct ComponentView: View {
    let component: InvoiceComponent

    var body: some View {
        // SwiftUI component rendering for preview
                    Rectangle()
            .fill(Color(NSColor.systemGray))
            .frame(width: component.size.width, height: component.size.height)
            .position(component.position)
    }
}

