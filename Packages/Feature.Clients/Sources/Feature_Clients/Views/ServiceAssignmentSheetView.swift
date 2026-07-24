import SwiftUI
import SwiftData
import Core
import Data
import SharedUI


struct ServiceAssignmentSheetView: View {
    let client: Client
    let onProceed: ([NDISItem]) -> Void
    let alreadySelectedItems: [NDISItem]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    @State private var availableNDISItems: [NDISItem] = []
    @State private var isLoadingItems: Bool = false
    @State private var selectedItemIDs: Set<UUID> = []
    @State private var filteredItems: [NDISItem] = []
    @State private var searchText: String = ""
    @State private var selectedCategory: String?
    @State private var selectedRegistrationGroup: String?
    @State private var selectedQuoteFilter: ServiceAssignmentQuoteFilter = .all
    @State private var selectedFeatures: Set<String> = []
    @State private var selectedUnits: Set<String> = []
    @State private var selectedSortOption: ServiceAssignmentSortOption = .defaultOrder

    init(
        client: Client,
        alreadySelectedItems: [NDISItem],
        onProceed: @escaping ([NDISItem]) -> Void
    ) {
        self.client = client
        self.onProceed = onProceed
        self.alreadySelectedItems = alreadySelectedItems
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Re-using the header from NDISCatalogueView
            header

            if isLoadingItems {
                LoadingView("Loading catalog...")
                    .frame(maxHeight: .infinity)
            } else if filteredItems.isEmpty {
                emptyStateView.frame(maxHeight: .infinity)
            } else {
                listContent
            }
        }
        .padding(StyleGuide.Dimensions.paddingMedium)
        .background(StyleGuide.Colors.background)
        .onAppear {
            // Pre-select already selected items
            for item in alreadySelectedItems {
                selectedItemIDs.insert(item.id)
            }
        }
        .task { @MainActor in
            isLoadingItems = true
            let actor = ReferenceDataWorkflowActor(modelContainer: modelContext.container)
            do {
                let ids = try await actor.fetchAllNDISItemIDs()
                let descriptor = FetchDescriptor<NDISItem>(
                    predicate: #Predicate { ids.contains($0.persistentModelID) }
                )
                let items = (try? modelContext.fetch(descriptor)) ?? []
                self.availableNDISItems = items
                self.updateFilteredItems()
                self.isLoadingItems = false
            } catch {
                print("Failed to fetch NDIS items: \(error)")
                self.isLoadingItems = false
            }
        }
        .onChange(of: availableNDISItems) { _, _ in
            updateFilteredItems()
        }
        .toolbar {
            AppToolbarSheetBar(
                confirmTitle: "Next: Configure \(selectedItemIDs.count) Services",
                isConfirmDisabled: selectedItemIDs.isEmpty,
                onCancel: { dismiss() },
                onConfirm: { assignSelectedServices() }
            )
        }
        .navigationTitle("Assign Services to \(client.fullName)")
        .frame(
            minWidth: StyleGuide.Dimensions.sheetMinWidth,
            idealWidth: StyleGuide.Dimensions.sheetIdealWidth,
            minHeight: StyleGuide.Dimensions.sheetMinHeight,
            idealHeight: StyleGuide.Dimensions.sheetIdealHeight
        )
        
    }
    
    private func assignSelectedServices() {
        let selectedEntities = availableNDISItems.filter { entity in
            selectedItemIDs.contains(entity.id)
        }
        onProceed(selectedEntities)
        dismiss()
    }

    private func updateFilteredItems() {
        let spec = catalogueQuerySpec
        let filteredSnapshots = NDISCatalogueQuery.filteredAndSortedItems(
            from: availableNDISItems.map { $0.snapshot() },
            spec: spec
        )
        var items = filteredSnapshots.compactMap { snapshot in
            availableNDISItems.first { $0.id == snapshot.id }
        }
        if selectedSortOption == .defaultOrder {
            let indexes = Dictionary(uniqueKeysWithValues: availableNDISItems.enumerated().map { ($1.id, $0) })
            items.sort { (indexes[$0.id] ?? .max) < (indexes[$1.id] ?? .max) }
        }
        filteredItems = items
    }

    private var catalogueQuerySpec: NDISCatalogueQuerySpec {
        NDISCatalogueQuerySpec(
            searchText: searchText,
            quoteFilter: coreQuoteFilter(selectedQuoteFilter),
            selectedCategoryId: selectedCategory,
            selectedRegistrationGroup: selectedRegistrationGroup,
            sortOrder: coreSortOrder(selectedSortOption),
            selectedFeatures: Array(selectedFeatures),
            selectedUnits: Array(selectedUnits),
            itemVersionFilter: .currentOnly
        )
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
                        .foregroundColor(StyleGuide.Colors.text)
                }
                .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                .frame(maxWidth: 400)
                
                Spacer()
                
                if !filteredItems.isEmpty {
                    Text("\(selectedItemIDs.count) of \(filteredItems.count)")
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundColor(StyleGuide.Colors.textSecondary)
                }
            }
            .standardCardStyle()

            ServiceAssignmentFilterBar(
                categoryOptions: categoryOptions,
                registrationGroupOptions: registrationGroupOptions,
                featureOptions: featureOptions,
                unitOptions: unitOptions,
                activeFilterChips: activeFilterChips,
                hasActiveFilters: hasActiveFilters,
                selectedCategory: $selectedCategory,
                selectedRegistrationGroup: $selectedRegistrationGroup,
                selectedQuoteFilter: $selectedQuoteFilter,
                selectedFeatures: $selectedFeatures,
                selectedUnits: $selectedUnits,
                selectedSortOption: $selectedSortOption,
                onFiltersChanged: updateFilteredItems,
                onClearAllFilters: clearAllFilters
            )
        }
        .padding(.bottom, StyleGuide.Dimensions.paddingLarge)
    }
    
    private var listContent: some View {
        ScrollView {
            LazyVStack(spacing: StyleGuide.Dimensions.paddingXSmall) {
                ForEach(filteredItems) { item in
                    ServiceAssignmentRowView(
                        item: item,
                        isSelected: selectedItemIDs.contains(item.id),
                        onToggle: {
                            if selectedItemIDs.contains(item.id) {
                                selectedItemIDs.remove(item.id)
                            } else {
                                selectedItemIDs.insert(item.id)
                            }
                        },
                        priceRangeDisplay: priceRangeDisplay(for: item)
                    )
                }
            }
        }
    }
    
    // Service Row replaced by ServiceAssignmentRowView
    
    @ViewBuilder
    private var emptyStateView: some View {
        EmptyStateView(
            icon: "list.bullet.clipboard",
            title: "No NDIS Items Found",
            message: "Try adjusting your search or filter criteria."
        )
    }
    
    @ViewBuilder
    private func priceRangeDisplay(for item: NDISItem) -> some View {
        if let regionalPrices = item.regionalPrices, !regionalPrices.isEmpty {
            let priceValues = regionalPrices.map { $0.amount }
            let minPrice = priceValues.min() ?? 0.0
            let maxPrice = priceValues.max() ?? 0.0

            VStack(alignment: .trailing, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                if minPrice == maxPrice {
                    Text(String(format: "$%.2f", minPrice)).fontWeight(.medium)
                } else {
                    Text(String(format: "$%.2f - $%.2f", minPrice, maxPrice)).fontWeight(.medium)
                }
                Text("/ \(item.unit ?? "")").font(StyleGuide.Typography.caption).foregroundColor(StyleGuide.Colors.textSecondary)
            }
        } else if let price = item.price, price > 0 {
            VStack(alignment: .trailing, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                Text(String(format: "$%.2f", price)).fontWeight(.medium)
                Text("/ \(item.unit ?? "")").font(StyleGuide.Typography.caption).foregroundColor(StyleGuide.Colors.textSecondary)
            }
        } else {
            VStack(alignment: .trailing, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                Text("No Price").font(StyleGuide.Typography.caption).fontWeight(.medium)
                Text("/ \(item.unit ?? "")").font(StyleGuide.Typography.caption).foregroundColor(StyleGuide.Colors.textSecondary)
            }
        }
    }
}

private extension ServiceAssignmentSheetView {
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
    
    var activeFilterChips: [ServiceAssignmentFilterChip] {
        var chips: [ServiceAssignmentFilterChip] = []
        
        if let selectedCategory {
            chips.append(
                ServiceAssignmentFilterChip(id: "category:\(selectedCategory)", label: "Category: \(selectedCategory)") {
                    self.selectedCategory = nil
                    self.updateFilteredItems()
                }
            )
        }
        
        if let selectedRegistrationGroup {
            chips.append(
                ServiceAssignmentFilterChip(id: "group:\(selectedRegistrationGroup)", label: "Group: \(selectedRegistrationGroup)") {
                    self.selectedRegistrationGroup = nil
                    self.updateFilteredItems()
                }
            )
        }
        
        if selectedQuoteFilter != .all {
            chips.append(
                ServiceAssignmentFilterChip(id: "quote:\(selectedQuoteFilter.rawValue)", label: selectedQuoteFilter.title.replacingOccurrences(of: "Pricing: ", with: "")) {
                    self.selectedQuoteFilter = .all
                    self.updateFilteredItems()
                }
            )
        }
        
        for feature in selectedFeatures.sorted() {
            chips.append(
                ServiceAssignmentFilterChip(id: "feature:\(feature)", label: "Feature: \(feature)") {
                    self.selectedFeatures.remove(feature)
                    self.updateFilteredItems()
                }
            )
        }
        
        for unit in selectedUnits.sorted() {
            chips.append(
                ServiceAssignmentFilterChip(id: "unit:\(unit)", label: "Unit: \(unit)") {
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
    
    func coreQuoteFilter(_ filter: ServiceAssignmentQuoteFilter) -> NDISCatalogueQuoteFilter {
        switch filter {
        case .all: return .all
        case .quoteRequired: return .quoteRequired
        case .noQuoteRequired: return .noQuoteRequired
        }
    }

    func coreSortOrder(_ option: ServiceAssignmentSortOption) -> NDISCatalogueSortOrder {
        switch option {
        case .defaultOrder, .nameAZ: return .nameAsc
        case .nameZA: return .nameDesc
        case .codeAZ: return .itemNumberAsc
        case .priceLowToHigh: return .priceAsc
        case .priceHighToLow: return .priceDesc
        }
    }

    func effectivePrice(for item: NDISItem) -> Double {
        if let regionalPrices = item.regionalPrices, !regionalPrices.isEmpty {
            return regionalPrices.map(\.amount).min() ?? item.price ?? .greatestFiniteMagnitude
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


private struct ServiceAssignmentRowView: View {
    let item: NDISItem
    let isSelected: Bool
    let onToggle: () -> Void
    let priceRangeDisplay: any View


    var body: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMediumLarge) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(StyleGuide.Typography.sectionTitle)
                .foregroundColor(isSelected ? .accentColor : StyleGuide.Colors.textSecondary.opacity(0.6))
                .frame(width: StyleGuide.Dimensions.selectionCheckmarkWidth)

            VStack(alignment: .leading) {
                Text(item.name)
                    .font(StyleGuide.Typography.itemTitle)
                    .fontWeight(.medium)
                    .foregroundColor(StyleGuide.Colors.text)
                Text(item.itemNumber)
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundColor(StyleGuide.Colors.textSecondary)
            }

            Spacer()

            AnyView(priceRangeDisplay)
        }
        .padding(.vertical, StyleGuide.Dimensions.paddingMediumLarge)
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
        .background(
            RoundedRectangle(cornerRadius: PanelShellTokens.panelCornerRadius)
                .fill(isSelected
                      ? Color.accentColor.opacity(StyleGuide.Opacity.faint)
                      : StyleGuide.Colors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: PanelShellTokens.panelCornerRadius)
                        .stroke(isSelected
                                ? Color.accentColor.opacity(StyleGuide.Opacity.strong + 0.1)
                                : StyleGuide.Colors.border,
                                lineWidth: 0.6)
                )
        )
        .animation(.spring(response: StyleGuide.Animations.springResponse, dampingFraction: StyleGuide.Animations.springDamping), value: isSelected)
        .contentShape(.rect(cornerRadius: PanelShellTokens.panelCornerRadius))
        .onTapGesture {
            onToggle()
        }
        .pointerStyle(.link)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), NDIS Code \(item.itemNumber), \(isSelected ? "Selected" : "Not selected")")
        .accessibilityHint("Double tap to toggle selection of this NDIS item")
    }
}
