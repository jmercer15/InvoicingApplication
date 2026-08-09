import PersistenceModels
import Foundation
import SharedUI
import SwiftData

/// Post-``SceneStorage`` validation for workspace navigation restores (stale UUIDs after deletes).
@MainActor
enum WorkspaceNavigationRestoration {
    static func sanitizedPath(_ path: [WorkspaceRoute], modelContext: ModelContext) -> [WorkspaceRoute] {
        var validated: [WorkspaceRoute] = []
        for route in path {
            guard routeExists(route, in: modelContext) else { break }
            validated.append(route)
        }
        return validated
    }

    static func sanitizedSelection(_ selection: AppSelection?, modelContext: ModelContext) -> AppSelection? {
        guard let selection, let route = WorkspaceRoute(selection) else { return selection }
        return routeExists(route, in: modelContext) ? selection : nil
    }

    private static func routeExists(_ route: WorkspaceRoute, in modelContext: ModelContext) -> Bool {
        switch route {
        case .invoice(let id):
            return invoiceExists(id: id, in: modelContext)
        case .client(let id):
            return clientExists(id: id, in: modelContext)
        case .payee(let id):
            return payeeExists(id: id, in: modelContext)
        case .planManager(let id):
            return planManagerExists(id: id, in: modelContext)
        case .clientService(let id):
            return clientServiceExists(id: id, in: modelContext)
        case .ndisItem(let id):
            return ndisItemExists(id: id, in: modelContext)
        case .session(let id):
            return sessionExists(id: id, in: modelContext)
        }
    }

    private static func invoiceExists(id: UUID, in modelContext: ModelContext) -> Bool {
        entityExists(id: id, in: modelContext, predicate: #Predicate<Invoice> { $0.id == id })
    }

    private static func clientExists(id: UUID, in modelContext: ModelContext) -> Bool {
        entityExists(id: id, in: modelContext, predicate: #Predicate<Client> { $0.id == id })
    }

    private static func payeeExists(id: UUID, in modelContext: ModelContext) -> Bool {
        entityExists(id: id, in: modelContext, predicate: #Predicate<Payee> { $0.id == id })
    }

    private static func planManagerExists(id: UUID, in modelContext: ModelContext) -> Bool {
        entityExists(id: id, in: modelContext, predicate: #Predicate<PlanManager> { $0.id == id })
    }

    private static func clientServiceExists(id: UUID, in modelContext: ModelContext) -> Bool {
        entityExists(id: id, in: modelContext, predicate: #Predicate<ClientService> { $0.id == id })
    }

    private static func ndisItemExists(id: UUID, in modelContext: ModelContext) -> Bool {
        entityExists(id: id, in: modelContext, predicate: #Predicate<NDISItem> { $0.id == id })
    }

    private static func sessionExists(id: UUID, in modelContext: ModelContext) -> Bool {
        entityExists(id: id, in: modelContext, predicate: #Predicate<Session> { $0.id == id })
    }

    private static func entityExists<T: PersistentModel>(
        id: UUID,
        in modelContext: ModelContext,
        predicate: Predicate<T>
    ) -> Bool {
        var descriptor = FetchDescriptor<T>(predicate: predicate)
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor).first) != nil
    }
}
