import SwiftUI
import SwiftData
import Core
import PersistenceModels
import SharedUI


struct ServiceAssignmentSheetView: View {
    @Bindable private var viewModel: ServiceAssignmentViewModel
    let onProceed: ([NDISItem]) -> Void
    let alreadySelectedItems: [NDISItem]

    @Environment(\.dismiss) var dismiss

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
        viewModel: ServiceAssignmentViewModel,
        alreadySelectedItems: [NDISItem],
        onProceed: @escaping ([NDISItem]) -> Void
    ) {
        self._viewModel = Bindable(viewModel)
        self.onProceed = onProceed
        self.alreadySelectedItems = alreadySelectedItems
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Re-using the header from NDISCatalogueView
            header

            if viewModel.isLoadingItems {
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
        .task {
            await viewModel.loadCatalogue()
            updateFilteredItems()
        }
        .onChange(of: viewModel.availableNDISItems) { _, _ in
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
        .navigationTitle("Assign Services to \(viewModel.client.fullName)")
        .frame(
            minWidth: StyleGuide.Dimensions.sheetMinWidth,
            idealWidth: StyleGuide.Dimensions.sheetIdealWidth,
            minHeight: StyleGuide.Dimensions.sheetMinHeight,
            idealHeight: StyleGuide.Dimensions.sheetIdealHeight
        )
        
    }
    
    private func assignSelectedServices() {
        let selectedEntities = viewModel.availableNDISItems.filter { entity in
            selectedItemIDs.contains(entity.id)
        }
        onProceed(selectedEntities)
        dismiss()
    }

    private func updateFilteredItems() {
        let spec = catalogueQuerySpec
        let filteredSnapshots = NDISCatalogueQuery.filteredAndSortedItems(
            from: viewModel.availableNDISItems.map { $0.snapshot() },
            spec: spec
        )
        var items = filteredSnapshots.compactMap { snapshot in
            viewModel.availableNDISItems.first { $0.id == snapshot.id }
        }
        if selectedSortOption == .defaultOrder {
            let indexes = Dictionary(uniqueKeysWithValues: viewModel.availableNDISItems.enumerated().map { ($1.id, $0) })
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
                        .foregroundStyle(StyleGuide.Colors.text)
                }
                .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                .frame(maxWidth: 400)
                
                Spacer()
                
                if !filteredItems.isEmpty {
                    Text("\(selectedItemIDs.count) of \(filteredItems.count)")
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
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
                    Text(CurrencyFormatting.display(minPrice))
                        .font(StyleGuide.Typography.bodyMedium)
                } else {
                    Text("\(CurrencyFormatting.display(minPrice)) - \(CurrencyFormatting.display(maxPrice))")
                        .font(StyleGuide.Typography.bodyMedium)
                }
                Text("/ \(item.unit ?? "")").font(StyleGuide.Typography.caption).foregroundStyle(StyleGuide.Colors.textSecondary)
            }
        } else if let price = item.price, price > 0 {
            VStack(alignment: .trailing, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                Text(CurrencyFormatting.display(price))
                    .font(StyleGuide.Typography.bodyMedium)
                Text("/ \(item.unit ?? "")").font(StyleGuide.Typography.caption).foregroundStyle(StyleGuide.Colors.textSecondary)
            }
        } else {
            VStack(alignment: .trailing, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                Text("No Price")
                    .font(StyleGuide.Typography.caption)
                Text("/ \(item.unit ?? "")").font(StyleGuide.Typography.caption).foregroundStyle(StyleGuide.Colors.textSecondary)
            }
        }
    }
}

private extension ServiceAssignmentSheetView {
    var hasActiveFilters: Bool {
        !activeFilterChips.isEmpty
    }
    
    var categoryOptions: [String] {
        sortedUnique(viewModel.availableNDISItems.compactMap { normalizedText($0.category) })
    }
    
    var registrationGroupOptions: [String] {
        sortedUnique(viewModel.availableNDISItems.compactMap { normalizedText($0.registrationGroup) })
    }
    
    var unitOptions: [String] {
        sortedUnique(viewModel.availableNDISItems.compactMap { normalizedText($0.unit) })
    }
    
    var featureOptions: [String] {
        sortedUnique(viewModel.availableNDISItems.flatMap(parsedFeatures(from:)))
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
        Button(action: onToggle) {
            HStack(spacing: StyleGuide.Dimensions.paddingMediumLarge) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(StyleGuide.Typography.sectionTitle)
                    .foregroundStyle(isSelected ? Color.accentColor : StyleGuide.Colors.textSecondary.opacity(0.6))
                    .frame(width: StyleGuide.Dimensions.selectionCheckmarkWidth)

                VStack(alignment: .leading) {
                    Text(item.name)
                        .font(StyleGuide.Typography.itemTitle)
                        .foregroundStyle(StyleGuide.Colors.text)
                    Text(item.itemNumber)
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
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
            .contentShape(.rect(cornerRadius: PanelShellTokens.panelCornerRadius))
        }
        .buttonStyle(.plain)
        .animation(.spring(response: StyleGuide.Animations.springResponse, dampingFraction: StyleGuide.Animations.springDamping), value: isSelected)
        .pointerStyle(.link)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.name), NDIS Code \(item.itemNumber), \(isSelected ? "Selected" : "Not selected")")
        .accessibilityHint("Double tap to toggle selection of this NDIS item")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
