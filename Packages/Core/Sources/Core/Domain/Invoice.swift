import Foundation

/// Domain model for an invoice
public struct Invoice: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let invoiceNumber: String
    public let totalAmount: Double
    public let taxRate: Double
    public let creditApplied: Double
    public let discount: Double
    public let date: Date
    public let dueDate: Date?
    public let invoiceID: Int32?
    public let issueDate: Date
    public let notes: String?
    public let paidDate: Date?
    public let paymentTerms: String?
    public let status: String?
    public let sentDate: Date?
    public let currencyCode: String
    
    // Business Information (snapshot)
    public let businessName: String?
    public let businessABN: String?
    public let businessEmail: String?
    public let businessAddress: String?
    public let businessPhone: String?
    
    // Client Information (snapshot)
    public let clientName: String?
    public let clientNDISNumber: String?
    public let clientEmail: String?
    public let clientPhone: String?
    public let clientAddress: String?
    
    // Billing Information (snapshot)
    public let billingAuthority: String?
    public let billToName: String?
    public let billToEmail: String?
    public let billToAddress: String?
    
    // Payee Information (snapshot)
    public let payeeName: String?
    public let payeeEmail: String?
    public let payeePhone: String?
    public let payeeAddress: String?
    
    // Payment Details (snapshot)
    public let bankName: String?
    public let bankAccountName: String?
    public let bankBSB: String?
    public let bankAccountNumber: String?
    
    // Relationships
    public let clientId: UUID?
    public let businessId: UUID?
    public let payeeId: UUID?
    public let sessionIds: [UUID]
    
    public init(
        id: UUID,
        invoiceNumber: String,
        totalAmount: Double = 0.0,
        taxRate: Double = 0.0,
        creditApplied: Double = 0.0,
        discount: Double = 0.0,
        date: Date = Date(),
        dueDate: Date? = nil,
        invoiceID: Int32? = nil,
        issueDate: Date = Date(),
        notes: String? = nil,
        paidDate: Date? = nil,
        paymentTerms: String? = nil,
        status: String? = nil,
        sentDate: Date? = nil,
        currencyCode: String = "AUD",
        businessName: String? = nil,
        businessABN: String? = nil,
        businessEmail: String? = nil,
        businessAddress: String? = nil,
        businessPhone: String? = nil,
        clientName: String? = nil,
        clientNDISNumber: String? = nil,
        clientEmail: String? = nil,
        clientPhone: String? = nil,
        clientAddress: String? = nil,
        billingAuthority: String? = nil,
        billToName: String? = nil,
        billToEmail: String? = nil,
        billToAddress: String? = nil,
        payeeName: String? = nil,
        payeeEmail: String? = nil,
        payeePhone: String? = nil,
        payeeAddress: String? = nil,
        bankName: String? = nil,
        bankAccountName: String? = nil,
        bankBSB: String? = nil,
        bankAccountNumber: String? = nil,
        clientId: UUID? = nil,
        businessId: UUID? = nil,
        payeeId: UUID? = nil,
        sessionIds: [UUID] = []
    ) {
        self.id = id
        self.invoiceNumber = invoiceNumber
        self.totalAmount = totalAmount
        self.taxRate = taxRate
        self.creditApplied = creditApplied
        self.discount = discount
        self.date = date
        self.dueDate = dueDate
        self.invoiceID = invoiceID
        self.issueDate = issueDate
        self.notes = notes
        self.paidDate = paidDate
        self.paymentTerms = paymentTerms
        self.status = status
        self.sentDate = sentDate
        self.currencyCode = currencyCode
        self.businessName = businessName
        self.businessABN = businessABN
        self.businessEmail = businessEmail
        self.businessAddress = businessAddress
        self.businessPhone = businessPhone
        self.clientName = clientName
        self.clientNDISNumber = clientNDISNumber
        self.clientEmail = clientEmail
        self.clientPhone = clientPhone
        self.clientAddress = clientAddress
        self.billingAuthority = billingAuthority
        self.billToName = billToName
        self.billToEmail = billToEmail
        self.billToAddress = billToAddress
        self.payeeName = payeeName
        self.payeeEmail = payeeEmail
        self.payeePhone = payeePhone
        self.payeeAddress = payeeAddress
        self.bankName = bankName
        self.bankAccountName = bankAccountName
        self.bankBSB = bankBSB
        self.bankAccountNumber = bankAccountNumber
        self.clientId = clientId
        self.businessId = businessId
        self.payeeId = payeeId
        self.sessionIds = sessionIds
    }
    
    /// Check if invoice is overdue
    public var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return dueDate < Date() && status != "paid"
    }
    
    /// Days until due (negative if overdue)
    public var daysUntilDue: Int? {
        guard let dueDate = dueDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day
    }
    
    /// Formatted invoice number for display
    public var formattedInvoiceNumber: String {
        invoiceNumber.isEmpty ? "Draft" : invoiceNumber
    }
}

/// Domain model for an invoice item
public struct InvoiceItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let invoiceId: UUID
    public let sessionId: UUID?
    public let clientServiceId: UUID?
    public let itemDescription: String
    public let quantity: Double
    public let rate: Double
    public let position: Int32
    
    public init(
        id: UUID,
        invoiceId: UUID,
        sessionId: UUID? = nil,
        clientServiceId: UUID? = nil,
        itemDescription: String,
        quantity: Double,
        rate: Double,
        position: Int32 = 0
    ) {
        self.id = id
        self.invoiceId = invoiceId
        self.sessionId = sessionId
        self.clientServiceId = clientServiceId
        self.itemDescription = itemDescription
        self.quantity = quantity
        self.rate = rate
        self.position = position
    }
    
    /// Calculated line total
    public var lineTotal: Double {
        quantity * rate
    }
}
