import Foundation

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

    public func prefetchContexts(for sessions: [Session]) -> [SessionAutomationContext] {
        sessions.map { session in
            let clientSnapshot = session.client?.snapshot()
                ?? session.clientId.flatMap { try? fetchClient(by: $0) }
            let serviceSnapshot = session.clientService?.snapshot()
                ?? session.clientServiceId.flatMap { try? fetchClientService(by: $0) }
            let ndisItemSnapshot = session.clientService?.ndisItem?.snapshot()
                ?? serviceSnapshot?.ndisItemId.flatMap { try? fetchNDISItem(by: $0) }
            let addressSnapshot = session.address?.snapshot()

            return SessionAutomationContext(
                session: session.snapshot(),
                client: clientSnapshot,
                service: serviceSnapshot,
                ndisItem: ndisItemSnapshot,
                address: addressSnapshot
            )
        }
    }
}

