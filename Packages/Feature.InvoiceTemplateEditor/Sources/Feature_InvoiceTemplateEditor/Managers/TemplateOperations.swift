import Foundation
import SwiftUI
import AppKit
import CoreGraphics

// MARK: - Template Operations (CRUD)

extension TemplateManager {
    // MARK: - Save Template
    
    func saveTemplate(
        document: InvoiceDocument,
        name: String,
        description: String = "",
        author: String = "",
        tags: [String] = [],
        thumbnailData: Data? = nil,
        existingMetadata: TemplateMetadata? = nil
    ) async -> TemplateMetadata? {
        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        
        do {
            // Generate actual PDF template
            let pdfData = try await generatePDFTemplate(from: document)

            let sanitizedName = sanitizeFileName(name.isEmpty ? "Template" : name)
            let fileURL = templatesDirectory.appendingPathComponent("\(sanitizedName).pdf")
            let metadataURL = templatesDirectory.appendingPathComponent("\(sanitizedName).metadata")

            let decoder = JSONDecoder()
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted

            var baseMetadata: TemplateMetadata?
            if let existingMetadata {
                baseMetadata = existingMetadata
            } else if FileManager.default.fileExists(atPath: metadataURL.path),
                      let data = try? Data(contentsOf: metadataURL),
                      let templateData = try? decoder.decode(TemplateData.self, from: data) {
                baseMetadata = templateData.metadata
            }

            if let existingMetadata = baseMetadata {
                let existingBaseName = sanitizeFileName(existingMetadata.name)
                if existingBaseName != sanitizedName {
                    let oldPDF = templatesDirectory.appendingPathComponent("\(existingBaseName).pdf")
                    let oldMetadata = templatesDirectory.appendingPathComponent("\(existingBaseName).metadata")
                    try? FileManager.default.removeItem(at: oldPDF)
                    try? FileManager.default.removeItem(at: oldMetadata)
                }
            }

            let metadata = TemplateMetadata(
                id: baseMetadata?.id ?? UUID(),
                name: name,
                description: description,
                author: author,
                tags: tags,
                thumbnailData: thumbnailData ?? baseMetadata?.thumbnailData,
                createdAt: baseMetadata?.createdAt ?? Date(),
                modifiedAt: Date(),
                version: baseMetadata?.version ?? "1.0"
            )

            try pdfData.write(to: fileURL)

            let templateData = TemplateData(metadata: metadata, document: InvoiceDocumentData(from: document))
            let jsonData = try encoder.encode(templateData)
            try jsonData.write(to: metadataURL)

            if let baseMetadata {
                let legacyURL = templatesDirectory.appendingPathComponent("\(baseMetadata.id.uuidString).metadata")
                if legacyURL != metadataURL {
                    try? FileManager.default.removeItem(at: legacyURL)
                }
            }

            await MainActor.run {
                addToRecentTemplates(metadata)
                isLoading = false
            }

            return metadata

        } catch {
            await MainActor.run {
                lastError = "Failed to save template: \(error.localizedDescription)"
                isLoading = false
            }
            return nil
        }
    }
    
    // MARK: - Load Template
    
    func loadTemplate(from url: URL) async -> TemplateData? {
        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        
        do {
            // Check if it's a PDF file
            if url.pathExtension.lowercased() == "pdf" {
                if let templateData = templateData(for: url) {
                    await MainActor.run {
                        addToRecentTemplates(templateData.metadata)
                        isLoading = false
                    }
                    
                    return templateData
                } else {
                    // Create basic template data from PDF
                    let basicMetadata = TemplateMetadata(
                        name: url.deletingPathExtension().lastPathComponent,
                        description: "Imported PDF template",
                        author: "Unknown"
                    )
                    
                    let templateData = TemplateData(
                        metadata: basicMetadata,
                        document: InvoiceDocumentData(from: InvoiceDocument())
                    )
                    
                    await MainActor.run {
                        addToRecentTemplates(basicMetadata)
                        isLoading = false
                    }
                    
                    return templateData
                }
            } else {
                // Legacy JSON template loading
                let jsonData = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let templateData = try decoder.decode(TemplateData.self, from: jsonData)
                
                await MainActor.run {
                    addToRecentTemplates(templateData.metadata)
                    isLoading = false
                }
                
                return templateData
            }
            
        } catch {
            await MainActor.run {
                lastError = "Failed to load template: \(error.localizedDescription)"
                isLoading = false
            }
            return nil
        }
    }
    
    func loadTemplate(metadata: TemplateMetadata) async -> TemplateData? {
        let sanitizedName = sanitizeFileName(metadata.name)
        let fileURL = templatesDirectory.appendingPathComponent("\(sanitizedName).pdf")
        return await loadTemplate(from: fileURL)
    }
    
    // MARK: - Browse Templates
    
    func browseTemplates() async -> [TemplateMetadata] {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: templatesDirectory,
                includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            var templates: [TemplateMetadata] = []
            
            for fileURL in fileURLs {
                if fileURL.pathExtension.lowercased() == "pdf" {
                    if let templateData = templateData(for: fileURL) {
                        templates.append(templateData.metadata)
                    } else {
                        // Create basic metadata from PDF
                        let basicMetadata = TemplateMetadata(
                            name: fileURL.deletingPathExtension().lastPathComponent,
                            description: "PDF template",
                            author: "Unknown"
                        )
                        templates.append(basicMetadata)
                    }
                } else if fileURL.pathExtension == "template" {
                    // Legacy JSON templates
                    if let templateData = await loadTemplate(from: fileURL) {
                        templates.append(templateData.metadata)
                    }
                }
            }
            
            // Sort by modification date (newest first)
            return templates.sorted { $0.modifiedAt > $1.modifiedAt }
            
        } catch {
            await MainActor.run {
                lastError = "Failed to browse templates: \(error.localizedDescription)"
            }
            return []
        }
    }
    
    // MARK: - Delete Template
    
    func deleteTemplate(metadata: TemplateMetadata) async -> Bool {
        do {
            let sanitizedName = sanitizeFileName(metadata.name)
            let fileURL = templatesDirectory.appendingPathComponent("\(sanitizedName).pdf")
            
            // Delete PDF file
            try FileManager.default.removeItem(at: fileURL)
            
            // Delete metadata file
            let metadataURL = templatesDirectory.appendingPathComponent("\(sanitizedName).metadata")
            try? FileManager.default.removeItem(at: metadataURL)

            // Remove legacy metadata file if it still exists
            let legacyURL = templatesDirectory.appendingPathComponent("\(metadata.id.uuidString).metadata")
            if legacyURL != metadataURL {
                try? FileManager.default.removeItem(at: legacyURL)
            }
            
            await MainActor.run {
                removeFromRecentTemplates(metadata.id)
            }
            
            return true
            
        } catch {
            await MainActor.run {
                lastError = "Failed to delete template: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    // MARK: - PDF Template Generation
    
    private func generatePDFTemplate(from document: InvoiceDocument) async throws -> Data {
        return try await Task.detached(priority: .userInitiated) { @Sendable in
            let pdfData = NSMutableData()
            var pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4
            
            // Create metadata
            let metadata = [
                kCGPDFContextTitle: "Invoice Template",
                kCGPDFContextAuthor: "Invoice Application",
                kCGPDFContextCreator: "InvoiceTemplateEditor v1.0",
                kCGPDFContextSubject: "Invoice Template",
                kCGPDFContextKeywords: "invoice, template, business"
            ] as CFDictionary
            
            guard let consumer = CGDataConsumer(data: pdfData),
                  let context = CGContext(consumer: consumer, mediaBox: &pageRect, metadata) else {
                throw TemplateError.pdfGenerationFailed
            }
            
            // Begin PDF page
            context.beginPDFPage(nil)
            
            // Calculate content area in UI coordinates using consistent utilities
            let uiMarginRect = CoordinateCalculator.contentArea(pageSize: pageRect.size, margins: document.margins)
            
            // Convert to PDF coordinates for rendering
            let marginRect = CoordinateConverter.uiToPDF(uiMarginRect, pageHeight: pageRect.height)
            
            // Render only top-level components (sections will render their children)
            for component in document.components {
                self.renderComponentToPDF(component, in: context, within: marginRect, pageHeight: pageRect.height)
            }
            
            context.restoreGState()
            context.endPDFPage()
            context.closePDF()
            
            return pdfData as Data
        }.value
    }
    
    private func renderComponentToPDF(_ component: InvoiceComponent, in context: CGContext, within bounds: CGRect, pageHeight: CGFloat) {
        context.saveGState()
        
        // Calculate component position with coordinate conversion using consistent utilities
        let uiComponentRect = CoordinateCalculator.componentRect(component, within: bounds)
        
        // Convert to PDF coordinates for rendering
        let componentRect = CoordinateConverter.uiToPDF(uiComponentRect, pageHeight: pageHeight)
        
        // Apply component transformations
        context.translateBy(x: componentRect.midX, y: componentRect.midY)
        
        // Render based on component type
        switch component.type {
        case .textBox, .companyName, .companyABN, .companyEmail, .invoiceTitle, .notes, .paymentTerms:
            renderTextComponentToPDF(component, in: context, rect: componentRect)
        case .rectangleShape:
            renderRectangleToPDF(component, in: context, rect: componentRect)
        case .ellipseShape:
            renderEllipseToPDF(component, in: context, rect: componentRect)
        case .lineShape:
            renderLineToPDF(component, in: context, rect: componentRect)
        case .triangleShape:
            renderTriangleToPDF(component, in: context, rect: componentRect)
        case .starShape:
            renderStarToPDF(component, in: context, rect: componentRect)
        case .companyLogo, .imagePlaceholder:
            renderImageToPDF(component, in: context, rect: componentRect)
        case .invoiceNumberAndDates, .billTo, .participant, .servicesTable, .documentGrid, .totals, .paymentDetails:
            renderSectionToPDF(component, in: context, rect: componentRect)
        }
        
        context.restoreGState()
    }
    
    private func renderTextComponentToPDF(_ component: InvoiceComponent, in context: CGContext, rect: CGRect) {
        let drawRect = CGRect(
            x: -rect.width / 2,
            y: -rect.height / 2,
            width: rect.width,
            height: rect.height
        )
        
        // Draw background
        if let cgColor = component.style.backgroundColorSwiftUI.cgColor {
            context.setFillColor(cgColor)
            context.fill(drawRect)
        }
        
        // Draw text
        let text = component.style.placeholderText.isEmpty ? "Sample Text" : component.style.placeholderText
        let font = NSFont.systemFont(ofSize: component.style.fontSize)
        if let color = component.style.textColorSwiftUI.cgColor {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color
            ]
            
            let attributedString = NSAttributedString(string: text, attributes: attributes)
            let textPoint = CGPoint(x: drawRect.minX + 8, y: drawRect.minY + 8)
            attributedString.draw(at: textPoint)
        }
        
        // Draw border
        if component.style.borderWidth > 0 {
            if let cgColor = component.style.borderColorSwiftUI.cgColor {
                context.setStrokeColor(cgColor)
                context.setLineWidth(component.style.borderWidth)
                context.stroke(drawRect)
            }
        }
    }
    
    private func renderRectangleToPDF(_ component: InvoiceComponent, in context: CGContext, rect: CGRect) {
        let drawRect = CGRect(
            x: -rect.width / 2,
            y: -rect.height / 2,
            width: rect.width,
            height: rect.height
        )
        
        // Draw background
        if let cgColor = component.style.backgroundColorSwiftUI.cgColor {
            context.setFillColor(cgColor)
            context.fill(drawRect)
        }
        
        // Draw border
        if component.style.borderWidth > 0 {
            if let cgColor = component.style.borderColorSwiftUI.cgColor {
                context.setStrokeColor(cgColor)
                context.setLineWidth(component.style.borderWidth)
                context.stroke(drawRect)
            }
        }
    }
    
    private func renderEllipseToPDF(_ component: InvoiceComponent, in context: CGContext, rect: CGRect) {
        let drawRect = CGRect(
            x: -rect.width / 2,
            y: -rect.height / 2,
            width: rect.width,
            height: rect.height
        )
        
        // Draw background
        if let cgColor = component.style.backgroundColorSwiftUI.cgColor {
            context.setFillColor(cgColor)
            context.fillEllipse(in: drawRect)
        }
        
        // Draw border
        if component.style.borderWidth > 0 {
            if let cgColor = component.style.borderColorSwiftUI.cgColor {
                context.setStrokeColor(cgColor)
                context.setLineWidth(component.style.borderWidth)
                context.strokeEllipse(in: drawRect)
            }
        }
    }
    
    private func renderLineToPDF(_ component: InvoiceComponent, in context: CGContext, rect: CGRect) {
        let lineRect = CGRect(
            x: -rect.width / 2,
            y: -component.style.lineThickness / 2,
            width: rect.width,
            height: component.style.lineThickness
        )
        
        if let cgColor = component.style.borderColorSwiftUI.cgColor {
            context.setFillColor(cgColor)
            context.fill(lineRect)
        }
    }
    
    private func renderTriangleToPDF(_ component: InvoiceComponent, in context: CGContext, rect: CGRect) {
        let path = CGMutablePath()
        let width = rect.width
        let height = rect.height
        
        switch component.style.triangleDirection {
        case .up:
            path.move(to: CGPoint(x: 0, y: height / 2))
            path.addLine(to: CGPoint(x: -width / 2, y: -height / 2))
            path.addLine(to: CGPoint(x: width / 2, y: -height / 2))
        case .down:
            path.move(to: CGPoint(x: 0, y: -height / 2))
            path.addLine(to: CGPoint(x: -width / 2, y: height / 2))
            path.addLine(to: CGPoint(x: width / 2, y: height / 2))
        case .left:
            path.move(to: CGPoint(x: width / 2, y: 0))
            path.addLine(to: CGPoint(x: -width / 2, y: -height / 2))
            path.addLine(to: CGPoint(x: -width / 2, y: height / 2))
        case .right:
            path.move(to: CGPoint(x: -width / 2, y: 0))
            path.addLine(to: CGPoint(x: width / 2, y: -height / 2))
            path.addLine(to: CGPoint(x: width / 2, y: height / 2))
        }
        
        path.closeSubpath()
        
        // Draw background
        if let cgColor = component.style.backgroundColorSwiftUI.cgColor {
            context.setFillColor(cgColor)
            context.addPath(path)
            context.fillPath()
        }
        
        // Draw border
        if component.style.borderWidth > 0 {
            if let cgColor = component.style.borderColorSwiftUI.cgColor {
                context.setStrokeColor(cgColor)
                context.setLineWidth(component.style.borderWidth)
                context.addPath(path)
                context.strokePath()
            }
        }
    }
    
    private func renderStarToPDF(_ component: InvoiceComponent, in context: CGContext, rect: CGRect) {
        let path = createStarPath(points: component.style.starPoints, smoothness: component.style.starSmoothness, size: rect.size)
        
        // Draw background
        if let cgColor = component.style.backgroundColorSwiftUI.cgColor {
            context.setFillColor(cgColor)
            context.addPath(path)
            context.fillPath()
        }
        
        // Draw border
        if component.style.borderWidth > 0 {
            if let cgColor = component.style.borderColorSwiftUI.cgColor {
                context.setStrokeColor(cgColor)
                context.setLineWidth(component.style.borderWidth)
                context.addPath(path)
                context.strokePath()
            }
        }
    }
    
    private func renderImageToPDF(_ component: InvoiceComponent, in context: CGContext, rect: CGRect) {
        let drawRect = CGRect(
            x: -rect.width / 2,
            y: -rect.height / 2,
            width: rect.width,
            height: rect.height
        )
        
        // Draw background
        if let cgColor = component.style.backgroundColorSwiftUI.cgColor {
            context.setFillColor(cgColor)
            context.fill(drawRect)
        }
        
        // Draw image if available
        if let imageData = component.style.imageData,
           let nsImage = NSImage(data: imageData),
           let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(cgImage, in: drawRect)
        }
        
        // Draw border
        if component.style.borderWidth > 0 {
            if let cgColor = component.style.borderColorSwiftUI.cgColor {
                context.setStrokeColor(cgColor)
                context.setLineWidth(component.style.borderWidth)
                context.stroke(drawRect)
            }
        }
    }
    
    private func renderSectionToPDF(_ component: InvoiceComponent, in context: CGContext, rect: CGRect) {
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
        
        // Draw section border
        if component.style.borderWidth > 0 {
            if let cgColor = component.style.borderColorSwiftUI.cgColor {
                context.setStrokeColor(cgColor)
                context.setLineWidth(component.style.borderWidth)
                context.stroke(drawRect)
            }
        }
    }
    
    private func renderSectionTitleToPDF(_ title: String, component: InvoiceComponent, in context: CGContext, rect: CGRect) {
        let font = NSFont.systemFont(ofSize: component.style.fontSize)
        if let color = component.style.textColorSwiftUI.cgColor {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color
            ]
            
            let attributedString = NSAttributedString(string: title, attributes: attributes)
            let textPoint = CGPoint(x: rect.minX + component.style.contentPadding, y: rect.minY + component.style.contentPadding)
            attributedString.draw(at: textPoint)
        }
    }
    
    private func createStarPath(points: Int, smoothness: CGFloat, size: CGSize) -> CGPath {
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
}

