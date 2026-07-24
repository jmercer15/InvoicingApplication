import Foundation
import SwiftData

@Model public class BulkClaimLine {
    #Index<BulkClaimLine>(
        [\.registrationNumber],
        [\.ndisNumber],
        [\.supportNumber],
        [\.claimTypeCode],
        [\.gstCode],
        [\.isValid]
    )

    public var id: UUID = UUID()
    public var registrationNumber: String = ""
    public var ndisNumber: String = ""
    public var supportsDeliveredFrom: Date = Date()
    public var supportsDeliveredTo: Date = Date()
    public var supportNumber: String = ""
    public var claimReference: String?
    public var quantity: Double?
    public var hours: String?
    public var unitPrice: Double = 0.0
    public var gstCode: String = "P2"
    public var authorisedBy: String?
    public var participantApproved: String?
    public var inKindFundingProgram: String?
    public var claimTypeCode: String?
    public var cancellationReason: String?
    public var abnOfSupportProvider: String?
    public var draftLineId: UUID?
    public var isValid: Bool = true
    public var validationErrorSummary: String?
    public var submissionStatus: String?
    public var submissionRef: String?
    public var reconciliationNotes: String?
    public var reconciledAt: Date?
    public var ndiaPaidAmount: Double?
    public var ndiaErrorCode: String?
    public var ndiaErrorMessage: String?

    @Relationship(deleteRule: .nullify) public var batch: BulkClaimBatch?
    @Relationship(deleteRule: .nullify, inverse: \Invoice.bulkClaimLines) public var invoice: Invoice?
    @Relationship(deleteRule: .nullify, inverse: \InvoiceItem.bulkClaimLines) public var invoiceItem: InvoiceItem?
    public var claimableLines: [ClaimableLine]?

    public init(id: UUID = UUID()) {
        self.id = id
    }
    
    /// Returns a thread-safe snapshot of the BulkClaimLine.
    public func snapshot() -> BulkClaimLineSnapshot {
        BulkClaimLineSnapshot(self)
    }
}
