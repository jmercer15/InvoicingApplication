import SwiftUI
import SwiftData
import Core
import SharedUI
import Data

public struct RelationshipsContentColumn: View {
    @ObservedObject private var viewModel: RelationshipsContainerViewModel

    @State private var searchText: String = ""
    @State private var selectedFilter: EntityFilter = .all
    @State private var selectedStatus: StatusFilter = .all
    @State private var isMultiSelectMode: Bool = false
    @State private var treeItems: [TreeItem] = []
    
    // Use domain models from ViewModel instead of @Query
    private var clients: [Client] { viewModel.clients }
    private var payees: [Payee] { viewModel.payees }
    private var planManagers: [PlanManager] { viewModel.planManagers }

    public init(viewModel: RelationshipsContainerViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        FoldPaperContainer(items: $treeItems, onItemTap: handleItemTap)
            .background(Color.clear)
            .searchable(text: $searchText)
            .toolbar(content: toolbarContent)
            .onAppear(perform: updateTreeItems)
            .onChange(of: searchText) { _, _ in updateTreeItems() }
            .onChange(of: selectedFilter) { _, _ in updateTreeItems() }
            .onChange(of: selectedStatus) { _, _ in updateTreeItems() }
            .onChange(of: viewModel.clients) { _, _ in updateTreeItems() }
            .onChange(of: viewModel.payees) { _, _ in updateTreeItems() }
            .onChange(of: viewModel.planManagers) { _, _ in updateTreeItems() }
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button(action: viewModel.createNewClient) {
                Label("New Client", systemImage: "person.crop.circle.badge.plus")
            }
            .help("Create a new client")
            .appInteractiveCursor()

            Button(action: viewModel.createNewPayee) {
                Label("New Payee", systemImage: "person.badge.plus")
            }
            .help("Create a new payee")
            .appInteractiveCursor()

            Button(action: viewModel.createNewPlanManager) {
                Label("New Plan Manager", systemImage: "briefcase.fill")
            }
            .help("Create a new plan manager")
            .appInteractiveCursor()
        }

        ToolbarItemGroup(placement: .automatic) {
            Menu {
                ForEach(Array(EntityFilter.allCases), id: \.self) { filter in
                    Button(filter.displayName) { selectedFilter = filter }
                }
            } label: {
                Label("Entity Type", systemImage: "person.2")
            }
            .help("Filter by entity type")
            .appInteractiveCursor()

            Menu {
                ForEach(Array(StatusFilter.allCases), id: \.self) { status in
                    Button(status.displayName) { selectedStatus = status }
                }
            } label: {
                Label("Status", systemImage: "checkmark.circle")
            }
            .help("Filter by status")
            .appInteractiveCursor()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isMultiSelectMode.toggle()
                }
            } label: {
                Label(isMultiSelectMode ? "Exit Multi-Select" : "Multi-Select",
                      systemImage: isMultiSelectMode ? "checkmark.circle.fill" : "checkmark.circle")
            }
            .help(isMultiSelectMode ? "Exit multi-select mode" : "Select multiple entities")
            .appInteractiveCursor()
        }
    }


    private func handleItemTap(_ item: TreeItem) {
        guard let entityIdString = item.entityId,
              let entityId = UUID(uuidString: entityIdString),
              let entityType = item.entityType else { return }

        switch entityType {
        case "client":
            viewModel.detailState = .client(entityId)
        case "payee":
            viewModel.detailState = .payee(entityId)
        case "planManager":
            viewModel.detailState = .planManager(entityId)
        default:
            break
        }
    }

    private func updateTreeItems() {
        var items: [TreeItem] = []

        if selectedFilter == .all || selectedFilter == .clients {
            let filtered = clients.filter { client in
                let matchesSearch = searchText.isEmpty || client.fullName.localizedCaseInsensitiveContains(searchText)
                let matchesStatus = selectedStatus == .all || client.status == selectedStatus.rawValue
                return matchesSearch && matchesStatus
            }

            if !filtered.isEmpty {
                let children = filtered.map { client in
                    TreeItem(
                        id: "client_\(client.id)",
                        title: client.fullName,
                        subtitle: client.status,
                        children: nil,
                        entityId: client.id.uuidString,
                        entityType: "client"
                    )
                }

                items.append(TreeItem(
                    id: "section_clients",
                    title: "Clients",
                    subtitle: "\(filtered.count) \(filtered.count == 1 ? "item" : "items")",
                    children: children
                ))
            }
        }

        if selectedFilter == .all || selectedFilter == .payees {
            let filtered = payees.filter { payee in
                let matchesSearch = searchText.isEmpty || payee.fullName.localizedCaseInsensitiveContains(searchText)
                let matchesStatus = selectedStatus == .all || (payee.status ?? "") == selectedStatus.rawValue
                return matchesSearch && matchesStatus
            }

            if !filtered.isEmpty {
                let children = filtered.map { payee in
                    TreeItem(
                        id: "payee_\(payee.id)",
                        title: payee.fullName,
                        subtitle: payee.status ?? "Unknown",
                        children: nil,
                        entityId: payee.id.uuidString,
                        entityType: "payee"
                    )
                }

                items.append(TreeItem(
                    id: "section_payees",
                    title: "Payees",
                    subtitle: "\(filtered.count) \(filtered.count == 1 ? "item" : "items")",
                    children: children
                ))
            }
        }

        if selectedFilter == .all || selectedFilter == .planManagers {
            let filtered = planManagers.filter { manager in
                searchText.isEmpty || manager.name.localizedCaseInsensitiveContains(searchText)
            }

            if !filtered.isEmpty {
                let children = filtered.map { manager in
                    TreeItem(
                        id: "planmanager_\(manager.id)",
                        title: manager.name,
                        subtitle: "Plan Manager",
                        children: nil,
                        entityId: manager.id.uuidString,
                        entityType: "planManager"
                    )
                }

                items.append(TreeItem(
                    id: "section_planmanagers",
                    title: "Plan Managers",
                    subtitle: "\(filtered.count) \(filtered.count == 1 ? "item" : "items")",
                    children: children
                ))
            }
        }

        treeItems = items
    }
}

public struct RelationshipsDetailColumn: View {
    @ObservedObject private var viewModel: RelationshipsContainerViewModel
    @Environment(\.modelContext) private var viewContext
    
    // Use domain models from ViewModel instead of @Query
    private var clients: [Client] { viewModel.clients }
    private var payees: [Payee] { viewModel.payees }
    private var planManagers: [PlanManager] { viewModel.planManagers }

    @State private var showingDeleteAlert: Bool = false
    @State private var deleteAlertTitle: String = ""
    @State private var deleteAlertMessage: String = ""
    @State private var deleteAction: (() -> Void)?

    public init(viewModel: RelationshipsContainerViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        Group {
            switch viewModel.detailState {
            case .client(let objectID):
                if let client = clients.first(where: { $0.id == objectID }) {
                    // Note: ClientDetailView requires ClientEntity for @Bindable SwiftData integration.
                    // This is a localized workaround: fetch entity to satisfy @Bindable requirement,
                    // but the ViewModel immediately converts to domain model. Future refactoring could
                    // remove @Bindable dependency and accept domain models directly.
                    if let clientEntity = try? viewContext.fetch(FetchDescriptor<ClientEntity>(
                        predicate: #Predicate { $0.id == objectID }
                    )).first {
                        ClientDetailView(client: clientEntity, context: viewContext)
                            .id("client_\(objectID)")
                    } else {
                        emptyState
                    }
                } else {
                    emptyState
                }
            case .payee(let objectID):
                if let payee = payees.first(where: { $0.id == objectID }) {
                    // Use domain model directly - PayeeDetailView accepts Payee domain model
                    PayeeDetailView(payee: payee, context: viewContext)
                        .id("payee_\(objectID)")
                } else {
                    emptyState
                }
            case .planManager(let objectID):
                if let manager = planManagers.first(where: { $0.id == objectID }) {
                    // Use domain model directly - PlanManagerDetailView accepts PlanManager domain model
                    PlanManagerDetailView(planManager: manager, context: viewContext)
                        .id("planManager_\(objectID)")
                } else {
                    emptyState
                }
            case .newClient:
                ClientDetailView(context: viewContext) {
                    viewModel.detailState = .none
                }
                .id("new_client")
            case .newPayee:
                PayeeDetailView(context: viewContext) {
                    viewModel.detailState = .none
                }
                .id("new_payee")
            case .newPlanManager:
                PlanManagerDetailView(context: viewContext) {
                    viewModel.detailState = .none
                }
                .id("new_plan_manager")
            case .selectEntityType:
                EntityTypeSelectionView(viewModel: viewModel)
                    .id("select_entity_type")
            case .none:
                emptyState
            }
        }
        .fluidDetailTransition()
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.detailState)
        .frame(minWidth: 400)
        .toolbar(content: deletionToolbar)
        .alert(deleteAlertTitle, isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteAction?() }
        } message: {
            Text(deleteAlertMessage)
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "person.2.fill",
            title: "No Relationship Selected",
            message: "Select a client, payee, or plan manager from the list."
        )
        .background(.ultraThinMaterial)
    }

    @ToolbarContentBuilder
    private func deletionToolbar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            deletionButton
        }
    }

    @ViewBuilder
    private var deletionButton: some View {
        if !viewModel.isCreatingNewEntity {
            switch viewModel.detailState {
            case .client(let objectID) where clients.contains(where: { $0.id == objectID }):
                Button("Delete Client", systemImage: "trash", role: .destructive) {
                    confirmDeleteClient(with: objectID)
                }
                .tint(Color.red.opacity(0.7))
                .appInteractiveCursor()

            case .payee(let objectID) where payees.contains(where: { $0.id == objectID }):
                Button("Delete Payee", systemImage: "trash", role: .destructive) {
                    confirmDeletePayee(with: objectID)
                }
                .tint(Color.red.opacity(0.7))
                .appInteractiveCursor()

            case .planManager(let objectID) where planManagers.contains(where: { $0.id == objectID }):
                Button("Delete Plan Manager", systemImage: "trash", role: .destructive) {
                    confirmDeletePlanManager(with: objectID)
                }
                .tint(Color.red.opacity(0.7))
                .appInteractiveCursor()

            default:
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }

    private func confirmDeleteClient(with id: UUID) {
        deleteAlertTitle = "Delete Client"
        deleteAlertMessage = "Are you sure you want to delete this client? This action cannot be undone."
        deleteAction = {
            Task {
                do {
                    try await viewModel.clientsRepository.delete(id: id)
                    await MainActor.run {
                        viewModel.detailState = .none
                    }
                } catch {
                    print("❌ Error deleting client: \(error)")
                }
            }
        }
        showingDeleteAlert = true
    }

    private func confirmDeletePayee(with id: UUID) {
        deleteAlertTitle = "Delete Payee"
        deleteAlertMessage = "Are you sure you want to delete this payee? This action cannot be undone."
        deleteAction = {
            Task {
                do {
                    try await viewModel.payeesRepository.delete(id: id)
                    await MainActor.run {
                        viewModel.detailState = .none
                    }
                } catch {
                    print("❌ Error deleting payee: \(error)")
                }
            }
        }
        showingDeleteAlert = true
    }

    private func confirmDeletePlanManager(with id: UUID) {
        deleteAlertTitle = "Delete Plan Manager"
        deleteAlertMessage = "Are you sure you want to delete this plan manager? This action cannot be undone."
        deleteAction = {
            Task {
                do {
                    try await viewModel.planManagersRepository.delete(id: id)
                    await MainActor.run {
                        viewModel.detailState = .none
                    }
                } catch {
                    print("❌ Error deleting plan manager: \(error)")
                }
            }
        }
        showingDeleteAlert = true
    }
}
