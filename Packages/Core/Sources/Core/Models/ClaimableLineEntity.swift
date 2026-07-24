import Foundation
import SwiftData

@Model public class ClaimableLine {
    #Index<ClaimableLine>([\.claimType])

    public var id: UUID = UUID()
    public var claimType: String = ""
    public var supportItemNumber: String = ""
    public var serviceFrom: Date = Date()
    public var serviceTo: Date = Date()
    public var quantityDecimal: Double?
    public var hoursHHHMM: String?
    public var unitPrice: Double = 0.0
    public var gstCode: String = ""
    public var cancellationReason: String?
    public var travelKM: Double?
    public var travelMinutes: Int32?
    public var metadata: Data?
    public var claimReference: String?

    public var draftId: UUID = UUID()
    @Relationship(deleteRule: .nullify) public var draft: BillableDraft?
    @Relationship(deleteRule: .nullify, inverse: \BulkClaimLine.claimableLines) public var bulkClaimLine: BulkClaimLine?

    public init(
        id: UUID,
        draftId: UUID,
        claimType: String,
        supportItemNumber: String,
        serviceFrom: Date,
        serviceTo: Date,
        quantityDecimal: Double? = nil,
        hoursHHHMM: String? = nil,
        unitPrice: Double,
        gstCode: String,
        cancellationReason: String? = nil,
        travelKM: Double? = nil,
        travelMinutes: Int32? = nil,
        metadata: Data? = nil,
        claimReference: String? = nil
    ) {
        self.id = id
        self.draftId = draftId
        self.claimType = claimType
        self.supportItemNumber = supportItemNumber
        self.serviceFrom = serviceFrom
        self.serviceTo = serviceTo
        self.quantityDecimal = quantityDecimal
        self.hoursHHHMM = hoursHHHMM
        self.unitPrice = unitPrice
        self.gstCode = gstCode
        self.cancellationReason = cancellationReason
        self.travelKM = travelKM
        self.travelMinutes = travelMinutes
        self.metadata = metadata
        self.claimReference = claimReference
    }
    
    /// Returns a thread-safe snapshot of the ClaimableLine.
    public func snapshot() -> ClaimableLineSnapshot {
        ClaimableLineSnapshot(self)
    }
}
