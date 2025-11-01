//
//  InvoiceSharingService.swift
//  Feature.Invoices
//
//  Created by AI Assistant for Refactoring Initiative
//
import Foundation
import SwiftUI
import SwiftData
import PDFKit
import UniformTypeIdentifiers
import Data
import SharedUI

// MARK: - Invoice PDF and Sharing Service
public struct InvoiceSharingService {
    @MainActor
    public static func renderPDFData(invoice: InvoiceEntity, business: BusinessEntity, context: ModelContext) -> Data? {
        let sheet = A4InvoiceSheetView(invoice: invoice, business: business)
            .environment(\.modelContext, context)
            .environment(\.colorScheme, .light)
            .background(Color("White", bundle: .sharedUI))
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
    public static func temporaryPDFURL(invoice: InvoiceEntity, business: BusinessEntity, context: ModelContext) -> URL? {
        guard let data = renderPDFData(invoice: invoice, business: business, context: context) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Invoice-\(invoice.invoiceNumber).pdf")
        do { try data.write(to: url) } catch { return nil }
        return url
    }

    @MainActor
    public static func pdfItemProvider(invoice: InvoiceEntity, business: BusinessEntity, context: ModelContext) -> NSItemProvider? {
        guard let data = renderPDFData(invoice: invoice, business: business, context: context) else { return nil }
        let provider = NSItemProvider()
        provider.suggestedName = "Invoice-\(invoice.invoiceNumber).pdf"
        provider.registerDataRepresentation(forTypeIdentifier: UTType.pdf.identifier, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }
}
