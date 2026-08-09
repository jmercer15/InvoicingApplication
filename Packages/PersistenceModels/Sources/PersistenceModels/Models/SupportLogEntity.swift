import Foundation
import Core
import SwiftData

@Model public class SupportLog {
    #Index<SupportLog>([\.deliveredFrom], [\.deliveredTo], [\.supportItemNumber], [\.participantNdisNumber], [\.sessionId])

    public var id: UUID = UUID()
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
    /// Predicate-friendly mirror of `session?.id` for bulk claim fetches.
    public var sessionId: UUID?

    @Relationship(deleteRule: .nullify, inverse: \Client.supportLogs) public var client: Client?
    @Relationship(deleteRule: .nullify, inverse: \Session.supportLogs) public var session: Session?

    public init(id: UUID = UUID()) {
        self.id = id
    }
    
    /// Returns a thread-safe snapshot of the SupportLog.
    public func snapshot() -> SupportLogSnapshot {
        SupportLogSnapshot(self)
    }
}
