//
//  InvoiceSharingService.swift
//  Feature.Invoices
//
//  Created by AI Assistant for Refactoring Initiative
//
import Foundation
import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import Core
import SharedUI

// MARK: - Invoice PDF and Sharing Service
public struct InvoiceSharingService {
    @MainActor
    public static func renderPDFData(invoice: Invoice, invoiceItems: [InvoiceItem]) -> Data? {
        let sheet = SharedUI.A4InvoiceSheetView(invoice: invoice, invoiceItems: invoiceItems)
            .environment(\.colorScheme, .light)
            .background(Color(NSColor.windowBackgroundColor))
            .frame(width: 595, height: 842)

        let renderer = ImageRenderer(content: sheet)
        renderer.proposedSize = .init(width: 595, height: 842)
        renderer.scale = 3.0
        renderer.isOpaque = true
        if let cg = renderer.cgImage {
            let nsImage = NSImage(cgImage: cg, size: NSSize(width: 595, height: 842))
            guard let page = PDFPage(image: nsImage) else { return nil }
            let doc = PDFDocument()
            doc.insert(page, at: 0)
            return doc.dataRepresentation()
        }
        if let ns = renderer.nsImage, let page = PDFPage(image: ns) {
            let doc = PDFDocument()
            doc.insert(page, at: 0)
            return doc.dataRepresentation()
        }
        return nil
    }

    @MainActor
    public static func temporaryPDFURL(invoice: Invoice, invoiceItems: [InvoiceItem]) -> URL? {
        guard let data = renderPDFData(invoice: invoice, invoiceItems: invoiceItems) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Invoice-\(invoice.invoiceNumber).pdf")
        do { try data.write(to: url) } catch { return nil }
        return url
    }

    @MainActor
    public static func pdfItemProvider(invoice: Invoice, invoiceItems: [InvoiceItem]) -> NSItemProvider? {
        guard let data = renderPDFData(invoice: invoice, invoiceItems: invoiceItems) else { return nil }
        let provider = NSItemProvider()
        provider.suggestedName = "Invoice-\(invoice.invoiceNumber).pdf"
        provider.registerDataRepresentation(forTypeIdentifier: UTType.pdf.identifier, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }
}
