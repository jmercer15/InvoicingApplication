import Foundation
import SwiftData

@Model public class BillableDraft {
    #Index<BillableDraft>([\.draftStatus], [\.computedAt], [\.clientId])

    public var id: UUID = UUID()
    public var sessionId: UUID = UUID()
    public var clientId: UUID = UUID()
    public var serviceId: UUID = UUID()
    public var computedAt: Date = Date()
    public var billingContextSnapshot: Data = Data()
    public var draftStatus: String = ""
    public var createdAt: Date = Date()
    public var updatedAt: Date?

    @Relationship(deleteRule: .nullify, inverse: \Session.billableDrafts) public var session: Session?
    @Relationship(deleteRule: .nullify, inverse: \Client.billableDrafts) public var client: Client?
    @Relationship(deleteRule: .nullify, inverse: \ClientService.billableDrafts) public var service: ClientService?
    @Relationship(deleteRule: .cascade, inverse: \ClaimableLine.draft) public var items: [ClaimableLine]?
    @Relationship(deleteRule: .cascade, inverse: \DraftIssue.draft) public var issues: [DraftIssue]?

    public init(
        id: UUID,
        sessionId: UUID,
        clientId: UUID,
        serviceId: UUID,
        computedAt: Date,
        billingContextSnapshot: Data,
        draftStatus: String,
        createdAt: Date,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.clientId = clientId
        self.serviceId = serviceId
        self.computedAt = computedAt
        self.billingContextSnapshot = billingContextSnapshot
        self.draftStatus = draftStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Returns a thread-safe snapshot of the BillableDraft.
    public func snapshot() -> BillableDraftSnapshot {
        BillableDraftSnapshot(self)
    }
}
