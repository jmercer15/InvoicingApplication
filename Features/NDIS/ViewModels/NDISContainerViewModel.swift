import SwiftUI
import Combine
import SwiftData // Change to SwiftData

class NDISContainerViewModel: ObservableObject {
    // MARK: - Dependencies
    private let modelContext: ModelContext // Change to ModelContext
    
    // MARK: - Published State for UI
    @Published var selectedItem: NDISItemEntity? = nil // Change to NDISItemEntity
    @Published var displayedItem: NDISItemEntity? = nil // Change to NDISItemEntity
    @Published var isTransitioningToBlack: Bool = false
    @Published var searchText: String = ""
    
    // Filtering State
    @Published var quoteFilter: QuoteFilter = .all
    @Published var currentSelectedFeatures: [String] = []
    @Published var featuresForToolbarMenu: [String] = []
    @Published var currentSelectedUnits: [String] = []
    @Published var unitsForToolbarMenu: [String] = []

    @Published var selectedCategoryId: String? = nil
    @Published var selectedRegistrationGroup: String? = nil
    @Published var showHistoricalItems: Bool = false
    @Published var itemVersionFilter: ItemVersionFilter = .currentOnly
    
    // Dynamic menu content
    @Published private(set) var registrationGroupsForMenu: [String] = []
    @Published private(set) var activeFilters: [ActiveFilter] = []

    // Sorting
    @Published var sortOrder: SortOrder = .nameAsc
    
    // Performance-Optimized Data Properties
    @Published private(set) var paginatedItems: [NDISItemEntity] = [] // Change to NDISItemEntity
    @Published private(set) var filteredItems: [NDISItemEntity] = [] // Change to NDISItemEntity
    
    // Internal Data Storage
    private var allSupportItems: [NDISItemEntity] = [] // Change to NDISItemEntity
    private var totalLoadedItems = 0

    // Caching
    @Published private(set) var cachedCategories: [String] = []
    @Published private(set) var cachedFeatures: [String] = []
    @Published private(set) var cachedRegistrationGroups: [String] = []
    @Published private(set) var cachedUnits: [String] = []

    @Published var selectedItemsCache: [UUID: NDISItemEntity] = [:] // Change to NDISItemEntity
    
    // Filter caching for performance
    private var cachedFilteredItems: [NDISItemEntity] = [] // Change to NDISItemEntity
    private var lastFilterParameters: (
        category: String?,
        group: String?,
        quote: QuoteFilter,
        features: [String],
        units: [String],
        search: String
    ) = (nil, nil, .all, [], [], "")
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Enums
    enum QuoteFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case quoteRequired = "Quote Req."
        case priceLimited = "Priced"
        var id: String { rawValue }
    }
    
    enum ItemVersionFilter: String, CaseIterable, Identifiable {
        case currentOnly = "Current Only"
        case historicalOnly = "Historical Only" 
        case all = "All Versions"
        
        var id: String { rawValue }
        var description: String { self.rawValue }
    }
    
    enum SortOrder: String, CaseIterable, Identifiable {
        case nameAsc = "Name (A-Z)"
        case nameDesc = "Name (Z-A)"
        case itemNumberAsc = "Item # (Asc)"
        case itemNumberDesc = "Item # (Desc)"
        case priceAsc = "Price (Low-High)"
        case priceDesc = "Price (High-Low)"
        case registrationGroupAsc = "Group (A-Z)"
        case registrationGroupDesc = "Group (Z-A)"
        var id: String { self.rawValue }
    }
    
    var sortDirection: SortDirection {
        switch sortOrder {
        case .nameAsc, .itemNumberAsc, .priceAsc, .registrationGroupAsc:
            return .ascending
        case .nameDesc, .itemNumberDesc, .priceDesc, .registrationGroupDesc:
            return .descending
        }
    }
    
    // MARK: - Dropdown/Filter Label Dictionaries
    var categoryLabels: [String: String] {
        Dictionary(uniqueKeysWithValues: cachedCategories.map { ($0, $0) })
    }
    var registrationGroupLabels: [String: String] {
        Dictionary(uniqueKeysWithValues: cachedRegistrationGroups.map { ($0, $0) })
    }
    var featureLabels: [String: String] {
        Dictionary(uniqueKeysWithValues: cachedFeatures.map { ($0, $0) })
    }
    var sortOptionLabels: [SortOrder: String] {
        Dictionary(uniqueKeysWithValues: SortOrder.allCases.map { ($0, $0.rawValue) })
    }
    
    // MARK: - Initializer
    init(context: ModelContext) { // Change context type
        self.modelContext = context
        setupDataProcessingPipeline()
        setupBindings()
        setupActiveFiltersPipeline()
        setupDynamicRegistrationGroupPipeline()
        
        // Observe changes to the ModelContext
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.fetchAndProcessAllItems() // Re-fetch and process all items on data change
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Private Methods
    
    private func setupDataProcessingPipeline() {
        // The previous implementation used MergeMany, which created a race condition.
        // The second attempt used a non-existent `CombineLatest8`.
        // The correct approach is to chain `CombineLatest` operators.
        
        let textSearchPublisher = $searchText.debounce(for: .milliseconds(300), scheduler: RunLoop.main)

        // Group the 8 publishers into two groups of 4.
        let group1 = Publishers.CombineLatest4(
            textSearchPublisher,
            $quoteFilter,
            $selectedCategoryId,
            $selectedRegistrationGroup
        )
        
        let group2 = Publishers.CombineLatest3(
            $sortOrder,
            $currentSelectedFeatures,
            $currentSelectedUnits
        )
        
        let group3 = $itemVersionFilter
        
        // Combine all groups.
        let filtersPublisher = Publishers.CombineLatest3(group1, group2, group3)
            .dropFirst() // Ignore the initial state on subscription.
            .eraseToAnyPublisher()

        filtersPublisher
            .map { [weak self] (group1, group2, versionFilter) -> AnyPublisher<[NDISItemEntity], Never> in // Change to NDISItemEntity
                // Destructure the tuples to get the individual filter values.
                let (searchText, quoteFilter, categoryId, groupId) = group1
                let (sortOrder, features, units) = group2
                
                guard let self = self else {
                    return Empty<[NDISItemEntity], Never>().eraseToAnyPublisher() // Change to NDISItemEntity
                }

                // Pass the explicit filter state to the background thread.
                return Just((searchText, quoteFilter, categoryId, groupId, sortOrder, features, units, versionFilter))
                    .receive(on: DispatchQueue.global(qos: .userInitiated))
                    .map { (searchText, quoteFilter, categoryId, groupId, sortOrder, features, units, versionFilter) -> [NDISItemEntity] in // Change to NDISItemEntity
                        // Call the pure function with the exact state.
                        return self.getFilteredAndSortedItems(
                            from: self.allSupportItems,
                            searchText: searchText,
                            quoteFilter: quoteFilter,
                            selectedCategoryId: categoryId,
                            selectedRegistrationGroup: groupId,
                            sortOrder: sortOrder,
                            currentSelectedFeatures: features,
                            currentSelectedUnits: units,
                            itemVersionFilter: versionFilter
                        )
                    }
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (processedItems) in
                guard let self = self else { return }
                self.filteredItems = processedItems
                self.totalLoadedItems = min(50, self.filteredItems.count)
                self.paginatedItems = self.getPaginatedItems(from: self.filteredItems)
                self.updateDynamicMenus(basedOn: processedItems)
            }
            .store(in: &cancellables)
    }

    private func setupBindings() {
        // Handle item selection changes with animations
        $selectedItem
            .dropFirst()
            .sink { [weak self] newValue in
                self?.handleItemSelectionChange(newValue)
            }
            .store(in: &cancellables)
    }
    
    private func setupActiveFiltersPipeline() {
        Publishers.CombineLatest(
            $selectedCategoryId.combineLatest($selectedRegistrationGroup, $quoteFilter),
            $currentSelectedFeatures.combineLatest($currentSelectedUnits)
        )
        .map { [weak self] (tuple1, tuple2) -> [ActiveFilter] in
            let (category, group, quote) = tuple1
            let (features, units) = tuple2
            
            guard let self = self else { return [] }
            var filters: [ActiveFilter] = []
            
            if let category = category {
                filters.append(ActiveFilter(type: .category, name: "Category: \(category)"))
            }
            if let group = group, group != "All" {
                filters.append(ActiveFilter(type: .group, name: "Group: \(group)"))
            }
            if quote != .all {
                filters.append(ActiveFilter(type: .quote, name: "Pricing: \(quote.rawValue)"))
            }
            features.forEach { feature in
                filters.append(ActiveFilter(type: .feature(feature), name: "Feature: \(feature)"))
            }
            units.forEach { unit in
                filters.append(ActiveFilter(type: .unit(unit), name: "Unit: \(self.displayString(forUnit: unit))"))
            }
            
            return filters
        }
        .receive(on: DispatchQueue.main)
        .assign(to: &$activeFilters)
    }
    
    private func setupDynamicRegistrationGroupPipeline() {
        $selectedCategoryId
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .map { [weak self] categoryId -> [String] in
                guard let self = self else { return [] }
                if let categoryId = categoryId {
                    // Filter groups by selected category
                    let itemsInCategory = self.allSupportItems.filter { ($0.category ?? "") == categoryId }
                    return ["All"] + Array(Set(itemsInCategory.map { ($0.registrationGroup ?? "").isEmpty ? "Unassigned" : ($0.registrationGroup ?? "") })).sorted()
                } else {
                    // Show all groups if no category is selected
                    return ["All"] + self.cachedRegistrationGroups
                }
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newGroups in
                self?.registrationGroupsForMenu = newGroups
                // Deselect group if it's no longer in the list of valid groups
                if let selected = self?.selectedRegistrationGroup, !newGroups.contains(selected) {
                    self?.selectedRegistrationGroup = nil
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Processing Entry Point
    
    // Updated to accept NDISItemEntity directly
    func setSourceItems(ndisItems: [NDISItemEntity]) {
        self.allSupportItems = ndisItems
        
        // After receiving, update caches and apply current filters.
        updateCachedData(from: self.allSupportItems)
        
        // Perform initial filtering and pagination on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            let processedItems = self.getFilteredAndSortedItems(from: self.allSupportItems)
            
            DispatchQueue.main.async {
                self.filteredItems = processedItems
                self.totalLoadedItems = min(50, self.filteredItems.count)
                self.paginatedItems = self.getPaginatedItems(from: self.filteredItems)
            }
        }
    }
    
    // New function to fetch all items from SwiftData
    func fetchAndProcessAllItems() {
        let descriptor = FetchDescriptor<NDISItemEntity>(sortBy: [
            SortDescriptor(\.itemNumber, order: .forward),
            SortDescriptor(\.effectiveStartDate, order: .reverse)
        ])
        do {
            let fetchedItems = try modelContext.fetch(descriptor)
            self.setSourceItems(ndisItems: fetchedItems)
        } catch {
            print("Failed to fetch NDIS items: \(error)")
        }
    }

    // MARK: - Filtering and Pagination Logic
    
    private func getPaginatedItems(from items: [NDISItemEntity]) -> [NDISItemEntity] {
        return Array(items.prefix(self.totalLoadedItems))
    }

    func loadMoreItems() {
        let remaining = filteredItems.count - totalLoadedItems
        let toLoad = min(50, remaining)
        totalLoadedItems += toLoad
        self.paginatedItems = getPaginatedItems(from: self.filteredItems)
    }

    func hasMoreItemsToLoad() -> Bool {
        return totalLoadedItems < filteredItems.count
    }
    
    // This function is now "pure", taking all its dependencies as parameters.
    // This makes it predictable and suitable for use in the reactive pipeline.
    private func getFilteredAndSortedItems(
        from items: [NDISItemEntity],
        searchText: String,
        quoteFilter: QuoteFilter,
        selectedCategoryId: String?,
        selectedRegistrationGroup: String?,
        sortOrder: SortOrder,
        currentSelectedFeatures: [String],
        currentSelectedUnits: [String],
        itemVersionFilter: ItemVersionFilter = .currentOnly
    ) -> [NDISItemEntity] {
        let lowercasedSearchText = searchText.lowercased()

        var result = items
        
        // Apply version filtering first
        switch itemVersionFilter {
        case .currentOnly:
            result = result.filter { $0.isCurrent }
            // Deduplicate - if multiple current versions exist, keep only the most recent
            result = deduplicateCurrentItems(result)
        case .historicalOnly:
            result = result.filter { !$0.isCurrent }
        case .all:
            break // No filtering
        }
        
        if let category = selectedCategoryId {
            result = result.filter { ($0.category ?? "") == category }
        }
        
        if let group = selectedRegistrationGroup, group != "All" {
            result = result.filter { ($0.registrationGroup ?? "") == group }
        }
        
        switch quoteFilter {
        case .quoteRequired:
            result = result.filter { $0.quoteRequired == true }
        case .priceLimited:
            result = result.filter { !($0.regionalPrices?.isEmpty ?? true) }
        case .all:
            break
        }
        
        if !lowercasedSearchText.isEmpty {
            result = result.filter { item in
                item.name.localizedCaseInsensitiveContains(lowercasedSearchText) ||
                item.itemNumber.localizedCaseInsensitiveContains(lowercasedSearchText) ||
                (item.itemDescription ?? "").localizedCaseInsensitiveContains(lowercasedSearchText)
            }
        }
        
        if !currentSelectedFeatures.isEmpty {
            result = result.filter { item in
                let featuresArray = (item.features ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                return currentSelectedFeatures.allSatisfy { selectedFeature in
                    featuresArray.contains { $0.localizedCaseInsensitiveContains(selectedFeature) }
                }
            }
        }
        
        if !currentSelectedUnits.isEmpty {
            result = result.filter { item in
                let unit = (item.unit ?? "")
                return currentSelectedUnits.contains { selectedUnit in
                    unit.localizedCaseInsensitiveCompare(selectedUnit) == .orderedSame
                }
            }
        }
        
        return getSortedItems(from: result, with: sortOrder)
    }

    // Overload for initial load and clearing filters, which use the view model's current state.
    private func getFilteredAndSortedItems(from items: [NDISItemEntity]) -> [NDISItemEntity] { // Change to NDISItemEntity
        return getFilteredAndSortedItems(
            from: items,
            searchText: self.searchText,
            quoteFilter: self.quoteFilter,
            selectedCategoryId: self.selectedCategoryId,
            selectedRegistrationGroup: self.selectedRegistrationGroup,
            sortOrder: self.sortOrder,
            currentSelectedFeatures: self.currentSelectedFeatures,
            currentSelectedUnits: self.currentSelectedUnits,
            itemVersionFilter: self.itemVersionFilter
        )
    }
    
    // This is now a dedicated sorting helper to avoid duplicating the logic.
    private func getSortedItems(from items: [NDISItemEntity], with sortOrder: SortOrder) -> [NDISItemEntity] { // Change to NDISItemEntity
        var sortedItems = items
        switch sortOrder {
        case .nameAsc:
            sortedItems = sortedItems.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        case .nameDesc:
            sortedItems = sortedItems.sorted { $0.name.localizedCompare($1.name) == .orderedDescending }
        case .priceAsc:
            sortedItems = sortedItems.sorted { (lhs: NDISItemEntity, rhs: NDISItemEntity) -> Bool in
                let price0 = lhs.regionalPrices?.map { $0.amount }.min() ?? Double.greatestFiniteMagnitude
                let price1 = rhs.regionalPrices?.map { $0.amount }.min() ?? Double.greatestFiniteMagnitude
                return price0 < price1
            }
        case .priceDesc:
            sortedItems = sortedItems.sorted { (lhs: NDISItemEntity, rhs: NDISItemEntity) -> Bool in
                let price0 = lhs.regionalPrices?.map { $0.amount }.max() ?? 0.0
                let price1 = rhs.regionalPrices?.map { $0.amount }.max() ?? 0.0
                return price0 > price1
            }
        case .itemNumberAsc:
            sortedItems = sortedItems.sorted { $0.itemNumber.localizedCompare($1.itemNumber) == .orderedAscending }
        case .itemNumberDesc:
            sortedItems = sortedItems.sorted { $0.itemNumber.localizedCompare($1.itemNumber) == .orderedDescending }
        case .registrationGroupAsc:
            sortedItems = sortedItems.sorted { ($0.registrationGroup ?? "").localizedCompare($1.registrationGroup ?? "") == .orderedAscending }
        case .registrationGroupDesc:
            sortedItems = sortedItems.sorted { ($0.registrationGroup ?? "").localizedCompare($1.registrationGroup ?? "") == .orderedDescending }
        }
        return sortedItems
    }
    
    // MARK: - Caching and Data Update Logic
    
    private func updateCachedData(from items: [NDISItemEntity]) { // Change to NDISItemEntity
        // This is an expensive operation, so we only want to do it when the source data changes
        // Using a background thread to not block the UI
        DispatchQueue.global(qos: .userInitiated).async {
            let categories = Array(Set(items.compactMap { $0.category })).sorted()
            let features = Array(Set(
                items
                    .compactMap { $0.features }
                    .flatMap { $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
            )).sorted()
            let regGroups = Array(Set(items.map { $0.registrationGroup ?? "" })).sorted()
            let units = Array(Set(items.map { $0.unit ?? "" })).sorted()
            
            DispatchQueue.main.async {
                self.cachedCategories = categories
                self.cachedFeatures = features
                self.cachedRegistrationGroups = regGroups
                self.cachedUnits = units
                
                self.featuresForToolbarMenu = self.getTopFeatures(from: items, count: 10)
                self.unitsForToolbarMenu = self.getTopUnits(from: items, count: 10)
            }
        }
    }
    
    private func updateDynamicMenus(basedOn items: [NDISItemEntity]) { // Change to NDISItemEntity
        // This can be computationally intensive, so dispatch to background
        DispatchQueue.global(qos: .userInteractive).async {
            let topFeatures = self.getTopFeatures(from: items, count: 10)
            let topUnits = self.getTopUnits(from: items, count: 10)
            
            DispatchQueue.main.async {
                self.featuresForToolbarMenu = topFeatures
                self.unitsForToolbarMenu = topUnits
            }
        }
    }
    
    func getTopFeatures(from items: [NDISItemEntity], count: Int) -> [String] { // Change to NDISItemEntity
        let allFeatures = items.flatMap { ($0.features ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        let featureCounts = allFeatures.reduce(into: [:]) { counts, feature in // Use non-optional features
            counts[feature, default: 0] += 1
        }
        
        let sortedFeatures = featureCounts.keys.sorted {
            (featureCounts[$0] ?? 0) > (featureCounts[$1] ?? 0)
        }
        
        return Array(sortedFeatures.prefix(count))
    }
    
    func getTopUnits(from items: [NDISItemEntity], count: Int) -> [String] { // Change to NDISItemEntity
        let allUnits = items.map { $0.unit ?? "" }.filter { !$0.isEmpty }
        let unitCounts = allUnits.reduce(into: [:]) { counts, unit in
            counts[unit, default: 0] += 1
        }
        
        let sortedUnits = unitCounts.keys.sorted { (unitCounts[$0] ?? 0) > (unitCounts[$1] ?? 0) }
        
        return Array(sortedUnits.prefix(count))
    }
    
    // MARK: - Deduplication Logic
    
    /// Removes duplicate items when multiple current versions exist for the same item number + name.
    /// Keeps only the version with the most recent effective start date.
    private func deduplicateCurrentItems(_ items: [NDISItemEntity]) -> [NDISItemEntity] { // Change to NDISItemEntity
        var itemsDict: [String: NDISItemEntity] = [:] // Change to NDISItemEntity
        
        for item in items {
            let compositeKey = "\(item.itemNumber)|\(item.name)"
            
            if let existingItem = itemsDict[compositeKey] {
                // Compare effective start dates - keep the more recent one
                let itemStartDate = item.effectiveStartDate ?? .distantPast
                let existingStartDate = existingItem.effectiveStartDate ?? .distantPast
                
                if itemStartDate > existingStartDate {
                    itemsDict[compositeKey] = item
                }
            } else {
                itemsDict[compositeKey] = item
            }
        }
        
        return Array(itemsDict.values)
    }
    
    // MARK: - Filter Management
    func toggleFeatureSelection(_ feature: String) {
        DispatchQueue.main.async {
            if self.currentSelectedFeatures.contains(feature) {
                self.currentSelectedFeatures.removeAll { $0 == feature }
            } else {
                self.currentSelectedFeatures.append(feature)
            }
        }
    }
    
    func toggleUnitSelection(_ unit: String) {
        DispatchQueue.main.async {
            if self.currentSelectedUnits.contains(unit) {
                self.currentSelectedUnits.removeAll { $0 == unit }
            } else {
                self.currentSelectedUnits.append(unit)
            }
        }
    }
    
    func clearAllFilters() {
        DispatchQueue.main.async {
            // Reset filter state properties
            self.quoteFilter = .all
            self.currentSelectedFeatures.removeAll()
            self.currentSelectedUnits.removeAll()
            self.selectedCategoryId = nil
            self.selectedRegistrationGroup = nil
            self.searchText = ""
            self.itemVersionFilter = .currentOnly

            // Manually and instantly update the UI state
            let sortedItems = self.getSortedItems(from: self.allSupportItems, with: self.sortOrder)
            self.filteredItems = sortedItems
            self.totalLoadedItems = min(50, sortedItems.count)
            self.paginatedItems = self.getPaginatedItems(from: sortedItems)

            // Reset dynamic menus and filter cache
            self.updateDynamicMenus(basedOn: self.allSupportItems)
            self.lastFilterParameters = (nil, nil, .all, [], [], "")
            self.cachedFilteredItems = []
            
            self.fetchAndProcessAllItems() // Trigger a re-fetch and process to ensure fresh data
        }
    }
    
    func removeFilter(_ filter: ActiveFilter) {
        switch filter.type {
        case .category:
            selectedCategoryId = nil
        case .group:
            selectedRegistrationGroup = nil
        case .quote:
            quoteFilter = .all
        case .feature(let name):
            currentSelectedFeatures.removeAll { $0 == name }
        case .unit(let name):
            currentSelectedUnits.removeAll { $0 == name }
        }
    }
    
    func clearFeatureFilters() {
        DispatchQueue.main.async {
            self.currentSelectedFeatures.removeAll()
        }
    }
    
    func clearUnitFilters() {
        DispatchQueue.main.async {
            self.currentSelectedUnits.removeAll()
        }
    }
    
    // MARK: - UI Helpers
    func displayString(forUnit unitCode: String) -> String {
        switch unitCode.lowercased() {
        case "e", "ea", "each": return "Each"
        case "h", "hr", "hour": return "Hour"
        case "d", "day", "dy": return "Day"
        case "wk", "week": return "Week"
        case "mon", "mth", "month": return "Month"
        case "qtr", "quarter": return "Quarter"
        case "ann", "yr", "year": return "Year"
        case "sess", "session": return "Session"
        case "km": return "Kilometre"
        case "item": return "Item"
        case "service": return "Service"
        default: return unitCode.capitalized
        }
    }
    
    func registrationGroups(for category: String, from allSupportItems: [NDISItemEntity]) -> [String] {
        let itemsInCategory = allSupportItems.filter { ($0.category ?? "") == category }
        return Set(itemsInCategory.map { ($0.registrationGroup ?? "").isEmpty ? "Unassigned" : ($0.registrationGroup ?? "") }).sorted()
    }
    
    func hasActiveFilters() -> Bool {
        return quoteFilter != .all || 
               !currentSelectedFeatures.isEmpty || 
               !currentSelectedUnits.isEmpty || 
               selectedCategoryId != nil ||
               selectedRegistrationGroup != nil
    }
    
    // MARK: - Private Helpers
    private func handleItemSelectionChange(_ newItem: NDISItemEntity?) {
        let oldItem = displayedItem
        
        if let oldItem = oldItem, let newItem = newItem, oldItem.id != newItem.id {
            // Case 1: Switching between two different items
            isTransitioningToBlack = true
            
            withAnimation(.easeInOut(duration: 0.1)) {
                displayedItem = nil
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.displayedItem = newItem
                
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.isTransitioningToBlack = false
                }
            }
        } else if newItem != nil && oldItem == nil {
            // Case 2: Selecting when nothing was selected
            isTransitioningToBlack = false
            withAnimation(.easeInOut(duration: 0.15)) {
                displayedItem = newItem
            }
        } else if newItem == nil && oldItem != nil {
            // Case 3: Deselecting (going to empty state)
            isTransitioningToBlack = false
            withAnimation(.easeInOut(duration: 0.1)) {
                displayedItem = nil
            }
        } else if newItem?.id == oldItem?.id {
            // Case 4: Same id but possibly updated object
            if displayedItem?.id != newItem?.id {
                isTransitioningToBlack = false
                withAnimation {
                    displayedItem = newItem
                }
            }
        } else {
            // Default case
            isTransitioningToBlack = false
            if displayedItem?.id != newItem?.id {
                withAnimation {
                    displayedItem = newItem
                }
            }
        }
    }
    
    private func areFilterParametersEqual(_ param1: (category: String?, group: String?, quote: QuoteFilter, features: [String], units: [String], search: String),
                                        _ param2: (category: String?, group: String?, quote: QuoteFilter, features: [String], units: [String], search: String)) -> Bool {
        return param1.category == param2.category &&
               param1.group == param2.group &&
               param1.quote == param2.quote &&
               param1.features == param2.features &&
               param1.units == param2.units &&
               param1.search == param2.search
    }
    
    func selectItem(for id: UUID) {
        if let newItem = findItem(by: id) {
            DispatchQueue.main.async {
                self.selectedItem = newItem
                self.selectedItemsCache[id] = newItem
            }
        }
    }
    
    func findItem(by id: UUID) -> NDISItemEntity? { // Change to NDISItemEntity
        if let cached = selectedItemsCache[id] {
            return cached
        }
        
        // If not in cache, try to fetch from context
        let descriptor = FetchDescriptor<NDISItemEntity>(predicate: #Predicate { $0.id == id })
        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            print("Error fetching NDIS item by ID: \(error)")
            return nil
        }
    }
    
    // MARK: - Supporting Types
    
    enum SortDirection {
        case ascending, descending
    }
    
    enum FilterType: Hashable {
        case category
        case group
        case quote
        case feature(String)
        case unit(String)
    }

    struct ActiveFilter: Identifiable, Hashable {
        let type: FilterType
        let name: String
        var id: String { name }
    }
} 
