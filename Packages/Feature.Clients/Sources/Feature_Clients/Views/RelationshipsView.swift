import SwiftUI
import SwiftData
import SharedUI
import Data
import Core

struct RelationshipsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: RelationshipsContainerViewModel
    
    // Use domain models from ViewModel instead of @Query
    // The ViewModel loads data via repositories and provides domain models
    private var clients: [Client] { viewModel.clients }
    private var payees: [Payee] { viewModel.payees }
    private var planManagers: [PlanManager] { viewModel.planManagers }
    
    // Search and filter state (bound to container)
    @Binding var searchText: String
    @Binding var selectedFilter: EntityFilter
    @Binding var selectedStatus: StatusFilter
    
    // UI state (bound to container)
    @Binding var isMultiSelectMode: Bool
    @State private var selectedItems: Set<UUID> = []
    
    // Collapsible sections state
    @State private var isClientsExpanded: Bool = false
    @State private var isPayeesExpanded: Bool = false
    @State private var isPlanManagersExpanded: Bool = false
    
    private let sectionCornerRadius: CGFloat = 16
    private let sectionInset: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            // Enhanced search and filter now provided via toolbar
            
            // Entity list with real-time filtering
            entityList
        }
        .background(.clear)
        .loadingOverlay(isLoading: viewModel.isLoading, message: "Loading relationships...")
        // Toolbar moved to RelationshipsContainerView
        // Create sheet is now triggered from container
        
    }
    
    // MARK: - Entity List
    private var entityList: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Clients Section
                if selectedFilter == .all || selectedFilter == .clients {
                    if !filteredClients.isEmpty {
                        sectionContainer {
                            CustomSectionHeader(
                                title: "Clients",
                                count: filteredClients.count,
                                icon: "person.2.fill",
                                accentColor: .blue,
                                isCollapsed: !isClientsExpanded,
                                onToggle: {
                                    withAnimation {
                                        if isClientsExpanded {
                                            isClientsExpanded = false
                                        } else {
                                            isClientsExpanded = true
                                            isPayeesExpanded = false
                                            isPlanManagersExpanded = false
                                        }
                                    }
                                }
                            )
                            
                            if isClientsExpanded {
                                ForEach(filteredClients) { client in
                                    ClientRow(
                                        client: client,
                                        isSelected: selectedItems.contains(client.id),
                                        isMultiSelectMode: isMultiSelectMode,
                                        onSelect: { handleSelection(client.id) },
                                        onTap: { selectClient(client) }
                                    )
                                }
                            }
                        }
                    }
                }
                
                // Payees Section
                if selectedFilter == .all || selectedFilter == .payees {
                    if !filteredPayees.isEmpty {
                        sectionContainer {
                            CustomSectionHeader(
                                title: "Payees",
                                count: filteredPayees.count,
                                icon: "creditcard.fill",
                                accentColor: .green,
                                isCollapsed: !isPayeesExpanded,
                                onToggle: {
                                    withAnimation {
                                        if isPayeesExpanded {
                                            isPayeesExpanded = false
                                        } else {
                                            isPayeesExpanded = true
                                            isClientsExpanded = false
                                            isPlanManagersExpanded = false
                                        }
                                    }
                                }
                            )
                            
                            if isPayeesExpanded {
                                ForEach(filteredPayees) { payee in
                                    PayeeRow(
                                        payee: payee,
                                        isSelected: selectedItems.contains(payee.id),
                                        isMultiSelectMode: isMultiSelectMode,
                                        onSelect: { handleSelection(payee.id) },
                                        onTap: { selectPayee(payee) }
                                    )
                                }
                            }
                        }
                    }
                }
                
                // Plan Managers Section
                if selectedFilter == .all || selectedFilter == .planManagers {
                    if !filteredPlanManagers.isEmpty {
                        sectionContainer {
                            CustomSectionHeader(
                                title: "Plan Managers",
                                count: filteredPlanManagers.count,
                                icon: "building.2.fill",
                                accentColor: .orange,
                                isCollapsed: !isPlanManagersExpanded,
                                onToggle: {
                                    withAnimation {
                                        if isPlanManagersExpanded {
                                            isPlanManagersExpanded = false
                                        } else {
                                            isPlanManagersExpanded = true
                                            isClientsExpanded = false
                                            isPayeesExpanded = false
                                        }
                                    }
                                }
                            )
                            
                            if isPlanManagersExpanded {
                                ForEach(filteredPlanManagers) { planManager in
                                    PlanManagerRow(
                                        planManager: planManager,
                                        isSelected: selectedItems.contains(planManager.id),
                                        isMultiSelectMode: isMultiSelectMode,
                                        onSelect: { handleSelection(planManager.id) },
                                        onTap: { selectPlanManager(planManager) }
                                    )
                                }
                            }
                        }
                    }
                }
                
                // Empty state if no items
                if filteredClients.isEmpty && filteredPayees.isEmpty && filteredPlanManagers.isEmpty {
                    EmptyStateView(
                        icon: "person.3.fill",
                        title: "No Relationships Found",
                        message: "No relationships match the current filters. Try adjusting your search or filters."
                    )
                    .background(
                        RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                            .glassEffect(.regular, in: .rect(cornerRadius: 12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 5)
                    .padding(.horizontal, 16)
                    .frame(maxHeight: .infinity)
                    .padding(.top, 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.clear)
        .scrollEdgeEffectStyle(.hard, for: .top)
    }
    
    // MARK: - Computed Properties
    // Note: Filtering is now handled by the ViewModel via repositories
    // These computed properties provide backward compatibility for the view
    private var filteredClients: [Client] {
        clients.filter { client in
            let matchesSearch = searchText.isEmpty || 
                client.fullName.localizedCaseInsensitiveContains(searchText) ||
                client.ndisNumber.localizedCaseInsensitiveContains(searchText)
            
            let matchesStatus = selectedStatus == .all || 
                (selectedStatus == .active && client.status == "Active") ||
                (selectedStatus == .inactive && client.status == "Inactive")
            
            return matchesSearch && matchesStatus
        }
    }
    
    private var filteredPayees: [Payee] {
        payees.filter { payee in
            let matchesSearch = searchText.isEmpty || 
                payee.fullName.localizedCaseInsensitiveContains(searchText)
            
            let matchesStatus = selectedStatus == .all || 
                (selectedStatus == .active && payee.status == "Active") ||
                (selectedStatus == .inactive && payee.status == "Inactive")
            
            return matchesSearch && matchesStatus
        }
    }
    
    private var filteredPlanManagers: [PlanManager] {
        planManagers.filter { planManager in
            let matchesSearch = searchText.isEmpty || 
                planManager.name.localizedCaseInsensitiveContains(searchText) ||
                (planManager.abn ?? "").localizedCaseInsensitiveContains(searchText)
            
            return matchesSearch
        }
    }
    
    private func sectionContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 10.0) {
            content()
        }
        .padding(sectionInset)
        .background(
            RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                .glassEffect(.regular, in: .rect(cornerRadius: 12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Helper Methods
    private func handleSelection(_ id: UUID) {
        if selectedItems.contains(id) {
            selectedItems.remove(id)
        } else {
            selectedItems.insert(id)
        }
    }
    
    private func selectClient(_ client: Client) {
        viewModel.detailState = .client(client.id)
    }
    
    private func selectPayee(_ payee: Payee) {
        viewModel.detailState = .payee(payee.id)
    }
    
    private func selectPlanManager(_ planManager: PlanManager) {
        viewModel.detailState = .planManager(planManager.id)
    }
}

// MARK: - Extensions
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}


// MARK: - Row Views


// MARK: - Entity Type Selection View
struct EntityTypeSelectionView: View {
    @ObservedObject var viewModel: RelationshipsContainerViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color("Primary", bundle: .sharedUI))
                
                Text("Create New Entity")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                Text("Select the type of entity you want to create")
                    .font(.subheadline)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            // Entity Type Options
            GlassEffectContainer(spacing: 16) {
                VStack(spacing: 16) {
                    EntityTypeOptionCard(
                        title: "Client",
                        subtitle: "Create a new client with NDIS details",
                        icon: "person.circle.fill",
                        color: .blue,
                        action: { viewModel.createNewClient() }
                    )
                    
                    EntityTypeOptionCard(
                        title: "Payee",
                        subtitle: "Create a new payee or guardian",
                        icon: "person.2.circle.fill",
                        color: .green,
                        action: { viewModel.createNewPayee() }
                    )
                    
                    EntityTypeOptionCard(
                        title: "Plan Manager",
                        subtitle: "Create a new NDIS plan manager",
                        icon: "building.2.circle.fill",
                        color: .orange,
                        action: { viewModel.createNewPlanManager() }
                    )
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.clear)
    }
}

// MARK: - Entity Type Option Card
struct EntityTypeOptionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    .opacity(0.5)
            }
            .padding(20)
            .contentShape(.rect(cornerRadius: 12))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.06),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .glassEffect(
                .regular
                    .interactive(true)
                    .tint(color.opacity(isHovering ? 0.12 : 0.04)),
                in: .rect(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.2), value: isHovering)
    }
}
