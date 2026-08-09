import SwiftUI
import SwiftData
import PersistenceModels
import DataInterfaces
import SharedUI
import Observation

@Observable
@MainActor
public final class RelationshipsContainerViewModel {
    // MARK: - Dependencies
    private let relationshipDeleter: any ClientRelationshipDeleting
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
        relationshipDeleter: any ClientRelationshipDeleting,
        requestRelationshipDelete: @escaping (UUID) -> Void = { _ in },
        storeChangeMonitor: (any StoreChangeMonitoring)? = nil
    ) {
        self.relationshipDeleter = relationshipDeleter
        self.requestRelationshipDelete = requestRelationshipDelete
        syncSelectionFromParent()

        StoreChangeMonitoringSubscription.subscribe(monitor: storeChangeMonitor) { [weak self] revision in
            self?.dataRevision = revision
        }
    }

    /// Builds the relationships navigation tree off the main actor.
    func buildProjection(
        searchText: String,
        selectedFilter: EntityFilter,
        selectedStatus: StatusFilter,
        modelContainer: ModelContainer
    ) async -> RelationshipsProjection? {
        let actor = RelationshipsProjectionActor(modelContainer: modelContainer)
        return try? await actor.build(
            searchText: searchText,
            selectedFilter: selectedFilter,
            selectedStatus: selectedStatus
        )
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
    /// When the client still has sessions, throws unless `deleteSessions` is true (sessions deleted first).
    public func deleteClient(_ entity: Client, deleteSessions: Bool = false) async throws {
        let id = entity.id
        let linkedSessions = entity.sessions ?? []
        if !linkedSessions.isEmpty && !deleteSessions {
            throw ClientDeletionError.hasLinkedSessions(count: linkedSessions.count)
        }
        try await relationshipDeleter.deleteClient(id: id, deleteSessions: deleteSessions)
        deleteEntity(with: id)
    }

    public func deletePayee(_ entity: Payee) async throws {
        let id = entity.id
        try await relationshipDeleter.deletePayee(id: id)
        deleteEntity(with: id)
    }

    public func deletePlanManager(_ entity: PlanManager) async throws {
        let id = entity.id
        try await relationshipDeleter.deletePlanManager(id: id)
        deleteEntity(with: id)
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

// MARK: - Enums & Extensions
extension RelationshipsContainerViewModel {
    enum RelationType: String, CaseIterable, Identifiable {
        case clients = "Clients"
        case payees = "Payees"
        case planManagers = "Plan Managers"
        var id: String { self.rawValue }
    }

}

public enum DetailState: Hashable {
    case none
    case client(UUID)
    case payee(UUID)
    case planManager(UUID)
    case newClient
    case newPayee
    case newPlanManager
}

public enum ClientDeletionError: LocalizedError, Equatable, Sendable {
    case hasLinkedSessions(count: Int)

    public var errorDescription: String? {
        switch self {
        case let .hasLinkedSessions(count):
            let noun = count == 1 ? "session" : "sessions"
            return "This client has \(count) linked \(noun). Delete those sessions first, or delete the client and all sessions together."
        }
    }
}
