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
    @State private var navigationTree: [TreeItem] = []
    @State private var selectionPath: [String] = []
    @State private var breadcrumbHeight: CGFloat = 32
    private let minimumCardWidth: CGFloat = 260
    @State private var availableWidth: CGFloat = 0
    @State private var optimalColumns: Int = 1
    @State private var descendantCountLookup: [String: Int] = [:]
    
    // Use domain models from ViewModel
    private var clients: [Client] { viewModel.clients }
    private var payees: [Payee] { viewModel.payees }
    private var planManagers: [PlanManager] { viewModel.planManagers }
    private var isDetailVisible: Bool { viewModel.detailState != .none }
    private var displayColumns: Int { isDetailVisible ? 1 : optimalColumns }

    public init(viewModel: RelationshipsContainerViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 0) {
            breadcrumbView
                .padding(.bottom, 12)

            if navigationTree.isEmpty {
                EmptyStateView(
                    icon: "person.2.slash",
                    title: "No Relationships Found",
                    message: "Try adjusting your search or filters."
                )
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
                .standardContentPanelListInsets()
            } else {
                GeometryReader { geometry in
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: PanelShellTokens.contentListGridSpacing), count: displayColumns),
                                spacing: PanelShellTokens.contentListGridSpacing
                            ) {
                                ForEach(currentNodes, id: \.id) { node in
                                    card(for: node)
                                        .id(node.id) // Explicit ID for scrolling
                                        .transition(cardTransition)
                                }
                            }
                            .animation(.easeInOut(duration: 0.3), value: optimalColumns)
                            .standardContentPanelListInsets()
                        }
                        .transaction { transaction in
                            if isDetailVisible {
                                transaction.disablesAnimations = true
                            }
                        }
                        .onAppear {
                            updateAvailableWidth(geometry.size.width)
                        }
                        .onChange(of: geometry.size.width) { _, newWidth in
                            updateAvailableWidth(newWidth)
                        }
                        .onChange(of: viewModel.detailState) { _, newState in
                            if newState == .none {
                                updateGridLayout(for: availableWidth)
                            }
                            
                            // Then scroll to selected item if applicable
                            if let scrollToId = nodeIdFrom(detailState: newState),
                               currentNodes.contains(where: { $0.id == scrollToId }) {
                                DispatchQueue.main.async {
                                    withAnimation {
                                        proxy.scrollTo(scrollToId, anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .searchable(text: $searchText)
        .toolbar(content: toolbarContent)

        .navigationTitle("Clients")
        .onAppear(perform: updateTreeItems)
        .onChange(of: searchText) { _, _ in updateTreeItems() }
        .onChange(of: selectedFilter) { _, _ in updateTreeItems() }
        .onChange(of: selectedStatus) { _, _ in updateTreeItems() }
        .onChange(of: viewModel.clients) { _, _ in updateTreeItems() }
        .onChange(of: viewModel.payees) { _, _ in updateTreeItems() }
        .onChange(of: viewModel.planManagers) { _, _ in updateTreeItems() }
        // Note: detailState change handled inside ScrollViewReader
        .animation(.easeInOut(duration: 0.25), value: selectionPath)
    }

    // MARK: - Grid Logic
    
    private func updateAvailableWidth(_ width: CGFloat) {
        let normalized = max(0, width)
        // Avoid thrashing layout recalculation for tiny floating-point changes.
        guard abs(normalized - availableWidth) > 0.5 else { return }
        availableWidth = normalized
        updateGridLayout(for: normalized)
    }
    
    private func updateGridLayout(for newAvailableWidth: CGFloat) {
        // Force single column if detail view is open (selection active)
        if isDetailVisible {
            return
        }

        // Simple adaptive column logic similar to NDISCatalogue
        let spacing: CGFloat = PanelShellTokens.contentListGridSpacing
        let minWidth: CGFloat = max(220, minimumCardWidth)
        
        let available = max(0, newAvailableWidth - (PanelShellTokens.contentListHorizontalInset * 2))
        let columns = max(1, Int((available + spacing) / (minWidth + spacing)))
        
        if columns != optimalColumns {
            optimalColumns = columns
        }
    }
    
    private var currentNodes: [TreeItem] {
        var level = navigationTree
        for id in selectionPath {
            guard let selected = level.first(where: { $0.id == id }),
                  let children = selected.children, !children.isEmpty else {
                return level
            }
            level = children
        }
        return level
    }

    private var cardTransition: AnyTransition {
        if isDetailVisible {
            return .identity
        }
        if displayColumns == 1 {
            return .opacity.combined(with: .move(edge: .top))
        }
        return .opacity.combined(with: .scale(scale: 0.96, anchor: .center))
    }

    // MARK: - Card Views
    
    @ViewBuilder
    private func card(for node: TreeItem) -> some View {
        if let children = node.children, !children.isEmpty {
            RelationshipGroupCard(
                node: node,
                count: descendantCount(for: node),
                isListStyle: displayColumns == 1,
                onSelect: {
                    selectionPath.append(node.id)
                }
            )
        } else {
            RelationshipCard(
                title: node.title,
                subtitle: node.subtitle,
                entityType: node.entityType ?? "unknown",
                status: node.subtitle, // Passing subtitle as status for now, or could map from entity
                isSelected: isSelected(node),
                isListStyle: displayColumns == 1,
                onSelect: {
                    handleItemTap(node)
                }
            )
        }
    }
    
    private func isSelected(_ node: TreeItem) -> Bool {
        guard let entityIdString = node.entityId,
              let uuid = UUID(uuidString: entityIdString) else { return false }
        
        switch viewModel.detailState {
        case .client(let id): return id == uuid
        case .payee(let id): return id == uuid
        case .planManager(let id): return id == uuid
        default: return false
        }
    }
    
    private func descendantCount(for node: TreeItem) -> Int {
        if let cached = descendantCountLookup[node.id] {
            return cached
        }
        if let children = node.children, !children.isEmpty {
            return children.reduce(0) { $0 + descendantCount(for: $1) }
        }
        return node.entityId != nil ? 1 : 0
    }

    // MARK: - Breadcrumbs

    private var breadcrumbTrail: [TreeItem] {
        var trail: [TreeItem] = []
        var level = navigationTree
        for id in selectionPath {
            guard let node = level.first(where: { $0.id == id }) else { break }
            trail.append(node)
            level = node.children ?? []
        }
        return trail
    }
    
    private var breadcrumbView: some View {
        HStack(alignment: .top, spacing: 8) {
            if !selectionPath.isEmpty {
                let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
                shape
                    .fill(Color.accentColor.opacity(0.25))
                    .frame(width: 42, height: breadcrumbHeight)
                    .glassEffect(.regular.interactive(true), in: shape)
                    .overlay(
                        shape.stroke(Color.accentColor.opacity(0.45), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.accentColor)
                    )
                    .shadow(color: Color.accentColor.opacity(0.2), radius: 3, x: 0, y: 1)
                    .onTapGesture { goBack() }
                    .animation(.easeInOut(duration: 0.2), value: selectionPath)
                    .pointerStyle(.link)
            }

            VStack(alignment: .leading, spacing: 8) {
                breadcrumbSegments
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { breadcrumbHeight = geometry.size.height }
                        .onChange(of: geometry.size.height) { _, newHeight in
                            breadcrumbHeight = newHeight
                        }
                }
            )
        }
        .standardContentPanelBreadcrumbInsets()
    }

    private var breadcrumbSegments: some View {
        let trail = breadcrumbTrail
        let nodes: [TreeItem?] = [nil] + trail.map { Optional($0) }

        return ForEach(Array(nodes.enumerated()), id: \.offset) { index, node in
            Button {
                crumbTapped(at: index)
            } label: {
                let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
                HStack(spacing: 12) {
                    Text(node?.title ?? "All Items")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text("\(nodeCount(for: node))")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .padding(.leading, CGFloat(index) * 14)
                .background(shape.fill(breadcrumbBackground(for: node)))
                .glassEffect(.regular.interactive(true), in: shape)
                .overlay(
                    shape.stroke(Color.primary.opacity(0.12), lineWidth: 0.6)
                )
                .contentShape(shape)
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
            .animation(.easeInOut(duration: 0.2), value: selectionPath)
        }
    }

    private func nodeCount(for node: TreeItem?) -> Int {
        if let node { return descendantCount(for: node) }
        return navigationTree.reduce(0) { $0 + descendantCount(for: $1) }
    }

    private func breadcrumbBackground(for node: TreeItem?) -> Color {
        guard let node else { return Color.primary.opacity(0.06) }
        if node.id.hasPrefix("section_clients") { return Color.blue.opacity(0.15) }
        if node.id.hasPrefix("section_payees") { return Color.orange.opacity(0.15) }
        if node.id.hasPrefix("section_planmanagers") { return Color.green.opacity(0.15) }
        return Color.primary.opacity(0.08)
    }
    
    private func goBack() {
        if !selectionPath.isEmpty {
            selectionPath.removeLast()
        }
    }

    private func crumbTapped(at index: Int) {
        if index == 0 {
            selectionPath = []
        } else {
            selectionPath = Array(selectionPath.prefix(index))
        }
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        // MARK: - Primary Action
        ToolbarItem(placement: .automatic) {
            Button(action: viewModel.createNewClient) {
                Label("New Client", systemImage: "person.crop.circle.badge.plus")
            }
            .keyboardShortcut("n")
            .glassEffect(.regular.tint(.blue).interactive(), in: .buttonBorder)
            .help("Create a new client")
            .pointerStyle(.link)
        }

        // MARK: - Secondary Actions
        ToolbarItemGroup(placement: .automatic) {
            Button(action: viewModel.createNewPayee) {
                Label("New Payee", systemImage: "person.badge.plus")
            }
            .help("Create a new payee")
            .pointerStyle(.link)
            
            Button(action: viewModel.createNewPlanManager) {
                Label("New Plan Manager", systemImage: "briefcase.fill")
            }
            .help("Create a new plan manager")
            .pointerStyle(.link)
        }

        // MARK: - Filters
        ToolbarItemGroup(placement: .automatic) {
            Menu {
                ForEach(Array(EntityFilter.allCases), id: \.self) { filter in
                    Button(filter.displayName) { selectedFilter = filter }
                }
            } label: {
                Label {
                    Text(selectedFilter == .all ? "Entity Type" : selectedFilter.displayName)
                } icon: {
                    Image(systemName: selectedFilter == .all ? "person.2" : "person.2.fill")
                }
            }
            .help("Filter by entity type")
            .pointerStyle(.link)
            
            Menu {
                ForEach(Array(StatusFilter.allCases), id: \.self) { status in
                    Button(status.displayName) { selectedStatus = status }
                }
            } label: {
                Label {
                    Text(selectedStatus == .all ? "Status" : selectedStatus.displayName)
                } icon: {
                    Image(systemName: selectedStatus == .all ? "checkmark.circle" : "checkmark.circle.fill")
                }
            }
            .help("Filter by status")
            .pointerStyle(.link)
        }
    }

    // MARK: - Navigation Construction
    
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
        let currentSearch = searchText
        let currentFilter = selectedFilter
        let currentStatus = selectedStatus
        let currentClients = clients
        let currentPayees = payees
        let currentPlanManagers = planManagers
        var items: [TreeItem] = []

        if currentFilter == .all || currentFilter == .clients {
            let filtered = currentClients.filter { client in
                let matchesSearch = currentSearch.isEmpty || client.fullName.localizedCaseInsensitiveContains(currentSearch)
                let matchesStatus = currentStatus == .all || client.status == currentStatus.rawValue
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
                    subtitle: "\(filtered.count) items",
                    children: children
                ))
            }
        }

        if currentFilter == .all || currentFilter == .payees {
            let filtered = currentPayees.filter { payee in
                let matchesSearch = currentSearch.isEmpty || payee.fullName.localizedCaseInsensitiveContains(currentSearch)
                let matchesStatus = currentStatus == .all || (payee.status ?? "") == currentStatus.rawValue
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
                    subtitle: "\(filtered.count) items",
                    children: children
                ))
            }
        }

        if currentFilter == .all || currentFilter == .planManagers {
            let filtered = currentPlanManagers.filter { manager in
                currentSearch.isEmpty || manager.name.localizedCaseInsensitiveContains(currentSearch)
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
                    subtitle: "\(filtered.count) items",
                    children: children
                ))
            }
        }

        var counts: [String: Int] = [:]
        func count(for node: TreeItem) -> Int {
            if let children = node.children, !children.isEmpty {
                let total = children.reduce(0) { $0 + count(for: $1) }
                counts[node.id] = total
                return total
            }
            let value = node.entityId != nil ? 1 : 0
            counts[node.id] = value
            return value
        }
        for item in items {
            _ = count(for: item)
        }

        navigationTree = items
        descendantCountLookup = counts

        // Keep breadcrumb/path in sync with active tree to avoid stale navigation state.
        selectionPath = normalizedSelectionPath(from: selectionPath, tree: items)
        updateGridLayout(for: availableWidth)
    }

    private func normalizedSelectionPath(from path: [String], tree: [TreeItem]) -> [String] {
        var normalized: [String] = []
        var level = tree

        for id in path {
            guard let node = level.first(where: { $0.id == id }),
                  let children = node.children,
                  !children.isEmpty else { break }
            normalized.append(id)
            level = children
        }

        return normalized
    }
    
    private func nodeIdFrom(detailState: DetailState) -> String? {
        switch detailState {
        case .client(let id): return "client_\(id)"
        case .payee(let id): return "payee_\(id)"
        case .planManager(let id): return "planmanager_\(id)"
        default: return nil
        }
    }
}

public struct RelationshipsDetailColumn: View {
    @ObservedObject private var viewModel: RelationshipsContainerViewModel
    
    // Use domain models from ViewModel
    private var clients: [Client] { viewModel.clients }
    private var payees: [Payee] { viewModel.payees }
    private var planManagers: [PlanManager] { viewModel.planManagers }

    @State private var showingDeleteAlert: Bool = false
    @State private var deleteAlertTitle: String = ""
    @State private var deleteAlertMessage: String = ""
    @State private var deleteAction: (() -> Void)?
    @State private var resolvedClient: Client?
    @State private var isResolvingClient: Bool = false

    public init(viewModel: RelationshipsContainerViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        Group {
            switch viewModel.detailState {
            case .client(let objectID):
                clientDetailView(for: objectID)
            case .payee(let objectID):
                if let payee = payees.first(where: { $0.id == objectID }) {
                    // Use domain model directly - PayeeDetailView accepts Payee domain model
                    PayeeDetailView(payee: payee, unitOfWork: viewModel.unitOfWork)
                        .id("payee_\(objectID)")
                } else {
                    emptyState
                }
            case .planManager(let objectID):
                if let manager = planManagers.first(where: { $0.id == objectID }) {
                    // Use domain model directly - PlanManagerDetailView accepts PlanManager domain model
                    PlanManagerDetailView(planManager: manager, unitOfWork: viewModel.unitOfWork)
                        .id("planManager_\(objectID)")
                } else {
                    emptyState
                }
            case .newClient:
                ClientDetailView(unitOfWork: viewModel.unitOfWork) {
                    viewModel.detailState = .none
                }
                .id("new_client")
            case .newPayee:
                PayeeDetailView(unitOfWork: viewModel.unitOfWork) {
                    viewModel.detailState = .none
                }
                .id("new_payee")
            case .newPlanManager:
                PlanManagerDetailView(unitOfWork: viewModel.unitOfWork) {
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
        .toolbar(content: deletionToolbar)
        .alert(deleteAlertTitle, isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteAction?() }
        } message: {
            Text(deleteAlertMessage)
        }
    }

    private func clientDetailView(for objectID: UUID) -> some View {
        Group {
            if let _ = clients.first(where: { $0.id == objectID }) {
                if let client = resolvedClient, client.id == objectID {
                    ClientDetailView(client: client, unitOfWork: viewModel.unitOfWork)
                        .id("client_\(objectID)")
                } else if isResolvingClient {
                    LoadingView("Loading client...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    emptyState
                }
            } else {
                emptyState
            }
        }
        .task(id: objectID) {
            isResolvingClient = true
            resolvedClient = nil
            await Task.yield()
            resolvedClient = try? await viewModel.unitOfWork.clients.fetch(by: objectID)
            isResolvingClient = false
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "person.2.fill",
            title: "No Relationship Selected",
            message: "Select a client, payee, or plan manager from the list."
        )
        .padding()
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
                .pointerStyle(.link)

            case .payee(let objectID) where payees.contains(where: { $0.id == objectID }):
                Button("Delete Payee", systemImage: "trash", role: .destructive) {
                    confirmDeletePayee(with: objectID)
                }
                .tint(Color.red.opacity(0.7))
                .pointerStyle(.link)

            case .planManager(let objectID) where planManagers.contains(where: { $0.id == objectID }):
                Button("Delete Plan Manager", systemImage: "trash", role: .destructive) {
                    confirmDeletePlanManager(with: objectID)
                }
                .tint(Color.red.opacity(0.7))
                .pointerStyle(.link)

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
                    try await viewModel.deleteClient(id: id)
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
                    try await viewModel.deletePayee(id: id)
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
                    try await viewModel.deletePlanManager(id: id)
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
