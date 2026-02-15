import Foundation
import SwiftData

@Model public class BulkClaimLineEntity {
    #Index<BulkClaimLineEntity>(
        [\.registrationNumber],
        [\.ndisNumber],
        [\.supportNumber],
        [\.claimTypeCode],
        [\.gstCode],
        [\.isValid]
    )

    public var id: UUID
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
    public var isValid: Bool = true
    public var validationErrorSummary: String?
    public var submissionStatus: String?
    public var submissionRef: String?
    public var reconciliationNotes: String?
    public var reconciledAt: Date?

    @Relationship(deleteRule: .nullify) public var batch: BulkClaimBatchEntity?
    @Relationship(deleteRule: .nullify) public var invoice: InvoiceEntity?
    @Relationship(deleteRule: .nullify) public var invoiceItem: InvoiceItemEntity?

    public init(id: UUID) {
        self.id = id
    }
}
