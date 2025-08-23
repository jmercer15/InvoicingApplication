import SwiftUI
import SwiftData


struct ServiceAssignmentSheetView: View {
    let client: ClientEntity
    let onProceed: ([NDISItemEntity]) -> Void
    let alreadySelectedItems: [NDISItemEntity]
    
    @Environment(\.modelContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var viewModel: NDISContainerViewModel
    @State private var selectedItemIDs: Set<UUID> = []
    
    init(
        client: ClientEntity,
        alreadySelectedItems: [NDISItemEntity],
        onProceed: @escaping ([NDISItemEntity]) -> Void
    ) {
        self.client = client
        self.onProceed = onProceed
        self.alreadySelectedItems = alreadySelectedItems
        
        // Initialize the ViewModel without context - will be set in onAppear
        self._viewModel = StateObject(wrappedValue: NDISContainerViewModel(context: ModelContext(try! ModelContainer(for: NDISItemEntity.self))))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Re-using the header from NDISCatalogueView
            header
            
            if viewModel.paginatedItems.isEmpty {
                emptyStateView.frame(maxHeight: .infinity)
            } else {
                listContent
            }
        }
        .padding()
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            // Set the context for the ViewModel
            // Context is already set in the initializer
            
            // Load NDIS items for the ViewModel when the view appears
            loadNDISItems()
            
            // Pre-select already selected items
            for item in alreadySelectedItems {
                selectedItemIDs.insert(item.id)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .cancel) { dismiss() }
                    .buttonStyle(.glass)
                    .appInteractiveCursor()
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Next: Configure \(selectedItemIDs.count) Services") {
                    assignSelectedServices()
                }
                .buttonStyle(.glassProminent)
                .appInteractiveCursor()
                .disabled(selectedItemIDs.isEmpty)
            }
        }
        .navigationTitle("Assign Services to \(client.fullName)")
        .frame(minWidth: 900, idealWidth: 1000, minHeight: 700, idealHeight: 800)
        
    }
    
    private func loadNDISItems() {
        let descriptor = FetchDescriptor<NDISItemEntity>(sortBy: [SortDescriptor(\.itemNumber)])
        if let items = try? viewContext.fetch(descriptor) {
            viewModel.setSourceItems(ndisItems: items)
        }
    }
    
    private func assignSelectedServices() {
        let selectedEntities = viewModel.paginatedItems.filter { entity in
            selectedItemIDs.contains(entity.id)
        }
        onProceed(selectedEntities)
        dismiss()
    }
    
    // MARK: - Header and Filters (Adapted from NDISCatalogueView)
    
    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                // Title is now in the navigation bar
                Spacer()
                HStack {
                    TextField("Search NDIS Items...", text: $viewModel.searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: 400)
                
                Spacer()
                
                if !viewModel.filteredItems.isEmpty {
                    Text("\(viewModel.paginatedItems.count) of \(viewModel.filteredItems.count)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            
            // Filter controls
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    categoryMenu
                    registrationGroupMenu
                    quoteFilterMenu
                    Spacer()
                }
                HStack {
                    featuresFilterMenu
                    unitsFilterMenu
                    Spacer()
                    if viewModel.hasActiveFilters() {
                        clearAllFiltersButton
                    }
                    sortMenu
                }
                
                if !viewModel.activeFilters.isEmpty {
                    activeFiltersView.padding(.top, 4)
                }
            }
            .padding(EdgeInsets(top: 12, leading: 16, bottom: 16, trailing: 16))
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
        }
        .padding(.bottom, 16)
    }
    
    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(viewModel.paginatedItems) { item in
                    serviceRow(for: item)
                }
                loadMoreView
            }
        }
    }
    
    @ViewBuilder
    private func serviceRow(for item: NDISItemEntity) -> some View {
        HStack(spacing: 12) {
            Image(systemName: selectedItemIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(selectedItemIDs.contains(item.id) ? .accentColor : .white.opacity(0.6))
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                Text(item.itemNumber)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            priceRangeDisplay(for: item)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 10))
        .scaleEffect(selectedItemIDs.contains(item.id) ? 1.02 : 1.0)
        .shadow(
            color: selectedItemIDs.contains(item.id) ? Color.accentColor.opacity(0.3) : Color.black.opacity(0.1),
            radius: selectedItemIDs.contains(item.id) ? 6 : 2,
            x: 0,
            y: selectedItemIDs.contains(item.id) ? 3 : 1
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedItemIDs.contains(item.id))
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedItemIDs.contains(item.id) {
                selectedItemIDs.remove(item.id)
            } else {
                selectedItemIDs.insert(item.id)
            }
        }
        .appInteractiveCursor()
        .padding(.horizontal, 4)
    }
    
    // MARK: - Filter Menu Components (Copied & Adapted)
    
    private var categoryMenu: some View {
        Menu {
            Button("All Categories") { viewModel.selectedCategoryId = nil }
                .appInteractiveCursor()
            Divider()
            ForEach(viewModel.cachedCategories, id: \.self) { category in
                Button(category) { viewModel.selectedCategoryId = category }
                    .appInteractiveCursor()
            }
        } label: {
            Text("Category: \(viewModel.selectedCategoryId ?? "All")")
        }
        .pickerStyle(.menu)
    }
    
    private var registrationGroupMenu: some View {
        Menu {
            Button("All Groups") { viewModel.selectedRegistrationGroup = nil }
                .appInteractiveCursor()
            Divider()
            ForEach(viewModel.registrationGroupsForMenu, id: \.self) { group in
                Button(group.isEmpty ? "Unassigned" : group) { viewModel.selectedRegistrationGroup = group }
                    .appInteractiveCursor()
            }
        } label: {
            Text("Group: \(viewModel.selectedRegistrationGroup ?? "All")")
        }
        .pickerStyle(.menu)
    }
    
    private var quoteFilterMenu: some View {
        Picker("Pricing", selection: $viewModel.quoteFilter) {
            ForEach(NDISContainerViewModel.QuoteFilter.allCases) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.menu)
    }
    
    
    
    private var sortMenu: some View {
        Picker("Sort By", selection: $viewModel.sortOrder) {
            ForEach(NDISContainerViewModel.SortOrder.allCases) { order in
                Text(order.rawValue).tag(order)
            }
        }
        .pickerStyle(.menu)
    }
    
    private var featuresFilterMenu: some View {
        Menu {
            ForEach(viewModel.featuresForToolbarMenu, id: \.self) { feature in
                Button(action: { viewModel.toggleFeatureSelection(feature) }) {
                    HStack {
                        Text(feature)
                        Spacer()
                        if viewModel.currentSelectedFeatures.contains(feature) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .appInteractiveCursor()
            }
        } label: {
            Text("Features (\(viewModel.currentSelectedFeatures.count))")
        }
        .pickerStyle(.menu)
    }
    
    private var unitsFilterMenu: some View {
        Menu {
            ForEach(viewModel.unitsForToolbarMenu, id: \.self) { unit in
                Button(action: { viewModel.toggleUnitSelection(unit) }) {
                    HStack {
                        Text(viewModel.displayString(forUnit: unit))
                        Spacer()
                        if viewModel.currentSelectedUnits.contains(unit) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .appInteractiveCursor()
            }
        } label: {
            Text("Units (\(viewModel.currentSelectedUnits.count))")
        }
        .pickerStyle(.menu)
    }
    
    @ViewBuilder
    private var clearAllFiltersButton: some View {
        Button(action: viewModel.clearAllFilters) {
            Label("Clear All Filters", systemImage: "xmark.circle.fill")
        }
        .buttonStyle(.plain)
        .foregroundColor(.red)
        .appInteractiveCursor()
    }
    
    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(viewModel.activeFilters) { filter in
                    HStack(spacing: 4) {
                        Text(filter.name)
                        Button(action: { viewModel.removeFilter(filter) }) {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .appInteractiveCursor()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
                    .buttonStyle(.plain)
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.clipboard")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No NDIS Items Found")
                .font(.title2)
            Text("Try adjusting your search or filter criteria.")
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var loadMoreView: some View {
        if viewModel.hasMoreItemsToLoad() {
            Button("Load More (\(viewModel.filteredItems.count - viewModel.paginatedItems.count) remaining)") {
                viewModel.loadMoreItems()
            }
            .appInteractiveCursor()
            .padding()
        }
    }
    
    @ViewBuilder
    private func priceRangeDisplay(for item: NDISItemEntity) -> some View {
        if let prices = item.regionalPrices, !prices.isEmpty {
            let priceValues = prices.map { $0.amount }
            let minPrice = priceValues.min() ?? 0.0
            let maxPrice = priceValues.max() ?? 0.0
            
            VStack(alignment: .trailing, spacing: 2) {
                if minPrice == maxPrice {
                    Text(String(format: "$%.2f", minPrice)).fontWeight(.medium)
                } else {
                    Text(String(format: "$%.2f - $%.2f", minPrice, maxPrice)).fontWeight(.medium)
                }
                Text("/ \(item.unit ?? "")").font(.caption).foregroundColor(.secondary)
            }
        } else if item.quoteRequired == true {
            VStack(alignment: .trailing, spacing: 2) {
                Text("Quote Required").font(.caption).fontWeight(.medium)
                Text("/ \(item.unit ?? "")").font(.caption).foregroundColor(.secondary)
            }
        } else {
            VStack(alignment: .trailing, spacing: 2) {
                Text("No Price").font(.caption).fontWeight(.medium)
                Text("/ \(item.unit ?? "")").font(.caption).foregroundColor(.secondary)
            }
        }
    }
}
