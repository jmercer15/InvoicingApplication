import SwiftUI
import SwiftData
import Core
import Data
import SharedUI
import Observation

public enum DetailState: Hashable {
    case none
    case client(UUID)
    case payee(UUID)
    case planManager(UUID)
    case newClient
    case newPayee
    case newPlanManager
}
@Observable
@MainActor
public final class RelationshipsContainerViewModel {
    // MARK: - Dependencies
    private let persistenceCommands: RelationshipPersistenceCommands
    private var requestRelationshipDelete: (UUID) -> Void

    // MARK: - Published State
    public var detailState: DetailState = .none {
        didSet { syncSelectionFromParent() }
    }
    var isLoading: Bool = false
    
    var isCreatingNewEntity: Bool {
        switch detailState {
        case .newClient, .newPayee, .newPlanManager:
            return true
        default:
            return false
        }
    }
    public var relationshipSearchText = ""
    public var dataRevision: Int = 0
    var selectedRelationType: RelationType = .clients {
        didSet { detailState = .none }
    }

    // MARK: - Initializer
    public init(
        modelContext: ModelContext,
        requestRelationshipDelete: @escaping (UUID) -> Void = { _ in },
        storeChangeMonitor: SwiftDataStoreChangeMonitor? = nil
    ) {
        self.persistenceCommands = RelationshipPersistenceCommands(modelContext: modelContext)
        self.requestRelationshipDelete = requestRelationshipDelete
        syncSelectionFromParent()

        SwiftDataStoreChangeMonitor.subscribeToStoreChanges(monitor: storeChangeMonitor) { [weak self] revision in
            self?.dataRevision = revision
        }
    }

    // MARK: - Public Intents
    
    func deleteEntity(with objectId: UUID) {
        requestRelationshipDelete(objectId)
        if case .client(let id) = detailState, id == objectId { detailState = .none }
        else if case .payee(let id) = detailState, id == objectId { detailState = .none }
        else if case .planManager(let id) = detailState, id == objectId { detailState = .none }
    }

    public func updateDeleteHandler(_ handler: @escaping (UUID) -> Void) {
        requestRelationshipDelete = handler
    }
    
    func createNewClient() { detailState = .newClient }
    func createNewPayee() { detailState = .newPayee }
    func createNewPlanManager() { detailState = .newPlanManager }
    
    // MARK: - Deletion Actions
    /// Deletes the same `@Query`-materialized model the detail column is showing (no duplicate fetch).
    func deleteClient(_ entity: Client) async throws {
        let id = entity.id
        try persistenceCommands.delete(entity)
        await MainActor.run { deleteEntity(with: id) }
    }

    func deletePayee(_ entity: Payee) async throws {
        let id = entity.id
        try persistenceCommands.delete(entity)
        await MainActor.run { deleteEntity(with: id) }
    }

    func deletePlanManager(_ entity: PlanManager) async throws {
        let id = entity.id
        try persistenceCommands.delete(entity)
        await MainActor.run { deleteEntity(with: id) }
    }

    // MARK: - Private Logic

    private func syncSelectionFromParent() {
        switch detailState {
        case .client: if selectedRelationType != .clients { selectedRelationType = .clients }
        case .payee: if selectedRelationType != .payees { selectedRelationType = .payees }
        case .planManager: if selectedRelationType != .planManagers { selectedRelationType = .planManagers }
        case .newClient: if selectedRelationType != .clients { selectedRelationType = .clients }
        case .newPayee: if selectedRelationType != .payees { selectedRelationType = .payees }
        case .newPlanManager: if selectedRelationType != .planManagers { selectedRelationType = .planManagers }
        case .none: break
        }
    }

    public func clearSelection() {
        detailState = .none
    }
}

@MainActor
private struct RelationshipPersistenceCommands {
    let modelContext: ModelContext

    func delete<T: PersistentModel>(_ entity: T) throws {
        modelContext.delete(entity)
        try modelContext.save()
    }
}

// MARK: - Enums & Extensions
extension RelationshipsContainerViewModel {
    enum RelationType: String, CaseIterable, Identifiable {
        case clients = "Clients"
        case payees = "Payees"
        case planManagers = "Plan Managers"
        var id: String { self.rawValue }
    }

}
