//
//  InvoiceTemplateRendererView.swift
//  Feature.Invoices
//
//  Created by AI Assistant for Refactoring Initiative
//

import SwiftUI
import Core
import Feature_InvoiceTemplateEditor

/// A view that renders an invoice using the template system.
/// It wraps InvoiceCanvasView and manages the InvoiceDocument.
struct InvoiceTemplateRendererView: View {
    let invoice: Invoice
    let invoiceItems: [InvoiceItem]? // Optional override items
    @ObservedObject var templateDataService: TemplateDataService
    
    // Create a local document instance for rendering
    @StateObject private var document = InvoiceDocument()
    @State private var lastTemplateId: UUID?
    
    init(invoice: Invoice, invoiceItems: [InvoiceItem]? = nil, templateDataService: TemplateDataService) {
        self.invoice = invoice
        self.invoiceItems = invoiceItems
        self.templateDataService = templateDataService
    }
    
    var body: some View {
        InvoiceCanvasView(document: document)
            .environmentObject(document)
            .environmentObject(templateDataService) // Canvas needs this
            .onAppear {
                loadTemplate()
            }
            .onChange(of: invoice) { _, newInvoice in
                updateData(invoice: newInvoice, items: invoiceItems)
            }
            .onChange(of: invoiceItems) { _, newItems in
                updateData(invoice: invoice, items: newItems)
            }
    }
    
    private func updateData(invoice: Invoice, items: [InvoiceItem]?) {
        Task {
            await templateDataService.setSelectedInvoice(invoice, items: items)
            
            if invoice.templateId != lastTemplateId {
                loadTemplate()
            }
        }
    }
    
    private func loadTemplate() {
        Task {
            // Ensure the data service has the correct invoice and items
            await templateDataService.setSelectedInvoice(invoice, items: invoiceItems)
            
            let manager = TemplateManager()
            let templatesList = await manager.browseTemplates()
            
            var selectedMetadata: TemplateMetadata?
            
            // Try to find the requested template
            if let templateId = invoice.templateId {
                selectedMetadata = templatesList.first(where: { $0.id == templateId })
            }
            
            // Fallback to first available template if not found or not specified
            if selectedMetadata == nil {
                selectedMetadata = templatesList.first
            }
            
            if let metadata = selectedMetadata,
               let data = await manager.loadTemplate(metadata: metadata) {
                await MainActor.run {
                    document.loadTemplate(data)
                    lastTemplateId = invoice.templateId
                }
            }
        }
    }
}
