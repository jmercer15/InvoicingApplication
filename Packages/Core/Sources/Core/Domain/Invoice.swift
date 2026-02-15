import Foundation

/// Domain model for an invoice
public struct Invoice: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var invoiceNumber: String
    public var totalAmount: Double
    public var taxRate: Double
    public var creditApplied: Double
    public var discount: Double
    public var date: Date
    public var dueDate: Date?
    public var issueDate: Date
    public var notes: String?
    public var paidDate: Date?
    public var paymentTerms: String?
    public var status: String
    public var sentDate: Date?
    public var currencyCode: String
    
    // Business Information (snapshot)
    public var businessName: String?
    public var businessABN: String?
    public var businessEmail: String?
    public var businessAddress: Address?
    public var businessPhone: String?
    
    // Client Information (snapshot)
    public var clientName: String?
    public var clientNDISNumber: String?
    public var clientEmail: String?
    public var clientPhone: String?
    public var clientAddress: Address?
    
    // Billing Information (snapshot)
    public var billingAuthority: String?
    public var billToName: String?
    public var billToEmail: String?
    public var billToAddress: Address?
    
    // Payee Information (snapshot)
    public var payeeName: String?
    public var payeeEmail: String?
    public var payeePhone: String?
    public var payeeAddress: Address?
    
    // Payment Details (snapshot)
    public var bankName: String?
    public var bankAccountName: String?
    public var bankBSB: String?
    public var bankAccountNumber: String?
    
    // Relationships
    public var clientId: UUID?
    public var businessId: UUID?
    public var payeeId: UUID?
    public var templateId: UUID?
    public var sessionIds: [UUID]
    
    public init(
        id: UUID,
        invoiceNumber: String,
        totalAmount: Double = 0.0,
        taxRate: Double = 0.0,
        creditApplied: Double = 0.0,
        discount: Double = 0.0,
        date: Date = Date(),
        dueDate: Date? = nil,
        issueDate: Date = Date(),
        notes: String? = nil,
        paidDate: Date? = nil,
        paymentTerms: String? = nil,
        status: String = "review_draft",
        sentDate: Date? = nil,
        currencyCode: String = "AUD",
        businessName: String? = nil,
        businessABN: String? = nil,
        businessEmail: String? = nil,
        businessAddress: Address? = nil,
        businessPhone: String? = nil,
        clientName: String? = nil,
        clientNDISNumber: String? = nil,
        clientEmail: String? = nil,
        clientPhone: String? = nil,
        clientAddress: Address? = nil,
        billingAuthority: String? = nil,
        billToName: String? = nil,
        billToEmail: String? = nil,
        billToAddress: Address? = nil,
        payeeName: String? = nil,
        payeeEmail: String? = nil,
        payeePhone: String? = nil,
        payeeAddress: Address? = nil,
        bankName: String? = nil,
        bankAccountName: String? = nil,
        bankBSB: String? = nil,
        bankAccountNumber: String? = nil,
        clientId: UUID? = nil,
        businessId: UUID? = nil,
        payeeId: UUID? = nil,
        templateId: UUID? = nil,
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
        self.templateId = templateId
        self.sessionIds = sessionIds
    }
    
    /// Check if invoice is overdue
    public var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        let isSettled = status == "received"
        return dueDate < Date() && !isSettled
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
    public var id: UUID
    public var invoiceId: UUID
    public var sessionId: UUID?
    public var clientServiceId: UUID?
    public var itemDescription: String
    public var quantity: Double
    public var rate: Double
    public var position: Int32
    
    // Snapshot fields
    public var serviceDate: Date
    public var ndisItemNumber: String?
    public var claimType: String?
    public var unit: String?
    public var gstCode: String?
    public var taxRate: Double
    
    // NDIS Fields
    public var ndisSupportCategory: String?
    public var ndisRegistrationGroup: String?
    public var ndisOutcomeDomain: String?
    public var ndisSupportPurpose: String?
    public var isComplexBehaviour: Bool
    public var isHighIntensity: Bool
    public var geographicLoading: Double
    public var timeModifier: Double
    public var groupModifier: Double
    public var finalRateLimit: Double
    
    public init(
        id: UUID,
        invoiceId: UUID,
        sessionId: UUID? = nil,
        clientServiceId: UUID? = nil,
        itemDescription: String,
        quantity: Double,
        rate: Double,
        position: Int32 = 0,
        serviceDate: Date = Date(),
        ndisItemNumber: String? = nil,
        claimType: String? = nil,
        unit: String? = nil,
        gstCode: String? = nil,
        taxRate: Double = 0.0,
        ndisSupportCategory: String? = nil,
        ndisRegistrationGroup: String? = nil,
        ndisOutcomeDomain: String? = nil,
        ndisSupportPurpose: String? = nil,
        isComplexBehaviour: Bool = false,
        isHighIntensity: Bool = false,
        geographicLoading: Double = 1.0,
        timeModifier: Double = 1.0,
        groupModifier: Double = 1.0,
        finalRateLimit: Double = 0.0
    ) {
        self.id = id
        self.invoiceId = invoiceId
        self.sessionId = sessionId
        self.clientServiceId = clientServiceId
        self.itemDescription = itemDescription
        self.quantity = quantity
        self.rate = rate
        self.position = position
        self.serviceDate = serviceDate
        self.ndisItemNumber = ndisItemNumber
        self.claimType = claimType
        self.unit = unit
        self.gstCode = gstCode
        self.taxRate = taxRate
        self.ndisSupportCategory = ndisSupportCategory
        self.ndisRegistrationGroup = ndisRegistrationGroup
        self.ndisOutcomeDomain = ndisOutcomeDomain
        self.ndisSupportPurpose = ndisSupportPurpose
        self.isComplexBehaviour = isComplexBehaviour
        self.isHighIntensity = isHighIntensity
        self.geographicLoading = geographicLoading
        self.timeModifier = timeModifier
        self.groupModifier = groupModifier
        self.finalRateLimit = finalRateLimit
    }
    
    /// Calculated line total
    public var lineTotal: Double {
        quantity * rate
    }
}
