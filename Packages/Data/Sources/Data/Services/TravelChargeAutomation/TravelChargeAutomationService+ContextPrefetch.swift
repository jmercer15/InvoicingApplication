import Core
import Foundation
import PersistenceModels

extension TravelChargeAutomationService {
    /// Fetches all related data required for travel charge processing to allow synchronous main logic execution.
    public func prefetchContexts(for sessions: [SessionSnapshot]) async throws -> [SessionAutomationContext] {
        var contexts: [SessionAutomationContext] = []
        for session in sessions {
            var clientSnapshot: ClientSnapshot?
            if let clientId = session.clientId {
                // Fallback for missing relationship but present ID
                clientSnapshot = try fetchClient(by: clientId)
            }

            var serviceSnapshot: ClientServiceSnapshot?
            if let serviceId = session.clientServiceId {
                serviceSnapshot = try fetchClientService(by: serviceId)
            }

            var ndisItemSnapshot: NDISItemSnapshot?
            if let ndisItemId = serviceSnapshot?.ndisItemId {
                ndisItemSnapshot = try fetchNDISItem(by: ndisItemId)
            }

            let addressSnapshot: AddressSnapshot? = nil // Not embedded in `SessionSnapshot` today.

            contexts.append(SessionAutomationContext(
                session: session,
                client: clientSnapshot,
                service: serviceSnapshot,
                ndisItem: ndisItemSnapshot,
                address: addressSnapshot
            ))
        }
        return contexts
    }
}
