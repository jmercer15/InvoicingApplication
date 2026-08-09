import Foundation

/// JSON model for individual invoice items in the legacy format
struct LegacyInvoiceItemPayload: Codable {
    let id: String?
    let name: String
    let quantity: Int
    let unitPrice: Double
}

/// JSON model for the actual invoice data from external systems
struct LegacyInvoicePayload: Codable {
    let id: String?
    let invoiceNumber: String
    let issueDate: String?
    let dueDate: String?
    let serviceIDs: [Int]?
    let items: [LegacyInvoiceItemPayload]?
    let totalAmount: Double?
    let gstComponent: Double?
    let status: String?
}

/// Wrapper for bulk invoice data
struct LegacyInvoiceEnvelope: Codable {
    let invoices: [LegacyInvoicePayload]?
}

/// JSON model for individual items in the modern import format
struct TabularInvoiceItemPayload: Codable {
    let description: String
    let quantity: Int
    let unitPrice: Double
    
    enum CodingKeys: String, CodingKey {
        case description = "Description"
        case quantity = "Quantity"
        case unitPrice = "Unit Price"
    }
}

/// JSON model for the modern invoice import format
struct TabularInvoicePayload: Codable {
    let invoiceNumber: String
    let issueDate: String?
    let dueDate: String?
    let clientName: String
    let items: [TabularInvoiceItemPayload]?
    let totalAmount: Double?
    let gstComponent: Double?
    let status: String?
    
    enum CodingKeys: String, CodingKey {
        case invoiceNumber = "Invoice Number"
        case issueDate = "Issue Date"
        case dueDate = "Due Date"
        case clientName = "Client Name"
        case items = "Items"
        case totalAmount = "Total Amount"
        case gstComponent = "GST Component"
        case status = "Status"
    }
    
    /// Converts tabular input to canonical import-patch semantics.
    func toImportPayload() -> InvoiceImportPayload {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let issueDateParsed = issueDate.flatMap { dateFormatter.date(from: $0) }
        let dueDateParsed = dueDate.flatMap { dateFormatter.date(from: $0) }
        
        let userData = try? JSONEncoder().encode(self)
        
        return InvoiceImportPayload(
            invoiceNumber: invoiceNumber,
            dateIssued: issueDateParsed,
            dateIssuedString: issueDate,
            dateDue: dueDateParsed,
            dateDueString: dueDate,
            totalAmount: totalAmount,
            totalAmountString: totalAmount != nil ? String(totalAmount!) : nil,
            status: status,
            clientName: clientName,
            userData: userData
        )
    }
}
