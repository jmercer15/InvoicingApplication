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
    @Namespace private var clientsNamespace
    @Namespace private var payeesNamespace
    @Namespace private var planManagersNamespace

    var body: some View {
        VStack(spacing: 0) {
            // Enhanced search and filter now provided via toolbar
            
            // Entity list with real-time filtering
            entityList
        }
        .background(Color("Background", bundle: .sharedUI))
        // Toolbar moved to RelationshipsContainerView
        // Create sheet is now triggered from container
        
    }
    
    // MARK: - Search & Filter Bar - moved to window toolbar
    private var searchAndFilterBar: some View { EmptyView() }
    
    // MARK: - Entity List
    private var entityList: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Clients Section
                if selectedFilter == .all || selectedFilter == .clients {
                    if !filteredClients.isEmpty {
                        GlassEffectContainer(spacing: 10.0) {
                            VStack(spacing: 10.0) {
                                HStack(spacing: 12) {
                                    // Icon with neutral color
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        .white.opacity(0.3),
                                                        .white.opacity(0.1)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 32, height: 32)
                                        
                                        Image(systemName: "person.2.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color("Text", bundle: .sharedUI))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Clients")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(Color("Text", bundle: .sharedUI))
                                        
                                        Text("\(filteredClients.count) \(filteredClients.count == 1 ? "item" : "items")")
                                            .font(.caption)
                                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: isClientsExpanded ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation {
                                        if isClientsExpanded {
                                            // If already expanded, just collapse
                                            isClientsExpanded = false
                                        } else {
                                            // If collapsed, expand this and collapse others
                                            isClientsExpanded = true
                                            isPayeesExpanded = false
                                            isPlanManagersExpanded = false
                                        }
                                    }
                                }
                                .appInteractiveCursor()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60.0)
                                .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 12))
                                .glassEffectID("clients-header", in: clientsNamespace)
                                
                                if isClientsExpanded {
                                    ForEach(Array(filteredClients.enumerated()), id: \.element.id) { index, client in
                                        HStack(spacing: 12) {
                                            HStack {
                                                Text(client.fullName)
                                                    .font(.headline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(Color("Text", bundle: .sharedUI))
                                                
                                                Spacer()
                                                
                                                Text(client.status)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(Color("Text", bundle: .sharedUI))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color("Gray40", bundle: .sharedUI))
                                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                            }
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 60.0)
                                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                                        .glassEffectID(client.id.uuidString, in: clientsNamespace)
                                        .padding(.leading, 12)
                                        .onTapGesture {
                                            selectClient(client)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Payees Section
                if selectedFilter == .all || selectedFilter == .payees {
                    if !filteredPayees.isEmpty {
                        GlassEffectContainer(spacing: 10.0) {
                            VStack(spacing: 10.0) {
                                HStack(spacing: 12) {
                                    // Icon with neutral color
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        .white.opacity(0.3),
                                                        .white.opacity(0.1)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 32, height: 32)
                                        
                                        Image(systemName: "creditcard.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color("Text", bundle: .sharedUI))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Payees")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(Color("Text", bundle: .sharedUI))
                                        
                                        Text("\(filteredPayees.count) \(filteredPayees.count == 1 ? "item" : "items")")
                                            .font(.caption)
                                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: isPayeesExpanded ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation {
                                        if isPayeesExpanded {
                                            // If already expanded, just collapse
                                            isPayeesExpanded = false
                                        } else {
                                            // If collapsed, expand this and collapse others
                                            isPayeesExpanded = true
                                            isClientsExpanded = false
                                            isPlanManagersExpanded = false
                                        }
                                    }
                                }
                                .appInteractiveCursor()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60.0)
                                .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 12))
                                .glassEffectID("payees-header", in: payeesNamespace)
                                
                                if isPayeesExpanded {
                                    ForEach(Array(filteredPayees.enumerated()), id: \.element.id) { index, payee in
                                        HStack(spacing: 12) {
                                            HStack {
                                                Text(payee.fullName)
                                                    .font(.headline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(Color("Text", bundle: .sharedUI))
                                                
                                                Spacer()
                                                
                                                Text(payee.status ?? "Unknown")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(Color("Text", bundle: .sharedUI))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color("Gray40", bundle: .sharedUI))
                                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                            }
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 60.0)
                                        .glassEffect(.regular, in: .rect(cornerRadius: 12))
                                        .glassEffectID(payee.id.uuidString, in: payeesNamespace)
                                        .padding(.leading, 12)
                                        .onTapGesture {
                                            selectPayee(payee)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Plan Managers Section
                if selectedFilter == .all || selectedFilter == .planManagers {
                    if !filteredPlanManagers.isEmpty {
                        GlassEffectContainer(spacing: 10.0) {
                            VStack(spacing: 10.0) {
                                HStack(spacing: 12) {
                                    // Icon with neutral color
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [
                                                        .white.opacity(0.3),
                                                        .white.opacity(0.1)
                                                    ],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 32, height: 32)
                                        
                                        Image(systemName: "building.2.fill")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color("Text", bundle: .sharedUI))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Plan Managers")
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(Color("Text", bundle: .sharedUI))
                                        
                                        Text("\(filteredPlanManagers.count) \(filteredPlanManagers.count == 1 ? "item" : "items")")
                                            .font(.caption)
                                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: isPlanManagersExpanded ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation {
                                        if isPlanManagersExpanded {
                                            // If already expanded, just collapse
                                            isPlanManagersExpanded = false
                                        } else {
                                            // If collapsed, expand this and collapse others
                                            isPlanManagersExpanded = true
                                            isClientsExpanded = false
                                            isPayeesExpanded = false
                                        }
                                    }
                                }
                                .appInteractiveCursor()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60.0)
                                .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 12))
                                .glassEffectID("planManagers-header", in: planManagersNamespace)
                                
                                if isPlanManagersExpanded {
                                    ForEach(Array(filteredPlanManagers.enumerated()), id: \.element.id) {
 index,
 planManager in
                                        HStack(spacing: 12) {
                                            HStack {
                                                Text(planManager.name ?? "Unknown")
                                                    .font(.headline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(Color("Text", bundle: .sharedUI))
                                                
                                                Spacer()
                                                
                                                Text("Active")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(Color("Text", bundle: .sharedUI))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color("Gray40", bundle: .sharedUI))
                                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                            }
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 60.0)
                                        .glassEffect(
                                            .regular,
                                            in: .rect(cornerRadius: 12)
                                        )
                                        .glassEffectID(planManager.id.uuidString, in: planManagersNamespace)
                                        .padding(.leading, 12)
                                        .onTapGesture {
                                            selectPlanManager(planManager)
                                        }
                                    }
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
                    .frame(maxHeight: .infinity)
                    .padding(.top, 40)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color("Background", bundle: .sharedUI))
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
struct ClientRowView: View {
    let client: Client
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
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
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
    let payee: Payee
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
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
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
    let planManager: PlanManager
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
                Text(planManager.name ?? "Unnamed")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
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
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                }
                .scaleEffect(isHovered ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
                    Text("\(count) \(count == 1 ? "item" : "items")")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                }
                
                Spacer()
                
                // Collapse/expand indicator
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
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
        .background(Color("Background", bundle: .sharedUI))
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
