import Foundation

/// Represents a change to a session's state (status, grouping) during drag and drop.
public struct BillingHubSessionStatePatch: Sendable {
    public let id: UUID
    public let status: String
    public let groupID: UUID?
    public let groupedPosition: Int32

    public init(id: UUID, status: String, groupID: UUID?, groupedPosition: Int32) {
        self.id = id
        self.status = status
        self.groupID = groupID
        self.groupedPosition = groupedPosition
    }
}

/// Protocol for persisting drag and drop changes in the Billing Hub.
public protocol BillingHubDragDropPersistenceService: Sendable {
    func applySessionStatePatches(_ patches: [BillingHubSessionStatePatch], notifyRefresh: Bool) async throws
}
