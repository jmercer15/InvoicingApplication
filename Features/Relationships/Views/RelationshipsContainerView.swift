import SwiftUI
import SwiftData

struct RelationshipsContainerView: View {
    @Environment(\.modelContext) private var viewContext
    @Binding var columnVisibility: NavigationSplitViewVisibility
    
    @StateObject private var viewModel: RelationshipsContainerViewModel
    @State private var isSidebarVisible: Bool = true
    
    // UI state should live in the view, not the view model
    @State private var hSplitPosition: CGFloat = 0.3
    @State private var isSplitterHovering: Bool = false
    // Lifted toolbar state
    @State private var searchText: String = ""
    @State private var selectedFilter: EntityFilter = .all
    @State private var selectedStatus: StatusFilter = .all
    @State private var isMultiSelectMode: Bool = false
    
    // Detail view toolbar state
    @State private var showingDeleteAlert: Bool = false
    @State private var deleteAlertTitle: String = ""
    @State private var deleteAlertMessage: String = ""
    @State private var deleteAction: (() -> Void)?
    
    init(
        columnVisibility: Binding<NavigationSplitViewVisibility>,
        requestRelationshipDelete: @escaping (UUID) -> Void,
        context: ModelContext,
        navigationManager: AppNavigationManager
    ) {
        self._columnVisibility = columnVisibility
        // Pass the delete handler into the ViewModel
        self._viewModel = StateObject(wrappedValue: RelationshipsContainerViewModel(
            context: context,
            navigationManager: navigationManager,
            requestRelationshipDelete: requestRelationshipDelete
        ))
    }

    var body: some View {
        CustomHSplitView(
            fraction: hSplitPosition,
            minPFraction: 0.25,
            maxPFraction: 0.5,
            isPrimaryVisible: $isSidebarVisible,
            primary: { listPanel },
            secondary: { detailPanel },
            splitter: { geo in splitter(geo: geo) }
        )
        .toolbar { 
            consolidatedToolbar
        }
        .searchable(text: $searchText)
        .onChange(of: viewModel.detailState) { _, newState in
            // Force toolbar update when detail state changes
            print("Detail state changed to: \(newState)")
        }
        .alert(deleteAlertTitle, isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAction?()
            }
        } message: {
            Text(deleteAlertMessage)
        }

    }

    // MARK: - Subviews
    private var listPanel: some View {
        RelationshipsView(
            viewModel: viewModel,
            searchText: $searchText,
            selectedFilter: $selectedFilter,
            selectedStatus: $selectedStatus,
            isMultiSelectMode: $isMultiSelectMode
        )
            .environment(\.modelContext, viewContext)
    }

    @ViewBuilder
    private var detailPanel: some View {
        Group {
            switch viewModel.detailState {
            case .client(let objectID):
                if let client = findClient(with: objectID) {
                    ClientDetailView(client: client, context: viewContext)
                        .id("client_\(objectID)")
                } else {
                    emptyState
                }
            case .payee(let objectID):
                if let payee = findPayee(with: objectID) {
                    PayeeDetailView(payee: payee, context: viewContext)
                        .id("payee_\(objectID)")
                } else {
                    emptyState
                }
            case .planManager(let objectID):
                if let planManager = findPlanManager(with: objectID) {
                    PlanManagerDetailView(planManager: planManager, context: viewContext)
                        .id("planManager_\(objectID)")
                } else {
                    emptyState
                }
            case .newClient:
                ClientDetailView(context: viewContext, onSave: {
                    viewModel.detailState = .none
                })
                    .id("new_client")
            case .newPayee:
                PayeeDetailView(context: viewContext, onSave: {
                    viewModel.detailState = .none
                })
                    .id("new_payee")
            case .newPlanManager:
                PlanManagerDetailView(context: viewContext, onSave: {
                    viewModel.detailState = .none
                })
                    .id("new_plan_manager")
            case .selectEntityType:
                EntityTypeSelectionView(viewModel: viewModel)
                    .id("select_entity_type")
            case .none:
                emptyState
            }
        }
        .frame(minWidth: 400)
        .background(Color.black)
    }

    // MARK: - Consolidated Toolbar
    @ToolbarContentBuilder
    private var consolidatedToolbar: some ToolbarContent {
        // Navigation area - Sidebar toggle and search
        ToolbarItem(placement: .navigation) {
            Button(action: { withAnimation(.easeInOut(duration: 0.25)) { isSidebarVisible.toggle() } }) {
                Image(systemName: "sidebar.left")
            }
            .buttonStyle(.glass)
            .help("Toggle Sidebar")
            .appInteractiveCursor()
        }
        

        

        
        // Secondary action area - Filters and multi-select (only when not creating new entity)
        if !viewModel.isCreatingNewEntity {
            ToolbarItem(placement: .secondaryAction) {
                HStack(spacing: 8) {
                    Menu {
                        Picker("Entity Type", selection: $selectedFilter) {
                            ForEach(EntityFilter.allCases, id: \.self) { f in
                                Text(f.displayName).tag(f)
                            }
                        }
                        Picker("Status", selection: $selectedStatus) {
                            ForEach(StatusFilter.allCases, id: \.self) { s in
                                Text(s.displayName).tag(s)
                            }
                        }
                    } label: { Label("Filters", systemImage: "line.3.horizontal.decrease.circle") }
                    .help("Filter by entity type and status")
                    .appInteractiveCursor()

                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isMultiSelectMode.toggle()
                        }
                    }) {
                        Image(systemName: isMultiSelectMode ? "checkmark.circle.fill" : "checkmark.circle")
                    }
                    .help(isMultiSelectMode ? "Exit multi-select mode" : "Select multiple entities")
                    .appInteractiveCursor()
                }
            }
        }
        
        // Primary action area - Dynamic based on context
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 12) {
                // When creating new entity - Show Save/Cancel buttons
                if viewModel.isCreatingNewEntity {
                    Button("Cancel") {
                        viewModel.cancelNewEntity()
                    }
                    .buttonStyle(.glass)
                    .appInteractiveCursor()
                    
                    Button("Save") {
                        viewModel.saveNewEntity()
                    }
                    .buttonStyle(.glass)
                    .appInteractiveCursor()
                }
                // When not creating new entity - Show create button
                else {
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.showEntityTypeSelection()
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.glassProminent)
                    .help("Create a new entity")
                    .appInteractiveCursor()
                }
            }
        }
        
        // Destructive action area - Delete buttons for existing entities
        if !viewModel.isCreatingNewEntity {
            if case .client(let objectID) = viewModel.detailState, findClient(with: objectID) != nil {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete Client", systemImage: "trash", role: .destructive) {
                        confirmDeleteClient(with: objectID)
                    }
                    .buttonStyle(.glass)
                    .tint(Color.red.opacity(0.7))
                    .appInteractiveCursor()
                }
            }
            
            if case .payee(let objectID) = viewModel.detailState, findPayee(with: objectID) != nil {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete Payee", systemImage: "trash", role: .destructive) {
                        confirmDeletePayee(with: objectID)
                    }
                    .buttonStyle(.glass)
                    .tint(Color.red.opacity(0.7))
                    .appInteractiveCursor()
                }
            }
            
            if case .planManager(let objectID) = viewModel.detailState, findPlanManager(with: objectID) != nil {
                ToolbarItem(placement: .destructiveAction) {
                    Button("Delete Plan Manager", systemImage: "trash", role: .destructive) {
                        confirmDeletePlanManager(with: objectID)
                    }
                    .buttonStyle(.glass)
                    .tint(Color.red.opacity(0.7))
                    .appInteractiveCursor()
                }
            }
        }
    }
    

    
    private var emptyState: some View {
        EmptyStateView(
            icon: "person.2.fill",
            title: "No Relationship Selected",
            message: "Select a client, payee, or plan manager from the list."
        )
        .background(Color.black)
    }

    // MARK: - Helper Functions
    
    private func confirmDeleteClient(with id: UUID) {
        deleteAlertTitle = "Delete Client"
        deleteAlertMessage = "Are you sure you want to delete this client? This action cannot be undone."
        deleteAction = {
            if let client = findClient(with: id) {
                viewContext.delete(client)
                try? viewContext.save()
                viewModel.detailState = .none
            }
        }
        showingDeleteAlert = true
    }
    
    private func confirmDeletePayee(with id: UUID) {
        deleteAlertTitle = "Delete Payee"
        deleteAlertMessage = "Are you sure you want to delete this payee? This action cannot be undone."
        deleteAction = {
            if let payee = findPayee(with: id) {
                viewContext.delete(payee)
                try? viewContext.save()
                viewModel.detailState = .none
            }
        }
        showingDeleteAlert = true
    }
    
    private func confirmDeletePlanManager(with id: UUID) {
        deleteAlertTitle = "Delete Plan Manager"
        deleteAlertMessage = "Are you sure you want to delete this plan manager? This action cannot be undone."
        deleteAction = {
            if let planManager = findPlanManager(with: id) {
                viewContext.delete(planManager)
                try? viewContext.save()
                viewModel.detailState = .none
            }
        }
        showingDeleteAlert = true
    }
    
    private func findClient(with id: UUID) -> ClientEntity? {
        let descriptor = FetchDescriptor<ClientEntity>(predicate: #Predicate { $0.id == id })
        return try? viewContext.fetch(descriptor).first
    }
    
    private func findPayee(with id: UUID) -> PayeeEntity? {
        let descriptor = FetchDescriptor<PayeeEntity>(predicate: #Predicate { $0.id == id })
        return try? viewContext.fetch(descriptor).first
    }
    
    private func findPlanManager(with id: UUID) -> PlanManagerEntity? {
        let descriptor = FetchDescriptor<PlanManagerEntity>(predicate: #Predicate { $0.id == id })
        return try? viewContext.fetch(descriptor).first
    }
    
    private func splitter(geo: GeometryProxy) -> some View {
        ZStack {
            Color.black.allowsHitTesting(false)
            Rectangle()
                .fill(isSplitterHovering ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
                .frame(height: 100)
                .cornerRadius(4)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(isSplitterHovering ? Color.gray : Color.clear, lineWidth: 1))
                .contentShape(Rectangle())
                .appSplitterCursor()
            VStack(spacing: isSplitterHovering ? 20 : 6) {
                Circle().fill(isSplitterHovering ? Color.white : Color.gray).frame(width: 4, height: 4)
                Circle().fill(isSplitterHovering ? Color.white : Color.gray).frame(width: 4, height: 4)
                Circle().fill(isSplitterHovering ? Color.white : Color.gray).frame(width: 4, height: 4)
            }
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.3), value: isSplitterHovering)
        }
    }
    
    /// Helper to fetch an entity by its ID from the view's context.
    private func entity(with objectID: UUID) -> Any? {
        // Try to find the entity by ID in the context
        // Since SwiftData doesn't have a direct way to fetch by ID like Core Data,
        // we'll need to implement this differently or remove this function
        // For now, return nil and let the calling code handle it
        return nil
    }
}
