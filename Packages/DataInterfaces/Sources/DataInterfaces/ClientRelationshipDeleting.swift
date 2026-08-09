import Foundation

/// Deletes relationship entities with explicit cascade policy for linked sessions.
///
/// Feature view models call this protocol instead of constructing Data-layer persistence helpers.
/// All methods use domain UUIDs — no live `@Model` instances cross this boundary.
@MainActor
public protocol ClientRelationshipDeleting: AnyObject {
    /// Deletes a client and optionally cascades to linked sessions.
    func deleteClient(id: UUID, deleteSessions: Bool) async throws

    /// Deletes a payee record.
    func deletePayee(id: UUID) async throws

    /// Deletes a plan-manager record.
    func deletePlanManager(id: UUID) async throws
}
