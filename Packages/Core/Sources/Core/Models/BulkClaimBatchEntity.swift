import Foundation
import SwiftData

@Model public class BulkClaimBatch {
    #Index<BulkClaimBatch>([\.createdAt], [\.fromDate], [\.toDate], [\.status], [\.exportedAt])

    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var fromDate: Date = Date()
    public var toDate: Date = Date()
    public var status: String = "draft"
    public var includeTravel: Bool = true
    public var includeCancellations: Bool = true
    public var claimReferenceStrategy: String = "invoice_number"
    public var exportFileName: String?
    public var exportedAt: Date?
    public var submittedAt: Date?
    public var rowCount: Int32 = 0
    public var errorCount: Int32 = 0
    public var checksumSHA256: String?
    public var notes: String?

    @Relationship(deleteRule: .cascade, inverse: \BulkClaimLine.batch) public var lines: [BulkClaimLine]?

    public init(id: UUID = UUID()) {
        self.id = id
    }
    
    /// Returns a thread-safe snapshot of the BulkClaimBatch.
    public func snapshot() -> BulkClaimBatchSnapshot {
        BulkClaimBatchSnapshot(self)
    }
}
