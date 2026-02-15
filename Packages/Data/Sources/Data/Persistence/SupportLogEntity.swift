import Foundation
import SwiftData

@Model public class SupportLogEntity {
    #Index<SupportLogEntity>([\.deliveredFrom], [\.deliveredTo], [\.supportItemNumber], [\.participantNdisNumber])

    public var id: UUID
    public var participantName: String = ""
    public var participantNdisNumber: String = ""
    public var supportItemNumber: String = ""
    public var serviceDescription: String = ""
    public var location: String = ""
    public var deliveredFrom: Date = Date()
    public var deliveredTo: Date = Date()
    public var quantityHours: Double = 0.0
    public var deliveredBy: String = ""
    public var attestedBy: String = ""
    public var attestedAt: Date = Date()
    public var signatureMethod: String?
    public var signedBy: String?
    public var signedAt: Date?
    public var cancellationReasonCode: String?
    public var notes: String?

    @Relationship(deleteRule: .nullify, inverse: \ClientEntity.supportLogs) public var client: ClientEntity?
    @Relationship(deleteRule: .nullify, inverse: \SessionEntity.supportLogs) public var session: SessionEntity?

    public init(id: UUID) {
        self.id = id
    }
}
