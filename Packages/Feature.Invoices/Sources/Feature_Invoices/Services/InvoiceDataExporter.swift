import Foundation
import Core

public struct InvoiceItemExportDTO: Codable, Sendable, Equatable {
    public let id: UUID
    public let itemDescription: String
    public let position: Int32
    public let quantity: Double
    public let rate: Double
    public let unit: String?
    public let gstCode: String?
    public let taxRate: Double
    public let ndisItemNumber: String?
    public let claimType: String?

    public init(item: InvoiceItem) {
        self.id = item.id
        self.itemDescription = item.itemDescription
        self.position = item.position
        self.quantity = item.quantity
        self.rate = item.rate
        self.unit = item.unit
        self.gstCode = item.gstCode
        self.taxRate = item.taxRate
        self.ndisItemNumber = item.ndisItemNumber
        self.claimType = item.claimType?.rawValue
    }

    public init(
        id: UUID,
        itemDescription: String,
        position: Int32,
        quantity: Double,
        rate: Double,
        unit: String?,
        gstCode: String?,
        taxRate: Double,
        ndisItemNumber: String?,
        claimType: String?
    ) {
        self.id = id
        self.itemDescription = itemDescription
        self.position = position
        self.quantity = quantity
        self.rate = rate
        self.unit = unit
        self.gstCode = gstCode
        self.taxRate = taxRate
        self.ndisItemNumber = ndisItemNumber
        self.claimType = claimType
    }
}

public struct InvoiceExportDTO: Codable, Sendable, Equatable {
    public let id: UUID
    public let invoiceNumber: String
    public let issueDate: Date
    public let dueDate: Date?
    public let paidDate: Date?
    public let status: String
    public let totalAmount: Double
    public let currencyCode: String
    public let subtotal: Double
    public let taxRate: Double
    public let taxAmount: Double
    public let discount: Double
    public let creditApplied: Double
    public let notes: String?
    public let paymentTerms: String?
    public let clientName: String?
    public let clientNDISNumber: String?
    public let clientEmail: String?
    public let businessName: String?
    public let businessABN: String?
    public let items: [InvoiceItemExportDTO]

    public init(invoice: Invoice) {
        self.id = invoice.id
        self.invoiceNumber = invoice.invoiceNumber
        self.issueDate = invoice.issueDate
        self.dueDate = invoice.dueDate
        self.paidDate = invoice.paidDate
        self.status = invoice.effectiveStatus.rawValue
        self.totalAmount = invoice.calculatedTotal
        self.currencyCode = invoice.currencyCode
        self.subtotal = invoice.subtotal
        self.taxRate = invoice.taxRate
        self.taxAmount = invoice.taxAmount
        self.discount = invoice.discount
        self.creditApplied = invoice.creditApplied
        self.notes = invoice.notes
        self.paymentTerms = invoice.paymentTerms
        self.clientName = invoice.clientName
        self.clientNDISNumber = invoice.clientNDISNumber
        self.clientEmail = invoice.clientEmail
        self.businessName = invoice.businessName
        self.businessABN = invoice.businessABN
        self.items = invoice.itemsArray.map { InvoiceItemExportDTO(item: $0) }
    }

    public init(
        id: UUID,
        invoiceNumber: String,
        issueDate: Date,
        dueDate: Date?,
        paidDate: Date?,
        status: String,
        totalAmount: Double,
        currencyCode: String,
        subtotal: Double,
        taxRate: Double,
        taxAmount: Double,
        discount: Double,
        creditApplied: Double,
        notes: String?,
        paymentTerms: String?,
        clientName: String?,
        clientNDISNumber: String?,
        clientEmail: String?,
        businessName: String?,
        businessABN: String?,
        items: [InvoiceItemExportDTO]
    ) {
        self.id = id
        self.invoiceNumber = invoiceNumber
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.paidDate = paidDate
        self.status = status
        self.totalAmount = totalAmount
        self.currencyCode = currencyCode
        self.subtotal = subtotal
        self.taxRate = taxRate
        self.taxAmount = taxAmount
        self.discount = discount
        self.creditApplied = creditApplied
        self.notes = notes
        self.paymentTerms = paymentTerms
        self.clientName = clientName
        self.clientNDISNumber = clientNDISNumber
        self.clientEmail = clientEmail
        self.businessName = businessName
        self.businessABN = businessABN
        self.items = items
    }
}

public enum InvoiceDataExporter {
    public static func escapeCSVField(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r")
        if needsQuoting {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }

    public static func exportCSV(invoices: [Invoice]) -> String {
        let shortDateFormatter = ISO8601DateFormatter()
        shortDateFormatter.formatOptions = [.withFullDate]

        let headers = [
            "Invoice Number",
            "Client Name",
            "Client NDIS Number",
            "Issue Date",
            "Due Date",
            "Paid Date",
            "Status",
            "Total Amount",
            "Currency",
            "Subtotal",
            "Tax Rate",
            "Tax Amount",
            "Discount",
            "Notes",
            "Items Count"
        ]

        var csvLines: [String] = [headers.map { escapeCSVField($0) }.joined(separator: ",")]

        for invoice in invoices {
            let issueDateStr = shortDateFormatter.string(from: invoice.issueDate)
            let dueDateStr = invoice.dueDate.map { shortDateFormatter.string(from: $0) } ?? ""
            let paidDateStr = invoice.paidDate.map { shortDateFormatter.string(from: $0) } ?? ""

            let rowValues = [
                invoice.invoiceNumber,
                invoice.clientName ?? "",
                invoice.clientNDISNumber ?? "",
                issueDateStr,
                dueDateStr,
                paidDateStr,
                invoice.effectiveStatus.rawValue,
                String(format: "%.2f", invoice.calculatedTotal),
                invoice.currencyCode,
                String(format: "%.2f", invoice.subtotal),
                String(format: "%.2f", invoice.taxRate),
                String(format: "%.2f", invoice.taxAmount),
                String(format: "%.2f", invoice.discount),
                invoice.notes ?? "",
                "\(invoice.itemsArray.count)"
            ]

            let formattedRow = rowValues.map { escapeCSVField($0) }.joined(separator: ",")
            csvLines.append(formattedRow)
        }

        return csvLines.joined(separator: "\r\n")
    }

    public static func exportJSONData(invoices: [Invoice]) throws -> Data {
        let dtos = invoices.map { InvoiceExportDTO(invoice: $0) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(dtos)
    }

    public static func exportJSONString(invoices: [Invoice]) throws -> String {
        let data = try exportJSONData(invoices: invoices)
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}
