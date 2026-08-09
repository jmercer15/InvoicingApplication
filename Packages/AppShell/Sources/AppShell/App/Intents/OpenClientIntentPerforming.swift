import Foundation

enum OpenClientIntentPerforming {
    @MainActor
    static func perform(
        target: ClientEntity,
        modelAccess: AppIntentModelAccess,
        delivery: WorkspaceIntentDeliveryCenter
    ) async throws {
        guard try await modelAccess.clientExists(id: target.id) else {
            throw AppIntentModelAccessError.clientNotFound(target.id)
        }
        delivery.enqueue(.openClient(target.id))
    }
}
