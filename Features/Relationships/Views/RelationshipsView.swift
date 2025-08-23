import SwiftUI
import SwiftData

struct RelationshipsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: RelationshipsContainerViewModel
    
    // SwiftData queries for real-time updates
    @Query(sort: \ClientEntity.fullName) private var clients: [ClientEntity]
    @Query(sort: \PayeeEntity.fullName) private var payees: [PayeeEntity]
    @Query(sort: \PlanManagerEntity.businessName) private var planManagers: [PlanManagerEntity]
    
    // Search and filter state (bound to container)
    @Binding var searchText: String
    @Binding var selectedFilter: EntityFilter
    @Binding var selectedStatus: StatusFilter
    
    // UI state (bound to container)
    @Binding var isMultiSelectMode: Bool
    @State private var selectedItems: Set<UUID> = []
    
    // Collapsible sections state
    @State private var collapsedSections: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            // Enhanced search and filter now provided via toolbar
            
            // Entity list with real-time filtering
            entityList
        }
        .background(Color.black)
        // Toolbar moved to RelationshipsContainerView
        // Create sheet is now triggered from container
        
    }
    
    // MARK: - Search & Filter Bar - moved to window toolbar
    private var searchAndFilterBar: some View { EmptyView() }
    
    // MARK: - Entity List
    private var entityList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Clients section
                if selectedFilter == .all || selectedFilter == .clients {
                    if !filteredClients.isEmpty {
                        CustomSectionHeader(
                            title: "Clients",
                            count: filteredClients.count,
                            icon: "person.2.fill",
                            accentColor: .white,
                            isCollapsed: collapsedSections.contains("clients"),
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    if collapsedSections.contains("clients") {
                                        collapsedSections.remove("clients")
                                    } else {
                                        collapsedSections.insert("clients")
                                    }
                                }
                            }
                        )
                        
                        if !collapsedSections.contains("clients") {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredClients) { client in
                                    ClientRowView(
                                        client: client,
                                        isSelected: selectedItems.contains(client.id),
                                        isMultiSelectMode: isMultiSelectMode,
                                        onSelect: { handleSelection(client.id) },
                                        onTap: { selectClient(client) }
                                    )
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .move(edge: .top))
                            ))
                        }
                    }
                }
                
                // Payees section
                if selectedFilter == .all || selectedFilter == .payees {
                    if !filteredPayees.isEmpty {
                        CustomSectionHeader(
                            title: "Payees",
                            count: filteredPayees.count,
                            icon: "creditcard.fill",
                            accentColor: .white,
                            isCollapsed: collapsedSections.contains("payees"),
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    if collapsedSections.contains("payees") {
                                        collapsedSections.remove("payees")
                                    } else {
                                        collapsedSections.insert("payees")
                                    }
                                }
                            }
                        )
                        
                        if !collapsedSections.contains("payees") {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredPayees) { payee in
                                    PayeeRowView(
                                        payee: payee,
                                        isSelected: selectedItems.contains(payee.id),
                                        isMultiSelectMode: isMultiSelectMode,
                                        onSelect: { handleSelection(payee.id) },
                                        onTap: { selectPayee(payee) }
                                    )
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .move(edge: .top))
                            ))
                        }
                    }
                }
                
                // Plan Managers section
                if selectedFilter == .all || selectedFilter == .planManagers {
                    if !filteredPlanManagers.isEmpty {
                        CustomSectionHeader(
                            title: "Plan Managers",
                            count: filteredPlanManagers.count,
                            icon: "building.2.fill",
                            accentColor: .white,
                            isCollapsed: collapsedSections.contains("planManagers"),
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    if collapsedSections.contains("planManagers") {
                                        collapsedSections.remove("planManagers")
                                    } else {
                                        collapsedSections.insert("planManagers")
                                    }
                                }
                            }
                        )
                        
                        if !collapsedSections.contains("planManagers") {
                            LazyVStack(spacing: 8) {
                                ForEach(filteredPlanManagers) { planManager in
                                    PlanManagerRowView(
                                        planManager: planManager,
                                        isSelected: selectedItems.contains(planManager.id),
                                        isMultiSelectMode: isMultiSelectMode,
                                        onSelect: { handleSelection(planManager.id) },
                                        onTap: { selectPlanManager(planManager) }
                                    )
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .move(edge: .top))
                            ))
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
                    .frame(maxHeight: .infinity)
                    .padding(.top, 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.black)
        .scrollEdgeEffectStyle(.hard, for: .top)
    }
    
    // MARK: - Computed Properties
    private var filteredClients: [ClientEntity] {
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
    
    private var filteredPayees: [PayeeEntity] {
        payees.filter { payee in
            let matchesSearch = searchText.isEmpty || 
                payee.fullName.localizedCaseInsensitiveContains(searchText)
            
            let matchesStatus = selectedStatus == .all || 
                (selectedStatus == .active && payee.status == "Active") ||
                (selectedStatus == .inactive && payee.status == "Inactive")
            
            return matchesSearch && matchesStatus
        }
    }
    
    private var filteredPlanManagers: [PlanManagerEntity] {
        planManagers.filter { planManager in
            let matchesSearch = searchText.isEmpty || 
                (planManager.businessName?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                planManager.abn.localizedCaseInsensitiveContains(searchText)
            
            return matchesSearch
        }
    }
    
    // MARK: - Helper Methods
    private func handleSelection(_ id: UUID) {
        if selectedItems.contains(id) {
            selectedItems.remove(id)
        } else {
            selectedItems.insert(id)
        }
    }
    
    private func selectClient(_ client: ClientEntity) {
        viewModel.detailState = .client(client.id)
    }
    
    private func selectPayee(_ payee: PayeeEntity) {
        viewModel.detailState = .payee(payee.id)
    }
    
    private func selectPlanManager(_ planManager: PlanManagerEntity) {
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

// MARK: - Supporting Types
enum EntityFilter: CaseIterable {
    case all, clients, payees, planManagers
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .clients: return "Clients"
        case .payees: return "Payees"
        case .planManagers: return "Plan Managers"
        }
    }
}

enum StatusFilter: CaseIterable {
    case all, active, inactive
    
    var displayName: String {
        switch self {
        case .all: return "All Status"
        case .active: return "Active"
        case .inactive: return "Inactive"
        }
    }
}

// MARK: - Row Views
struct ClientRowView: View {
    let client: ClientEntity
    let isSelected: Bool
    let isMultiSelectMode: Bool
    let onSelect: () -> Void
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            if isMultiSelectMode {
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .appInteractiveCursor()
            }
            
            HStack {
                Text(client.fullName)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Spacer()
                
                StatusBadge(status: client.status)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 8))
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                onTap()
            }
        }
        .appInteractiveCursor()
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

struct PayeeRowView: View {
    let payee: PayeeEntity
    let isSelected: Bool
    let isMultiSelectMode: Bool
    let onSelect: () -> Void
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            if isMultiSelectMode {
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .appInteractiveCursor()
            }
            
            HStack {
                Text(payee.fullName)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Spacer()
                
                StatusBadge(status: payee.status ?? "Active")
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 8))
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                onTap()
            }
        }
        .appInteractiveCursor()
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

struct PlanManagerRowView: View {
    let planManager: PlanManagerEntity
    let isSelected: Bool
    let isMultiSelectMode: Bool
    let onSelect: () -> Void
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            if isMultiSelectMode {
                Button(action: onSelect) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : .white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .appInteractiveCursor()
            }
            
            HStack {
                Text(planManager.businessName ?? "Unnamed")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Spacer()
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 8))
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                onTap()
            }
        }
        .appInteractiveCursor()
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
    }
}

// MARK: - Custom Section Header
struct CustomSectionHeader: View {
    let title: String
    let count: Int
    let icon: String
    let accentColor: Color
    let isCollapsed: Bool
    let onToggle: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Icon with neutral color
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(isHovered ? 0.4 : 0.3),
                                    .white.opacity(isHovered ? 0.2 : 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("\(count) \(count == 1 ? "item" : "items")")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                // Collapse/expand indicator
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .rotationEffect(.degrees(isHovered ? (isCollapsed ? 90 : -90) : 0))
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
                    .animation(.easeInOut(duration: 0.3), value: isCollapsed)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(in: RoundedRectangle(cornerRadius: 16))
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovered = hovering
                }
            }
        }
        .buttonStyle(.plain)
        .appInteractiveCursor()
    }
}

// MARK: - Entity Type Selection View
struct EntityTypeSelectionView: View {
    @ObservedObject var viewModel: RelationshipsContainerViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
                
                Text("Create New Entity")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Select the type of entity you want to create")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            // Entity Type Options
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
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

// MARK: - Entity Type Option Card
struct EntityTypeOptionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
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
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .opacity(isHovered ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.2), value: isHovered)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovered ? 0.1 : 0.05),
                                Color.white.opacity(isHovered ? 0.05 : 0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                color.opacity(isHovered ? 0.3 : 0.1),
                                lineWidth: isHovered ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .appInteractiveCursor()
    }
}
