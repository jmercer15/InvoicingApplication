import SwiftUI
import SwiftData
import Core
import Data
import SharedUI


struct ServiceAssignmentSheetView: View {
    let client: Client
    let onProceed: ([NDISItem]) -> Void
    let alreadySelectedItems: [NDISItem]
    let availableNDISItems: [NDISItem]

    @Environment(\.dismiss) private var dismiss

    @State private var selectedItemIDs: Set<UUID> = []
    @State private var filteredItems: [NDISItem] = []
    @State private var searchText: String = ""
    @State private var selectedCategory: String?
    @State private var selectedRegistrationGroup: String?
    @State private var selectedQuoteFilter: QuoteFilter = .all
    @State private var selectedFeatures: Set<String> = []
    @State private var selectedUnits: Set<String> = []
    @State private var selectedSortOption: SortOption = .defaultOrder

    init(
        client: Client,
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
        .glassEffect(.regular, in: .rect())
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
                    .pointerStyle(.link)
            }
            ToolbarItem(placement: .automatic) {
                Button("Next: Configure \(selectedItemIDs.count) Services") {
                    assignSelectedServices()
                }
                .buttonStyle(.glassProminent)
                .pointerStyle(.link)
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
        var items = availableNDISItems.filter { item in
            searchMatches(item)
                && categoryMatches(item)
                && registrationGroupMatches(item)
                && quoteFilterMatches(item)
                && featureFilterMatches(item)
                && unitFilterMatches(item)
        }
        sortFilteredItems(&items)
        filteredItems = items
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
                        .glassEffect(.regular, in: .rect(cornerRadius: 8))
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
                    if hasActiveFilters {
                        clearAllFiltersButton
                    }
                    sortMenu
                }
                
                if hasActiveFilters {
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
        .glassEffect(.regular.interactive(true), in: RoundedRectangle(cornerRadius: 10))
        .scaleEffect(selectedItemIDs.contains(item.id) ? 1.02 : 1.0)
        .shadow(
            color: selectedItemIDs.contains(item.id) ? Color.accentColor.opacity(0.3) : Color("Background", bundle: .sharedUI).opacity(0.1),
            radius: selectedItemIDs.contains(item.id) ? 6 : 2,
            x: 0,
            y: selectedItemIDs.contains(item.id) ? 3 : 1
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedItemIDs.contains(item.id))
        .contentShape(.rect(cornerRadius: 10))
        .onTapGesture {
            if selectedItemIDs.contains(item.id) {
                selectedItemIDs.remove(item.id)
            } else {
                selectedItemIDs.insert(item.id)
            }
        }
        .pointerStyle(.link)
        .padding(.horizontal, 4)
    }
    
    // MARK: - Filter Menu Components (Copied & Adapted)
    
    private var categoryMenu: some View {
        Menu {
            Button("All Categories") {
                selectedCategory = nil
                updateFilteredItems()
            }
                .pointerStyle(.link)
            Divider()
            ForEach(categoryOptions, id: \.self) { category in
                Button(category) {
                    selectedCategory = category
                    updateFilteredItems()
                }
                    .pointerStyle(.link)
            }
        } label: {
            Text("Category: \(selectedCategory ?? "All")")
        }
        .pickerStyle(.menu)
    }
    
    private var registrationGroupMenu: some View {
        Menu {
            Button("All Groups") {
                selectedRegistrationGroup = nil
                updateFilteredItems()
            }
                .pointerStyle(.link)
            Divider()
            ForEach(registrationGroupOptions, id: \.self) { group in
                Button(group) {
                    selectedRegistrationGroup = group
                    updateFilteredItems()
                }
                    .pointerStyle(.link)
            }
        } label: {
            Text("Group: \(selectedRegistrationGroup ?? "All")")
        }
        .pickerStyle(.menu)
    }
    
    private var quoteFilterMenu: some View {
        Picker("Pricing", selection: $selectedQuoteFilter) {
            ForEach(QuoteFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.menu)
        .onChange(of: selectedQuoteFilter) { _, _ in
            updateFilteredItems()
        }
    }
    
    
    
    private var sortMenu: some View {
        Picker("Sort By", selection: $selectedSortOption) {
            ForEach(SortOption.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.menu)
        .onChange(of: selectedSortOption) { _, _ in
            updateFilteredItems()
        }
    }
    
    private var featuresFilterMenu: some View {
        Menu {
            ForEach(featureOptions, id: \.self) { feature in
                Button(action: {
                    toggleFeature(feature)
                }) {
                    HStack {
                        Text(feature)
                        Spacer()
                        if selectedFeatures.contains(feature) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .pointerStyle(.link)
            }
        } label: {
            Text("Features (\(selectedFeatures.count))")
        }
        .pickerStyle(.menu)
    }
    
    private var unitsFilterMenu: some View {
        Menu {
            ForEach(unitOptions, id: \.self) { unit in
                Button(action: {
                    toggleUnit(unit)
                }) {
                    HStack {
                        Text(unit)
                        Spacer()
                        if selectedUnits.contains(unit) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .pointerStyle(.link)
            }
        } label: {
            Text("Units (\(selectedUnits.count))")
        }
        .pickerStyle(.menu)
    }
    
    @ViewBuilder
    private var clearAllFiltersButton: some View {
        Button(action: clearAllFilters) {
            Label("Clear All Filters", systemImage: "xmark.circle.fill")
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundColor(Color("Cancelled", bundle: .sharedUI))
        .pointerStyle(.link)
    }
    
    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(activeFilterChips, id: \.id) { filter in
                    HStack(spacing: 4) {
                        Text(filter.label)
                        Button(action: filter.remove) {
                            Image(systemName: "xmark.circle.fill")
                                .contentShape(Circle())
                        }
                        .pointerStyle(.link)
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

private extension ServiceAssignmentSheetView {
    enum QuoteFilter: String, CaseIterable, Identifiable {
        case all
        case quoteRequired
        case noQuoteRequired
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .all: return "Pricing: All"
            case .quoteRequired: return "Pricing: Quote Required"
            case .noQuoteRequired: return "Pricing: No Quote"
            }
        }
    }
    
    enum SortOption: String, CaseIterable, Identifiable {
        case defaultOrder
        case nameAZ
        case nameZA
        case codeAZ
        case priceLowToHigh
        case priceHighToLow
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .defaultOrder: return "Sort: Default"
            case .nameAZ: return "Sort: Name A-Z"
            case .nameZA: return "Sort: Name Z-A"
            case .codeAZ: return "Sort: Code A-Z"
            case .priceLowToHigh: return "Sort: Price Low-High"
            case .priceHighToLow: return "Sort: Price High-Low"
            }
        }
    }
    
    struct FilterChip: Identifiable {
        let id: String
        let label: String
        let remove: () -> Void
    }
    
    var hasActiveFilters: Bool {
        !activeFilterChips.isEmpty
    }
    
    var categoryOptions: [String] {
        sortedUnique(availableNDISItems.compactMap { normalizedText($0.category) })
    }
    
    var registrationGroupOptions: [String] {
        sortedUnique(availableNDISItems.compactMap { normalizedText($0.registrationGroup) })
    }
    
    var unitOptions: [String] {
        sortedUnique(availableNDISItems.compactMap { normalizedText($0.unit) })
    }
    
    var featureOptions: [String] {
        sortedUnique(availableNDISItems.flatMap(parsedFeatures(from:)))
    }
    
    var activeFilterChips: [FilterChip] {
        var chips: [FilterChip] = []
        
        if let selectedCategory {
            chips.append(
                FilterChip(id: "category:\(selectedCategory)", label: "Category: \(selectedCategory)") {
                    self.selectedCategory = nil
                    self.updateFilteredItems()
                }
            )
        }
        
        if let selectedRegistrationGroup {
            chips.append(
                FilterChip(id: "group:\(selectedRegistrationGroup)", label: "Group: \(selectedRegistrationGroup)") {
                    self.selectedRegistrationGroup = nil
                    self.updateFilteredItems()
                }
            )
        }
        
        if selectedQuoteFilter != .all {
            chips.append(
                FilterChip(id: "quote:\(selectedQuoteFilter.rawValue)", label: selectedQuoteFilter.title.replacingOccurrences(of: "Pricing: ", with: "")) {
                    self.selectedQuoteFilter = .all
                    self.updateFilteredItems()
                }
            )
        }
        
        for feature in selectedFeatures.sorted() {
            chips.append(
                FilterChip(id: "feature:\(feature)", label: "Feature: \(feature)") {
                    self.selectedFeatures.remove(feature)
                    self.updateFilteredItems()
                }
            )
        }
        
        for unit in selectedUnits.sorted() {
            chips.append(
                FilterChip(id: "unit:\(unit)", label: "Unit: \(unit)") {
                    self.selectedUnits.remove(unit)
                    self.updateFilteredItems()
                }
            )
        }
        
        return chips
    }
    
    func clearAllFilters() {
        selectedCategory = nil
        selectedRegistrationGroup = nil
        selectedQuoteFilter = .all
        selectedFeatures.removeAll()
        selectedUnits.removeAll()
        selectedSortOption = .defaultOrder
        updateFilteredItems()
    }
    
    func toggleFeature(_ feature: String) {
        if selectedFeatures.contains(feature) {
            selectedFeatures.remove(feature)
        } else {
            selectedFeatures.insert(feature)
        }
        updateFilteredItems()
    }
    
    func toggleUnit(_ unit: String) {
        if selectedUnits.contains(unit) {
            selectedUnits.remove(unit)
        } else {
            selectedUnits.insert(unit)
        }
        updateFilteredItems()
    }
    
    func searchMatches(_ item: NDISItem) -> Bool {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return item.description?.localizedCaseInsensitiveContains(needle) ?? false
            || item.itemNumber.localizedCaseInsensitiveContains(needle)
            || item.name.localizedCaseInsensitiveContains(needle)
    }
    
    func categoryMatches(_ item: NDISItem) -> Bool {
        guard let selectedCategory else { return true }
        return normalizedText(item.category) == selectedCategory
    }
    
    func registrationGroupMatches(_ item: NDISItem) -> Bool {
        guard let selectedRegistrationGroup else { return true }
        return normalizedText(item.registrationGroup) == selectedRegistrationGroup
    }
    
    func quoteFilterMatches(_ item: NDISItem) -> Bool {
        switch selectedQuoteFilter {
        case .all:
            return true
        case .quoteRequired:
            return item.quoteRequired == true
        case .noQuoteRequired:
            return item.quoteRequired != true
        }
    }
    
    func featureFilterMatches(_ item: NDISItem) -> Bool {
        guard !selectedFeatures.isEmpty else { return true }
        let itemFeatures = Set(parsedFeatures(from: item))
        return selectedFeatures.allSatisfy { itemFeatures.contains($0) }
    }
    
    func unitFilterMatches(_ item: NDISItem) -> Bool {
        guard !selectedUnits.isEmpty else { return true }
        guard let unit = normalizedText(item.unit) else { return false }
        return selectedUnits.contains(unit)
    }
    
    func sortFilteredItems(_ items: inout [NDISItem]) {
        switch selectedSortOption {
        case .defaultOrder:
            let indexes = Dictionary(uniqueKeysWithValues: availableNDISItems.enumerated().map { ($1.id, $0) })
            items.sort {
                (indexes[$0.id] ?? .max) < (indexes[$1.id] ?? .max)
            }
        case .nameAZ:
            items.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .nameZA:
            items.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending
            }
        case .codeAZ:
            items.sort {
                $0.itemNumber.localizedCaseInsensitiveCompare($1.itemNumber) == .orderedAscending
            }
        case .priceLowToHigh:
            items.sort {
                effectivePrice(for: $0) < effectivePrice(for: $1)
            }
        case .priceHighToLow:
            items.sort {
                effectivePrice(for: $0) > effectivePrice(for: $1)
            }
        }
    }
    
    func effectivePrice(for item: NDISItem) -> Double {
        if !item.regionalPrices.isEmpty {
            return item.regionalPrices.map(\.amount).min() ?? item.price ?? .greatestFiniteMagnitude
        }
        return item.price ?? .greatestFiniteMagnitude
    }
    
    func parsedFeatures(from item: NDISItem) -> [String] {
        guard let features = item.features, !features.isEmpty else { return [] }
        return features
            .split(whereSeparator: { [",", ";", "|"].contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    func sortedUnique(_ values: [String]) -> [String] {
        Array(Set(values)).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }
}
