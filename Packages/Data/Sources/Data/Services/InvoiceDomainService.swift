//
//  InvoiceDomainService.swift
//  Data
//
//  Domain service for invoice business operations
//

import Foundation
import SwiftData
import Core
import CoreGraphics
import CoreText

/// Implementation of InvoiceDomainServiceProtocol.
/// Encapsulates complex invoice operations including session billing.
@MainActor
public final class InvoiceDomainService: InvoiceDomainServiceProtocol, @unchecked Sendable {
    
    // MARK: - Dependencies
    
    private let unitOfWork: UnitOfWorkService
    
    // MARK: - Initialization
    
    public init(unitOfWork: UnitOfWorkService) {
        self.unitOfWork = unitOfWork
    }
    
    // MARK: - InvoiceDomainServiceProtocol
    
    public func createInvoiceFromSessions(_ sessionIds: [UUID], clientId: UUID) async throws -> Invoice {
        // Create invoice using repository
        let invoice = try await unitOfWork.invoices.createFromSessions(sessionIds, clientId: clientId)
        
        // Move sessions along the billing workflow to readyToSend
        for sessionId in sessionIds {
            try await unitOfWork.sessions.updateBillingStatus(id: sessionId, status: .readyToSend)
        }
        
        try await unitOfWork.saveChanges()
        return invoice
    }
    
    public func updateInvoiceStatus(_ invoiceId: UUID, status: String) async throws -> Invoice {
        try await unitOfWork.invoices.updateStatus(id: invoiceId, status: status)
        
        guard let updatedInvoice = try await unitOfWork.invoices.fetch(by: invoiceId) else {
            throw DomainServiceError.entityNotFound(type: "Invoice", id: invoiceId)
        }
        
        try await unitOfWork.saveChanges()
        return updatedInvoice
    }
    
    public func generatePDF(for invoiceId: UUID) async throws -> URL {
        guard let invoice = try await unitOfWork.invoices.fetch(by: invoiceId) else {
            throw DomainServiceError.entityNotFound(type: "Invoice", id: invoiceId)
        }
        let items = try await unitOfWork.invoices.fetchItems(by: invoiceId)
        let pdfData = try renderInvoicePDF(invoice: invoice, items: items)

        let sanitizedInvoiceNumber = invoice.invoiceNumber
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
        let fileName = "invoice-\(sanitizedInvoiceNumber.isEmpty ? invoice.id.uuidString : sanitizedInvoiceNumber).pdf"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try pdfData.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            throw DomainServiceError.invalidOperation(
                message: "Failed to write invoice PDF: \(error.localizedDescription)"
            )
        }
    }
    
    public func markSessionsAsBilled(for invoiceId: UUID) async throws {
        // Fetch invoice items to get session IDs
        let items = try await unitOfWork.invoices.fetchItems(by: invoiceId)
        
        for item in items {
            if let sessionId = item.sessionId {
                try await unitOfWork.sessions.updateBillingStatus(id: sessionId, status: .pending)
            }
        }
        
        try await unitOfWork.saveChanges()
    }
    
    public func generateNextInvoiceNumber(for client: Client?) async throws -> String {
        let allInvoices = try await unitOfWork.invoices.fetchAll()
        
        if let client = client {
            let nameParts = client.fullName.split(separator: " ").map { String($0) }
            if let first = nameParts.first, let last = nameParts.last, !first.isEmpty, !last.isEmpty {
                let surnamePart = String(last.uppercased().prefix(4))
                let firstInitial = String(first.uppercased().prefix(1))
                let prefix = "\(surnamePart)-\(firstInitial)-"
                
                // Filter for client specific prefix matches using in-memory filter since repository returns all
                // Optimally we would push this down to repository query, but strictly speaking of porting logic:
                let clientInvoices = allInvoices.filter {
                    $0.invoiceNumber.starts(with: prefix) && $0.clientId == client.id
                }
                
                let suffixes = clientInvoices.compactMap { inv -> Int? in
                    guard inv.invoiceNumber.starts(with: prefix) else { return nil }
                    return Int(String(inv.invoiceNumber.dropFirst(prefix.count)))
                }
                
                let next = (suffixes.max() ?? 0) + 1
                return "\(prefix)\(String(format: "%04d", next))"
            }
        }
        
        // Generic fallback INV-####
        let suffixes = allInvoices.compactMap { inv -> Int? in
            let parts = inv.invoiceNumber.split(separator: "-")
            guard parts.count >= 2 else { return nil }
            return Int(parts.last!)
        }
        
        let next = (suffixes.max() ?? 0) + 1
        return String(format: "INV-%04d", next)
    }

    // MARK: - PDF Rendering

    private func renderInvoicePDF(invoice: Invoice, items: [InvoiceItem]) throws -> Data {
        let output = NSMutableData()
        guard let consumer = CGDataConsumer(data: output as CFMutableData) else {
            throw DomainServiceError.invalidOperation(message: "Unable to create PDF consumer")
        }

        var mediaBox = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 in points
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw DomainServiceError.invalidOperation(message: "Unable to create PDF context")
        }

        context.beginPDFPage(nil)
        context.translateBy(x: 0, y: mediaBox.height)
        context.scaleBy(x: 1, y: -1)

        let titleFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 20, nil)
        let headingFont = CTFontCreateWithName("Helvetica-Bold" as CFString, 12, nil)
        let bodyFont = CTFontCreateWithName("Helvetica" as CFString, 11, nil)

        var y: CGFloat = 52
        draw("Tax Invoice", atX: 40, y: y, font: titleFont, context: context)
        y += 30

        draw("Invoice Number: \(invoice.invoiceNumber)", atX: 40, y: y, font: headingFont, context: context)
        y += 18
        draw("Issue Date: \(formatDate(invoice.issueDate))", atX: 40, y: y, font: bodyFont, context: context)
        y += 16
        if let dueDate = invoice.dueDate {
            draw("Due Date: \(formatDate(dueDate))", atX: 40, y: y, font: bodyFont, context: context)
            y += 16
        }
        if let clientName = invoice.clientName, !clientName.isEmpty {
            draw("Client: \(clientName)", atX: 40, y: y, font: bodyFont, context: context)
            y += 16
        }
        if let businessName = invoice.businessName, !businessName.isEmpty {
            draw("Business: \(businessName)", atX: 40, y: y, font: bodyFont, context: context)
            y += 16
        }

        y += 14
        draw("Line Items", atX: 40, y: y, font: headingFont, context: context)
        y += 18
        context.setStrokeColor(CGColor(gray: 0.8, alpha: 1))
        context.stroke(CGRect(x: 40, y: y, width: mediaBox.width - 80, height: 1))
        y += 14

        let maxTextWidth: Int = 58
        for item in items {
            if y > mediaBox.height - 120 {
                context.endPDFPage()
                context.beginPDFPage(nil)
                context.translateBy(x: 0, y: mediaBox.height)
                context.scaleBy(x: 1, y: -1)
                y = 52
            }

            for line in wrapped(item.itemDescription, maxLength: maxTextWidth) {
                draw(line, atX: 40, y: y, font: bodyFont, context: context)
                y += 14
            }
            draw("Qty \(item.quantity.cleanNumberString) × \(formatCurrency(item.rate))", atX: 50, y: y, font: bodyFont, context: context)
            draw(formatCurrency(item.lineTotal), atX: mediaBox.width - 140, y: y, font: bodyFont, context: context)
            y += 18
        }

        y += 8
        context.setStrokeColor(CGColor(gray: 0.8, alpha: 1))
        context.stroke(CGRect(x: 40, y: y, width: mediaBox.width - 80, height: 1))
        y += 16
        draw("Total: \(formatCurrency(invoice.totalAmount))", atX: mediaBox.width - 220, y: y, font: headingFont, context: context)

        context.endPDFPage()
        context.closePDF()
        return output as Data
    }

    private func draw(_ text: String, atX x: CGFloat, y: CGFloat, font: CTFont, context: CGContext) {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0.1, alpha: 1)
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
    }

    private func wrapped(_ text: String, maxLength: Int) -> [String] {
        guard text.count > maxLength else { return [text] }

        var lines: [String] = []
        var current = ""
        for word in text.split(separator: " ") {
            let candidate = current.isEmpty ? String(word) : "\(current) \(word)"
            if candidate.count <= maxLength {
                current = candidate
            } else {
                if !current.isEmpty { lines.append(current) }
                current = String(word)
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }
}

private extension Double {
    var cleanNumberString: String {
        if truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(self))
        }
        return String(format: "%.2f", self)
    }
}
