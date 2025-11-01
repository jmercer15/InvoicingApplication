import SwiftUI
import Combine
import SwiftData
import Data
import Core
import SharedUI

enum DetailState: Hashable {
    case none
    case client(UUID)
    case payee(UUID)
    case planManager(UUID)
    case newClient
    case newPayee
    case newPlanManager
    case selectEntityType
}

public final class RelationshipsContainerViewModel: ObservableObject, @unchecked Sendable {
    // MARK: - Dependencies
    private var modelContext: ModelContext
    private let navigationManager: AppNavigationManager
    private var requestRelationshipDelete: (UUID) -> Void
    private let pageSize = 50
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published State
    @Published var detailState: DetailState = .none
    
    var isCreatingNewEntity: Bool {
        switch detailState {
        case .newClient, .newPayee, .newPlanManager:
            return true
        default:
            return false
        }
    }
    @Published var relationshipSearchText = ""
    @Published var selectedRelationType: RelationType = .clients
    
    // Sorting & Filtering
    @Published var clientSortOrder: SortOrder = .nameAsc
    @Published var payeeSortOrder: SortOrder = .nameAsc
    @Published var planManagerSortOrder: SortOrder = .nameAsc
    @Published var clientFilter: ClientFilter = .all
    @Published var payeeFilter: PayeeFilter = .all

    // Data lists for the view
    @Published private(set) var clients: [ClientEntity] = []
    @Published private(set) var payees: [PayeeEntity] = []
    @Published private(set) var planManagers: [PlanManagerEntity] = []
    
    // Pagination
    @Published private(set) var hasMoreToLoad = false


    
    // All fetched data
    private var allFilteredClients: [ClientEntity] = []
    private var allFilteredPayees: [PayeeEntity] = []
    private var allFilteredPlanManagers: [PlanManagerEntity] = []

    // MARK: - Initializer
    public init(
        context: ModelContext,
        navigationManager: AppNavigationManager,
        requestRelationshipDelete: @escaping (UUID) -> Void = { _ in }
    ) {
        self.modelContext = context
        self.navigationManager = navigationManager
        self.requestRelationshipDelete = requestRelationshipDelete
        
        setupBindings()
        fetchAllDataAndFilter()
        syncSelectionFromParent()
        // Handle initial navigation context directly to avoid data races
        // await handleInitialNavigationContext()
    }

    // MARK: - Public Intents
    
    func deleteEntity(with objectId: UUID) {
        requestRelationshipDelete(objectId)
        if case .client(let id) = detailState, id == objectId { detailState = .none }
        else if case .payee(let id) = detailState, id == objectId { detailState = .none }
        else if case .planManager(let id) = detailState, id == objectId { detailState = .none }
    }

    @MainActor
    public func updateContextIfNeeded(_ newContext: ModelContext) {
        guard modelContext !== newContext else { return }
        modelContext = newContext
        fetchAllDataAndFilter()
    }

    public func updateDeleteHandler(_ handler: @escaping (UUID) -> Void) {
        requestRelationshipDelete = handler
    }
    
    func createNewClient() { detailState = .newClient }
    func createNewPayee() { detailState = .newPayee }
    func createNewPlanManager() { detailState = .newPlanManager }
    func showEntityTypeSelection() { detailState = .selectEntityType }
    
    func saveNewEntity() {
        // This will be called from the toolbar
        // The detail views will handle their own save logic
        detailState = .none
    }
    
    func cancelNewEntity() {
        detailState = .none
    }
    
    func loadMore() {
        switch selectedRelationType {
        case .clients:
            let currentCount = clients.count
            let remainingCount = allFilteredClients.count - currentCount
            if remainingCount > 0 {
                let nextBatch = allFilteredClients[currentCount..<min(currentCount + pageSize, allFilteredClients.count)]
                clients.append(contentsOf: nextBatch)
            }
        case .payees:
            let currentCount = payees.count
            let remainingCount = allFilteredPayees.count - currentCount
            if remainingCount > 0 {
                let nextBatch = allFilteredPayees[currentCount..<min(currentCount + pageSize, allFilteredPayees.count)]
                payees.append(contentsOf: nextBatch)
            }
        case .planManagers:
            let currentCount = planManagers.count
            let remainingCount = allFilteredPlanManagers.count - currentCount
            if remainingCount > 0 {
                let nextBatch = allFilteredPlanManagers[currentCount..<min(currentCount + pageSize, allFilteredPlanManagers.count)]
                planManagers.append(contentsOf: nextBatch)
            }
        }
        updateHasMoreToLoad()
    }

    // MARK: - Private Logic
    
    private func setupBindings() {
        // Any change that requires re-filtering data
        let filterTrigger = Publishers.MergeMany(
            $relationshipSearchText.debounce(for: .milliseconds(300), scheduler: RunLoop.main).eraseToAnyPublisher(),
            $clientFilter.map { _ in "" }.eraseToAnyPublisher(),
            $payeeFilter.map { _ in "" }.eraseToAnyPublisher(),
            $clientSortOrder.map { _ in "" }.eraseToAnyPublisher(),
            $payeeSortOrder.map { _ in "" }.eraseToAnyPublisher(),
            $planManagerSortOrder.map { _ in "" }.eraseToAnyPublisher()
        ).eraseToAnyPublisher()

        filterTrigger
            .sink { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.fetchAllDataAndFilter()
                }
            }
            .store(in: &cancellables)

        $detailState
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.syncSelectionFromParent()
            }
            .store(in: &cancellables)
            
        $selectedRelationType
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.detailState = .none
                self?.fetchAllDataAndFilter()
            }
            .store(in: &cancellables)

        // MARK: - Notification handling for data changes
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                // Re-fetch data when the store changes (e.g., after imports)
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.fetchAllDataAndFilter()
                }
            }
            .store(in: &cancellables)
    }

    private func fetchAllDataAndFilter() {
        // Capture filter/search values
        let searchText = relationshipSearchText
        let clientFilterRawValue = clientFilter.rawValue
        let payeeFilterRawValue = payeeFilter.rawValue

        // Fetch all entities without filtering
        let clientDescriptor = FetchDescriptor<ClientEntity>(sortBy: clientSortOrder.clientSortDescriptors())
        let payeeDescriptor = FetchDescriptor<PayeeEntity>(sortBy: payeeSortOrder.payeeSortDescriptors())
        let planManagerDescriptor = FetchDescriptor<PlanManagerEntity>(sortBy: planManagerSortOrder.planManagerSortDescriptors())

        do {
            let allClients = try modelContext.fetch(clientDescriptor)
            let allPayees = try modelContext.fetch(payeeDescriptor)
            let allPlanManagers = try modelContext.fetch(planManagerDescriptor)

            // In-memory filtering for clients
            allFilteredClients = allClients.filter { client in
                let matchesSearch = searchText.isEmpty ||
                    client.fullName.localizedStandardContains(searchText) ||
                    (client.email ?? "").localizedStandardContains(searchText) ||
                    client.ndisNumber.localizedStandardContains(searchText)
                
                let matchesFilter = clientFilterRawValue == "All" || client.status.rawValue == clientFilterRawValue
                
                return matchesSearch && matchesFilter
            }

            // In-memory filtering for payees
            allFilteredPayees = allPayees.filter { payee in
                (searchText.isEmpty ||
                    payee.fullName.localizedStandardContains(searchText) ||
                    (payee.email ?? "").localizedStandardContains(searchText)
                ) &&
                (payeeFilterRawValue == "All" || payee.status == payeeFilterRawValue)
            }

            // In-memory filtering for plan managers
            allFilteredPlanManagers = allPlanManagers.filter { planManager in
                (searchText.isEmpty ||
                    (planManager.name ?? "").localizedStandardContains(searchText) ||
                    (planManager.email ?? "").localizedStandardContains(searchText) ||
                    (planManager.abn).localizedStandardContains(searchText)
                )
            }
        } catch {
            print("Failed to fetch data: \(error)")
        }
        
        clients = Array(allFilteredClients.prefix(pageSize))
        payees = Array(allFilteredPayees.prefix(pageSize))
        planManagers = Array(allFilteredPlanManagers.prefix(pageSize))
        updateHasMoreToLoad()
    }
    
    private func updateHasMoreToLoad() {
        hasMoreToLoad = {
            switch selectedRelationType {
            case .clients: return clients.count < allFilteredClients.count
            case .payees: return payees.count < allFilteredPayees.count
            case .planManagers: return planManagers.count < allFilteredPlanManagers.count
            }
        }()
    }

    @MainActor
    private func handleInitialNavigationContext() async {
        guard let navContext = navigationManager.consumeNavigationContext(), let targetEntity = navContext.targetEntity else { return }
        switch navContext.targetEntityType {
        case .client: detailState = .client(targetEntity)
        case .payee: detailState = .payee(targetEntity)
        case .planManager: detailState = .planManager(targetEntity)
        default: break
        }
    }
    

    
    private func syncSelectionFromParent() {
        switch detailState {
        case .client: if selectedRelationType != .clients { selectedRelationType = .clients }
        case .payee: if selectedRelationType != .payees { selectedRelationType = .payees }
        case .planManager: if selectedRelationType != .planManagers { selectedRelationType = .planManagers }
        case .newClient: if selectedRelationType != .clients { selectedRelationType = .clients }
        case .newPayee: if selectedRelationType != .payees { selectedRelationType = .payees }
        case .newPlanManager: if selectedRelationType != .planManagers { selectedRelationType = .planManagers }
        case .selectEntityType: break // No specific relation type for entity selection
        case .none: break
        }
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

    enum SortOrder: String, CaseIterable, Identifiable {
        case nameAsc = "Name (A-Z)"
        case nameDesc = "Name (Z-A)"
        case dateAddedDesc = "Date Added (Newest)"
        case dateAddedAsc = "Date Added (Oldest)"
        var id: String { self.rawValue }
        
        func clientSortDescriptors() -> [SortDescriptor<ClientEntity>] {
            switch self {
            case .nameAsc: return [SortDescriptor(\ClientEntity.fullName)]
            case .nameDesc: return [SortDescriptor(\ClientEntity.fullName, order: .reverse)]
            case .dateAddedDesc: return [SortDescriptor(\ClientEntity.id, order: .reverse)]
            case .dateAddedAsc: return [SortDescriptor(\ClientEntity.id)]
            }
        }
        func payeeSortDescriptors() -> [SortDescriptor<PayeeEntity>] {
            switch self {
            case .nameAsc: return [SortDescriptor(\PayeeEntity.fullName)]
            case .nameDesc: return [SortDescriptor(\PayeeEntity.fullName, order: .reverse)]
            case .dateAddedDesc: return [SortDescriptor(\PayeeEntity.id, order: .reverse)]
            case .dateAddedAsc: return [SortDescriptor(\PayeeEntity.id)]
            }
        }
        func planManagerSortDescriptors() -> [SortDescriptor<PlanManagerEntity>] {
            switch self {
            case .nameAsc: return [SortDescriptor(\PlanManagerEntity.name)]
            case .nameDesc: return [SortDescriptor(\PlanManagerEntity.name, order: .reverse)]
            case .dateAddedDesc: return [SortDescriptor(\PlanManagerEntity.id, order: .reverse)]
            case .dateAddedAsc: return [SortDescriptor(\PlanManagerEntity.id)]
            }
        }
    }

    enum ClientFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case active = "Active"
        case inactive = "Inactive"
        case archived = "Archived"
        var id: String { self.rawValue }
    }

    enum PayeeFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case active = "Active"
        case inactive = "Inactive"
        var id: String { self.rawValue }
    }
}
