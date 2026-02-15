import SwiftUI
import Combine
import SwiftData
import Data
import Core
import SharedUI

public enum DetailState: Hashable {
    case none
    case client(UUID)
    case payee(UUID)
    case planManager(UUID)
    case newClient
    case newPayee
    case newPlanManager
    case selectEntityType
}

@MainActor
public final class RelationshipsContainerViewModel: ObservableObject {
    // MARK: - Dependencies
    public let unitOfWork: UnitOfWorkService
    private let navigationManager: AppNavigationManager
    private var requestRelationshipDelete: (UUID) -> Void
    private let pageSize = 50
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published State
    @Published public var detailState: DetailState = .none
    @Published var isLoading: Bool = false
    
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

    // Data lists for the view (Domain Models)
    @Published private(set) var clients: [Client] = []
    @Published private(set) var payees: [Payee] = []
    @Published private(set) var planManagers: [PlanManager] = []
    
    // Pagination
    @Published private(set) var hasMoreToLoad = false
    
    // All fetched data (Domain Models)
    private var allFilteredClients: [Client] = []
    private var allFilteredPayees: [Payee] = []
    private var allFilteredPlanManagers: [PlanManager] = []

    // MARK: - Initializer
    // MARK: - Initializer
    public init(
        unitOfWork: UnitOfWorkService,
        navigationManager: AppNavigationManager,
        requestRelationshipDelete: @escaping (UUID) -> Void = { _ in }
    ) {
        self.unitOfWork = unitOfWork
        self.navigationManager = navigationManager
        self.requestRelationshipDelete = requestRelationshipDelete
        
        setupBindings()
        Task {
            await fetchAllDataAndFilter()
        }
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
    public func refreshData() {
        Task {
            await fetchAllDataAndFilter()
        }
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
    
    // MARK: - Deletion Actions
    func deleteClient(id: UUID) async throws {
        try await unitOfWork.clients.delete(id: id)
        await MainActor.run {
            allFilteredClients.removeAll(where: { $0.id == id })
            applyCurrentFilteredResults()
        }
    }
    
    func deletePayee(id: UUID) async throws {
        try await unitOfWork.payees.delete(id: id)
        await MainActor.run {
            allFilteredPayees.removeAll(where: { $0.id == id })
            applyCurrentFilteredResults()
        }
    }
    
    func deletePlanManager(id: UUID) async throws {
        try await unitOfWork.planManagers.delete(id: id)
        await MainActor.run {
            allFilteredPlanManagers.removeAll(where: { $0.id == id })
            applyCurrentFilteredResults()
        }
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
                Task { @MainActor in
                    await self.fetchAllDataAndFilter()
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
                Task { @MainActor in
                    self?.applyCurrentFilteredResults()
                }
            }
            .store(in: &cancellables)

        // MARK: - Notification handling for data changes
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                // Re-fetch data when the store changes (e.g., after imports)
                guard let self = self else { return }
                Task { @MainActor in
                    await self.fetchAllDataAndFilter()
                }
            }
            .store(in: &cancellables)
    }

    private func fetchAllDataAndFilter() async {
        await MainActor.run { self.isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }
        
        // Capture filter/search values
        let searchText = relationshipSearchText
        let clientFilterRawValue = clientFilter.rawValue
        let payeeFilterRawValue = payeeFilter.rawValue
        let clientSort = clientSortOrder
        let payeeSort = payeeSortOrder
        let planManagerSort = planManagerSortOrder

        do {
            // Capture repositories on MainActor to avoid isolation errors in child tasks
            let clientsRepo = unitOfWork.clients
            let payeesRepo = unitOfWork.payees
            let planManagersRepo = unitOfWork.planManagers

            // Fetch all data using repositories
            async let allClientsTask = clientsRepo.fetchAll()
            async let allPayeesTask = payeesRepo.fetchAll()
            async let allPlanManagersTask = planManagersRepo.fetchAll()
            
            let allClients = try await allClientsTask
            let allPayees = try await allPayeesTask
            let allPlanManagers = try await allPlanManagersTask

            let processed = await Task.detached {
                // Apply sorting
                let sortedClients = clientSort.sortClients(allClients)
                let sortedPayees = payeeSort.sortPayees(allPayees)
                let sortedPlanManagers = planManagerSort.sortPlanManagers(allPlanManagers)

                // In-memory filtering for clients
                let filteredClients = sortedClients.filter { client in
                    let matchesSearch = searchText.isEmpty ||
                        client.fullName.localizedStandardContains(searchText) ||
                        (client.email ?? "").localizedStandardContains(searchText) ||
                        client.ndisNumber.localizedStandardContains(searchText)
                    
                    let matchesFilter = clientFilterRawValue == "All" || client.status == clientFilterRawValue
                    
                    return matchesSearch && matchesFilter
                }

                // In-memory filtering for payees
                let filteredPayees = sortedPayees.filter { payee in
                    (searchText.isEmpty ||
                        payee.fullName.localizedStandardContains(searchText) ||
                        (payee.email ?? "").localizedStandardContains(searchText)
                    ) &&
                    (payeeFilterRawValue == "All" || payee.status == payeeFilterRawValue)
                }

                // In-memory filtering for plan managers
                let filteredPlanManagers = sortedPlanManagers.filter { planManager in
                    (searchText.isEmpty ||
                        planManager.name.localizedStandardContains(searchText) ||
                        (planManager.email ?? "").localizedStandardContains(searchText) ||
                        planManager.abn.localizedStandardContains(searchText)
                    )
                }

                return (filteredClients, filteredPayees, filteredPlanManagers)
            }.value

            await MainActor.run {
                allFilteredClients = processed.0
                allFilteredPayees = processed.1
                allFilteredPlanManagers = processed.2
                applyCurrentFilteredResults()
            }
        } catch {
            print("❌ [RelationshipsContainerViewModel] Failed to fetch data: \(error)")
            await MainActor.run {
                allFilteredClients = []
                allFilteredPayees = []
                allFilteredPlanManagers = []
                applyCurrentFilteredResults()
            }
        }
    }

    @MainActor
    private func applyCurrentFilteredResults() {
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
        
        func sortClients(_ clients: [Client]) -> [Client] {
            switch self {
            case .nameAsc: return clients.sorted { $0.fullName < $1.fullName }
            case .nameDesc: return clients.sorted { $0.fullName > $1.fullName }
            case .dateAddedDesc: return clients.sorted { $0.id.uuidString > $1.id.uuidString }
            case .dateAddedAsc: return clients.sorted { $0.id.uuidString < $1.id.uuidString }
            }
        }
        
        func sortPayees(_ payees: [Payee]) -> [Payee] {
            switch self {
            case .nameAsc: return payees.sorted { $0.fullName < $1.fullName }
            case .nameDesc: return payees.sorted { $0.fullName > $1.fullName }
            case .dateAddedDesc: return payees.sorted { $0.id.uuidString > $1.id.uuidString }
            case .dateAddedAsc: return payees.sorted { $0.id.uuidString < $1.id.uuidString }
            }
        }
        
        func sortPlanManagers(_ planManagers: [PlanManager]) -> [PlanManager] {
            switch self {
            case .nameAsc: return planManagers.sorted { $0.name < $1.name }
            case .nameDesc: return planManagers.sorted { $0.name > $1.name }
            case .dateAddedDesc: return planManagers.sorted { $0.id.uuidString > $1.id.uuidString }
            case .dateAddedAsc: return planManagers.sorted { $0.id.uuidString < $1.id.uuidString }
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
