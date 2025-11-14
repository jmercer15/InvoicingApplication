import SwiftUI
import SwiftData
import Core
import Data
import SharedUI


struct ServiceAssignmentSheetView: View {
    let client: ClientEntity
    let onProceed: ([NDISItem]) -> Void
    let alreadySelectedItems: [NDISItem]
    let availableNDISItems: [NDISItem]

    @Environment(\.modelContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItemIDs: Set<UUID> = []
    @State private var filteredItems: [NDISItem] = []
    @State private var searchText: String = ""

    init(
        client: ClientEntity,
        alreadySelectedItems: [NDISItem],
        availableNDISItems: [NDISItem],
        onProceed: @escaping ([NDISItem]) -> Void
    ) {
        self.client = client
        self.onProceed = onProceed
        self.alreadySelectedItems = alreadySelectedItems
        self.availableNDISItems = availableNDISItems
        self._filteredItems = State(initialValue: availableNDISItems)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Re-using the header from NDISCatalogueView
            header
            
            if filteredItems.isEmpty {
                emptyStateView.frame(maxHeight: .infinity)
            } else {
                listContent
            }
        }
        .padding()
        .background(Color("Background", bundle: .sharedUI).ignoresSafeArea())
        .onAppear {
            // Pre-select already selected items
            for item in alreadySelectedItems {
                selectedItemIDs.insert(item.id)
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Cancel", role: .cancel) { dismiss() }
                    .buttonStyle(.glass)
                    .appInteractiveCursor()
            }
            ToolbarItem(placement: .automatic) {
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
    
    private func assignSelectedServices() {
        let selectedEntities = availableNDISItems.filter { entity in
            selectedItemIDs.contains(entity.id)
        }
        onProceed(selectedEntities)
        dismiss()
    }

    private func updateFilteredItems() {
        if searchText.isEmpty {
            filteredItems = availableNDISItems
        } else {
            filteredItems = availableNDISItems.filter { item in
                item.description?.localizedCaseInsensitiveContains(searchText) ?? false ||
                item.itemNumber.localizedCaseInsensitiveContains(searchText) ||
                item.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Header and Filters (Adapted from NDISCatalogueView)
    
    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                // Title is now in the navigation bar
                Spacer()
                HStack {
                    TextField("Search NDIS Items...", text: $searchText)
                        .onChange(of: searchText) { _, _ in
                            updateFilteredItems()
                        }
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .foregroundColor(Color("White", bundle: .sharedUI))
                        .background(Color("Background", bundle: .sharedUI).opacity(0.3))
                        .cornerRadius(8)
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: 400)
                
                Spacer()
                
                if !filteredItems.isEmpty {
                    Text("\(selectedItemIDs.count) of \(filteredItems.count)")
                        .font(.subheadline)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
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
                    if false { // NDIS functionality temporarily disabled
                        clearAllFiltersButton
                    }
                    sortMenu
                }
                
                if false { // NDIS functionality temporarily disabled
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
                ForEach(filteredItems) { item in
                    serviceRow(for: item)
                }
                loadMoreView
            }
        }
    }
    
    @ViewBuilder
    private func serviceRow(for item: NDISItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: selectedItemIDs.contains(item.id) ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundColor(selectedItemIDs.contains(item.id) ? .accentColor : .white.opacity(0.6))
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(Color("White", bundle: .sharedUI))
                Text(item.itemNumber)
                    .font(.subheadline)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
            
            Spacer()
            
            priceRangeDisplay(for: item)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .glassEffect(in: RoundedRectangle(cornerRadius: 10))
        .scaleEffect(selectedItemIDs.contains(item.id) ? 1.02 : 1.0)
        .shadow(
            color: selectedItemIDs.contains(item.id) ? Color.accentColor.opacity(0.3) : Color("Background", bundle: .sharedUI).opacity(0.1),
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
            Button("All Categories") { } // NDIS functionality temporarily disabled
                .appInteractiveCursor()
            Divider()
            ForEach([String](), id: \.self) { category in // NDIS functionality temporarily disabled
                Button(category) { } // NDIS functionality temporarily disabled
                    .appInteractiveCursor()
            }
        } label: {
            Text("Category: All") // NDIS functionality temporarily disabled
        }
        .pickerStyle(.menu)
    }
    
    private var registrationGroupMenu: some View {
        Menu {
            Button("All Groups") { } // NDIS functionality temporarily disabled
                .appInteractiveCursor()
            Divider()
            ForEach([String](), id: \.self) { group in // NDIS functionality temporarily disabled
                Button(group.isEmpty ? "Unassigned" : group) { } // NDIS functionality temporarily disabled
                    .appInteractiveCursor()
            }
        } label: {
            Text("Group: All") // NDIS functionality temporarily disabled
        }
        .pickerStyle(.menu)
    }
    
    private var quoteFilterMenu: some View {
        Picker("Pricing", selection: .constant("")) { // NDIS functionality temporarily disabled
            Text("All").tag("")
        }
        .pickerStyle(.menu)
    }
    
    
    
    private var sortMenu: some View {
        Picker("Sort By", selection: .constant("")) { // NDIS functionality temporarily disabled
            Text("Default").tag("")
        }
        .pickerStyle(.menu)
    }
    
    private var featuresFilterMenu: some View {
        Menu {
            ForEach([String](), id: \.self) { feature in // NDIS functionality temporarily disabled
                Button(action: { }) { // NDIS functionality temporarily disabled
                    HStack {
                        Text(feature)
                        Spacer()
                        if false { // NDIS functionality temporarily disabled
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .appInteractiveCursor()
            }
        } label: {
            Text("Features (0)") // NDIS functionality temporarily disabled
        }
        .pickerStyle(.menu)
    }
    
    private var unitsFilterMenu: some View {
        Menu {
            ForEach([String](), id: \.self) { unit in // NDIS functionality temporarily disabled
                Button(action: { }) { // NDIS functionality temporarily disabled
                    HStack {
                        Text(unit) // NDIS functionality temporarily disabled
                        Spacer()
                        if false { // NDIS functionality temporarily disabled
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .appInteractiveCursor()
            }
        } label: {
            Text("Units (0)") // NDIS functionality temporarily disabled
        }
        .pickerStyle(.menu)
    }
    
    @ViewBuilder
    private var clearAllFiltersButton: some View {
        Button(action: { }) { // NDIS functionality temporarily disabled
            Label("Clear All Filters", systemImage: "xmark.circle.fill")
        }
        .buttonStyle(.plain)
        .foregroundColor(Color("Cancelled", bundle: .sharedUI))
        .appInteractiveCursor()
    }
    
    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach([String](), id: \.self) { filter in // NDIS functionality temporarily disabled
                    HStack(spacing: 4) {
                        Text(filter) // NDIS functionality temporarily disabled
                        Button(action: { }) { // NDIS functionality temporarily disabled
                            Image(systemName: "xmark.circle.fill")
                        }
                        .appInteractiveCursor()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
                    .buttonStyle(.plain)
                    .foregroundColor(Color("White", bundle: .sharedUI))
                }
            }
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.clipboard")
                .font(.largeTitle)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            Text("No NDIS Items Found")
                .font(.title2)
            Text("Try adjusting your search or filter criteria.")
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
        }
    }
    
    @ViewBuilder
    private var loadMoreView: some View {
        EmptyView()
    }
    
    @ViewBuilder
    private func priceRangeDisplay(for item: NDISItem) -> some View {
        if !item.regionalPrices.isEmpty {
            let priceValues = item.regionalPrices.map { $0.amount }
            let minPrice = priceValues.min() ?? 0.0
            let maxPrice = priceValues.max() ?? 0.0
            
            VStack(alignment: .trailing, spacing: 2) {
                if minPrice == maxPrice {
                    Text(String(format: "$%.2f", minPrice)).fontWeight(.medium)
                } else {
                    Text(String(format: "$%.2f - $%.2f", minPrice, maxPrice)).fontWeight(.medium)
                }
                Text("/ \(item.unit ?? "")").font(.caption).foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
        } else if let price = item.price, price > 0 {
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "$%.2f", price)).fontWeight(.medium)
                Text("/ \(item.unit ?? "")").font(.caption).foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
        } else {
            VStack(alignment: .trailing, spacing: 2) {
                Text("No Price").font(.caption).fontWeight(.medium)
                Text("/ \(item.unit ?? "")").font(.caption).foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
        }
    }
}
