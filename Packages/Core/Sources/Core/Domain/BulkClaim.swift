import Foundation

public struct BulkClaimBatch: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let fromDate: Date
    public let toDate: Date
    public let status: String
    public let includeTravel: Bool
    public let includeCancellations: Bool
    public let claimReferenceStrategy: String
    public let exportFileName: String?
    public let exportedAt: Date?
    public let rowCount: Int
    public let errorCount: Int
    public let checksumSHA256: String?
    public let notes: String?

    public init(
        id: UUID,
        createdAt: Date = Date(),
        fromDate: Date,
        toDate: Date,
        status: String = BulkClaimBatchStatus.draft.rawValue,
        includeTravel: Bool = true,
        includeCancellations: Bool = true,
        claimReferenceStrategy: String = "invoice_number",
        exportFileName: String? = nil,
        exportedAt: Date? = nil,
        rowCount: Int = 0,
        errorCount: Int = 0,
        checksumSHA256: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.fromDate = fromDate
        self.toDate = toDate
        self.status = status
        self.includeTravel = includeTravel
        self.includeCancellations = includeCancellations
        self.claimReferenceStrategy = claimReferenceStrategy
        self.exportFileName = exportFileName
        self.exportedAt = exportedAt
        self.rowCount = rowCount
        self.errorCount = errorCount
        self.checksumSHA256 = checksumSHA256
        self.notes = notes
    }
}

public struct BulkClaimLine: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let batchId: UUID
    public let registrationNumber: String
    public let ndisNumber: String
    public let supportsDeliveredFrom: Date
    public let supportsDeliveredTo: Date
    public let supportNumber: String
    public let claimReference: String?
    public let quantity: Double?
    public let hours: String?
    public let unitPrice: Double
    public let gstCode: String
    public let authorisedBy: String?
    public let participantApproved: String?
    public let inKindFundingProgram: String?
    public let claimTypeCode: String?
    public let cancellationReason: String?
    public let abnOfSupportProvider: String?
    public let invoiceId: UUID?
    public let invoiceItemId: UUID?
    public let isValid: Bool
    public let validationErrorSummary: String?
    public let submissionStatus: String?
    public let submissionRef: String?
    public let reconciliationNotes: String?
    public let reconciledAt: Date?

    public init(
        id: UUID,
        batchId: UUID,
        registrationNumber: String,
        ndisNumber: String,
        supportsDeliveredFrom: Date,
        supportsDeliveredTo: Date,
        supportNumber: String,
        claimReference: String? = nil,
        quantity: Double? = nil,
        hours: String? = nil,
        unitPrice: Double,
        gstCode: String = GSTCode.p2.rawValue,
        authorisedBy: String? = nil,
        participantApproved: String? = nil,
        inKindFundingProgram: String? = nil,
        claimTypeCode: String? = nil,
        cancellationReason: String? = nil,
        abnOfSupportProvider: String? = nil,
        invoiceId: UUID? = nil,
        invoiceItemId: UUID? = nil,
        isValid: Bool = true,
        validationErrorSummary: String? = nil,
        submissionStatus: String? = nil,
        submissionRef: String? = nil,
        reconciliationNotes: String? = nil,
        reconciledAt: Date? = nil
    ) {
        self.id = id
        self.batchId = batchId
        self.registrationNumber = registrationNumber
        self.ndisNumber = ndisNumber
        self.supportsDeliveredFrom = supportsDeliveredFrom
        self.supportsDeliveredTo = supportsDeliveredTo
        self.supportNumber = supportNumber
        self.claimReference = claimReference
        self.quantity = quantity
        self.hours = hours
        self.unitPrice = unitPrice
        self.gstCode = gstCode
        self.authorisedBy = authorisedBy
        self.participantApproved = participantApproved
        self.inKindFundingProgram = inKindFundingProgram
        self.claimTypeCode = claimTypeCode
        self.cancellationReason = cancellationReason
        self.abnOfSupportProvider = abnOfSupportProvider
        self.invoiceId = invoiceId
        self.invoiceItemId = invoiceItemId
        self.isValid = isValid
        self.validationErrorSummary = validationErrorSummary
        self.submissionStatus = submissionStatus
        self.submissionRef = submissionRef
        self.reconciliationNotes = reconciliationNotes
        self.reconciledAt = reconciledAt
    }
}
