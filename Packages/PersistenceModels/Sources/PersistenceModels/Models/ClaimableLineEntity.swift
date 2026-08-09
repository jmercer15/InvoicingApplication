import Foundation
import Core
import SwiftData

@Model public class ClaimableLine {
    #Index<ClaimableLine>([\.claimType])

    public var id: UUID = UUID()
    public var claimType: String = ""
    public var supportItemNumber: String = ""
    public var serviceFrom: Date = Date()
    public var serviceTo: Date = Date()
    /// CloudKit forbids attribute renames; physical `*Decimal` names stay stable.
    public var quantityDecimal: Decimal?
    public var quantity: Decimal? {
        get { quantityDecimal }
        set { quantityDecimal = newValue }
    }
    public var hoursHHHMM: String?
    public var unitPrice: Decimal = 0
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
        quantity: Decimal? = nil,
        hoursHHHMM: String? = nil,
        unitPrice: Decimal,
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
        self.quantityDecimal = quantity
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
