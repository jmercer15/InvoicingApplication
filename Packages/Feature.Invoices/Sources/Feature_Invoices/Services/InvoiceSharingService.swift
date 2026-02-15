//
//  InvoiceSharingService.swift
//  Feature.Invoices
//
//  Service for generating PDF documents from invoices using the template system
//

import Foundation
import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import Core
import SharedUI
import Feature_InvoiceTemplateEditor

/// Service for generating PDF documents from invoices using the template system
public class InvoiceSharingService {
    private let templateManager: TemplateManager
    private let templateDataService: TemplateDataService
    
    public init(templateManager: TemplateManager, templateDataService: TemplateDataService) {
        self.templateManager = templateManager
        self.templateDataService = templateDataService
    }
    
    /// Renders PDF data for the given invoice using template-based rendering
    @MainActor
    public func renderPDFData(invoice: Invoice, invoiceItems: [InvoiceItem]) async -> Data? {
        // Create a fresh document to load the template into
        let document = InvoiceDocument()
        
        // Set the invoice data in the template data service
        await templateDataService.setSelectedInvoice(invoice, items: invoiceItems)
        
        // Load the template - prefer invoice's assigned template, fallback to first available
        let templates = await templateManager.browseTemplates()
        
        var selectedTemplate: TemplateMetadata?
        
        // Try to find the invoice's assigned template
        if let templateId = invoice.templateId {
            selectedTemplate = templates.first(where: { $0.id == templateId })
        }
        
        // Fallback to first available template if not found
        if selectedTemplate == nil {
            selectedTemplate = templates.first
        }
        
        if let metadata = selectedTemplate,
           let templateData = await templateManager.loadTemplate(metadata: metadata) {
            document.loadTemplate(templateData)
        }
        
        // Generate PDF using ExportService
        do {
            return try await ExportService.shared.generatePDFData(from: document)
        } catch {
            print("❌ [InvoiceSharingService] PDF generation failed: \(error)")
            return nil
        }
    }

    /// Creates a temporary PDF file URL for the invoice
    @MainActor
    public func temporaryPDFURL(invoice: Invoice, invoiceItems: [InvoiceItem]) async -> URL? {
        guard let data = await renderPDFData(invoice: invoice, invoiceItems: invoiceItems) else {
            return nil
        }
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Invoice-\(invoice.invoiceNumber).pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            print("❌ [InvoiceSharingService] Failed to write PDF to temp file: \(error)")
            return nil
        }
    }

    /// Creates an NSItemProvider for sharing the invoice as a PDF
    @MainActor
    public func pdfItemProvider(invoice: Invoice, invoiceItems: [InvoiceItem]) async -> NSItemProvider? {
        guard let data = await renderPDFData(invoice: invoice, invoiceItems: invoiceItems) else {
            return nil
        }
        
        let provider = NSItemProvider()
        provider.suggestedName = "Invoice-\(invoice.invoiceNumber).pdf"
        provider.registerDataRepresentation(forTypeIdentifier: UTType.pdf.identifier, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }
}
