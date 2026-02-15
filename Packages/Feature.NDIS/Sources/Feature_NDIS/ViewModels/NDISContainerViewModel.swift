import SwiftUI
import Combine
import SwiftData
import Core
import Data
import Core

@MainActor
public class NDISContainerViewModel: ObservableObject {
    // MARK: - Dependencies
    private let unitOfWork: UnitOfWorkService
    
    // MARK: - Published State for UI
    @Published public var selectedItem: NDISItem? = nil
    @Published var displayedItem: NDISItem? = nil
    @Published var isTransitioningToBlack: Bool = false
    @Published var searchText: String = ""
    
    // Historical Analysis State
    @Published public var changesSummary: NDISChangesSummary?
    @Published public var itemChanges: [NDISItemChange] = []
    @Published public var isAnalyzingChanges: Bool = false
    
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
    @Published private(set) var paginatedItems: [NDISItem] = []
    @Published private(set) var filteredItems: [NDISItem] = []

    // Internal Data Storage
    private var allSupportItems: [NDISItem] = []
    private var totalLoadedItems = 0

    // Caching
    @Published private(set) var cachedCategories: [String] = []
    @Published private(set) var cachedFeatures: [String] = []
    @Published private(set) var cachedRegistrationGroups: [String] = []
    @Published private(set) var cachedUnits: [String] = []

    @Published var selectedItemsCache: [UUID: NDISItem] = [:]
    @Published private(set) var preferredRegionIdentifier: String? = nil

    // Filter caching for performance
    private var cachedFilteredItems: [NDISItem] = []
    private var lastFilterParameters: (
        category: String?,
        group: String?,
        quote: QuoteFilter,
        features: [String],
        units: [String],
        search: String
    ) = (nil, nil, .all, [], [], "")
    
    private var cancellables = Set<AnyCancellable>()
    private var processingTask: Task<Void, Never>?
    
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
    // Updated to use UnitOfWork service
    public init(unitOfWork: UnitOfWorkService) {
        self.unitOfWork = unitOfWork
        
        setupDataProcessingPipeline()
        setupBindings()
        setupActiveFiltersPipeline()
        setupDynamicRegistrationGroupPipeline()
        
        // Observe changes to the ModelContext via standard notification
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.fetchAndProcessAllItems() // Re-fetch and process all items on data change
                }
            }
            .store(in: &cancellables)

        Task { await fetchAndProcessAllItems() }
    }
    
    // Removed legacy context update support
    public func updateContextIfNeeded(_ newContext: ModelContext) {
        // No-op for UoW compatibility
    }
    
    // MARK: - Private Methods
    
    private func setupDataProcessingPipeline() {
        // The previous implementation used MergeMany, which created a race condition.
        // The second attempt used a non-existent `CombineLatest8`.
        // The correct approach is to chain `CombineLatest` operators.
        
        let textSearchPublisher = $searchText.debounce(for: .milliseconds(300), scheduler: RunLoop.main)

        // Group the 8 publishers into two groups of 4.
        let categoryPublisher = $selectedCategoryId.eraseToAnyPublisher()
        let groupPublisher = $selectedRegistrationGroup.eraseToAnyPublisher()
        
        let group1 = Publishers.CombineLatest4(
            textSearchPublisher,
            $quoteFilter,
            categoryPublisher,
            groupPublisher
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
            .sink { [weak self] (group1: (String, QuoteFilter, String?, String?), group2: (SortOrder, [String], [String]), versionFilter: ItemVersionFilter) in
                guard let self = self else { return }
                let (searchText, quoteFilter, categoryId, groupId) = group1
                let (sortOrder, features, units) = group2
                let currentItems = self.allSupportItems

                self.processingTask?.cancel()
                self.processingTask = Task { [currentItems, searchText, quoteFilter, categoryId, groupId, sortOrder, features, units, versionFilter] in
                    let processed = await Task.detached {
                        Self.getFilteredAndSortedItemsStatic(
                            from: currentItems,
                            searchText: searchText,
                            quoteFilter: quoteFilter,
                            selectedCategoryId: categoryId,
                            selectedRegistrationGroup: groupId,
                            sortOrder: sortOrder,
                            currentSelectedFeatures: features,
                            currentSelectedUnits: units,
                            itemVersionFilter: versionFilter
                        )
                    }.value
                    if Task.isCancelled { return }
                    let topFeatures = Self.getTopFeaturesStatic(from: processed, count: 10)
                    let topUnits = Self.getTopUnitsStatic(from: processed, count: 10)

                    self.filteredItems = processed
                    self.totalLoadedItems = min(50, self.filteredItems.count)
                    self.paginatedItems = self.getPaginatedItems(from: self.filteredItems)
                    self.featuresForToolbarMenu = topFeatures
                    self.unitsForToolbarMenu = topUnits
                }
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
            .receive(on: DispatchQueue.main) // Keep on main thread to avoid race conditions
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
    
    // Updated to accept NDISItem directly
    @MainActor
    func setSourceItems(ndisItems: [NDISItem]) {
        self.allSupportItems = ndisItems
        self.filteredItems = ndisItems
        self.totalLoadedItems = min(50, self.filteredItems.count)
        self.paginatedItems = self.getPaginatedItems(from: self.filteredItems)
        let currentFilters = (
            searchText: searchText,
            quoteFilter: quoteFilter,
            categoryId: selectedCategoryId,
            groupId: selectedRegistrationGroup,
            sortOrder: sortOrder,
            features: currentSelectedFeatures,
            units: currentSelectedUnits,
            versionFilter: itemVersionFilter
        )
        Task.detached { [weak self] in
            await self?.rebuildCachesAndFilters(from: ndisItems, filters: currentFilters)
        }
    }
    
    // New function to fetch all items from Repository
    @MainActor
    func fetchAndProcessAllItems() async {
        refreshBusinessRegionPreference()

        do {
            let items = try await unitOfWork.ndisItems.fetchAll()
            setSourceItems(ndisItems: items)
        } catch {
            print("Failed to fetch NDIS items via repository: \(error)")
        }
    }
    
    @MainActor
    public func fetchChangesSummary() async {
        isAnalyzingChanges = true
        defer { isAnalyzingChanges = false }
        
        do {
            let summary = try await NDISVersioningService.getChangesSummary(using: unitOfWork)
            self.changesSummary = summary
        } catch {
            print("Error fetching changes summary: \(error)")
        }
    }
    
    @MainActor
    public func loadItemHistory(for itemNumber: String) async {
        isAnalyzingChanges = true
        defer { isAnalyzingChanges = false }
        
        do {
            let changes = try await NDISVersioningService.analyzeItemChanges(itemNumber: itemNumber, using: unitOfWork)
            self.itemChanges = changes
        } catch {
            print("Error loading item history for \(itemNumber): \(error)")
        }
    }

    // MARK: - Filtering and Pagination Logic

    @MainActor
    private func refreshBusinessRegionPreference() {
        Task {
            do {
                if let business = try await unitOfWork.business.fetchFirst() {
                    self.preferredRegionIdentifier = Self.regionIdentifier(for: business.address)
                } else {
                    self.preferredRegionIdentifier = nil
                }
            } catch {
                print("Failed to fetch business for region preference: \(error)")
                self.preferredRegionIdentifier = nil
            }
        }
    }

    private nonisolated func rebuildCachesAndFilters(
        from items: [NDISItem],
        filters: (
            searchText: String,
            quoteFilter: QuoteFilter,
            categoryId: String?,
            groupId: String?,
            sortOrder: SortOrder,
            features: [String],
            units: [String],
            versionFilter: ItemVersionFilter
        )
    ) async {
        let caches = Self.buildCaches(from: items)
        let processed = Self.getFilteredAndSortedItemsStatic(
            from: items,
            searchText: filters.searchText,
            quoteFilter: filters.quoteFilter,
            selectedCategoryId: filters.categoryId,
            selectedRegistrationGroup: filters.groupId,
            sortOrder: filters.sortOrder,
            currentSelectedFeatures: filters.features,
            currentSelectedUnits: filters.units,
            itemVersionFilter: filters.versionFilter
        )
        await MainActor.run {
            cachedCategories = caches.categories
            cachedFeatures = caches.features
            cachedRegistrationGroups = caches.registrationGroups
            cachedUnits = caches.units
            featuresForToolbarMenu = caches.topFeatures
            unitsForToolbarMenu = caches.topUnits
            filteredItems = processed
            totalLoadedItems = min(50, filteredItems.count)
            paginatedItems = getPaginatedItems(from: filteredItems)
        }
    }

    private static let stateToRegionMap: [String: String] = {
        var mapping: [String: String] = [:]

        func register(_ raw: String, as region: String) {
            let normalized = normalizeStateKey(raw)
            guard !normalized.isEmpty else { return }
            mapping[normalized] = region
        }

        let pairs: [(String, String)] = [
            ("ACT", "ACT"),
            ("Australian Capital Territory", "ACT"),
            ("NSW", "NSW"),
            ("New South Wales", "NSW"),
            ("N.S.W.", "NSW"),
            ("QLD", "QLD"),
            ("Queensland", "QLD"),
            ("VIC", "VIC"),
            ("Victoria", "VIC"),
            ("TAS", "TAS"),
            ("Tasmania", "TAS"),
            ("SA", "SA"),
            ("South Australia", "SA"),
            ("WA", "WA"),
            ("Western Australia", "WA"),
            ("NT", "NT"),
            ("Northern Territory", "NT")
        ]

        pairs.forEach { register($0.0, as: $0.1) }

        return mapping
    }()

    private static let regionAbbreviations: [String] = ["ACT", "NSW", "NT", "QLD", "SA", "TAS", "VIC", "WA"]

    private static func regionIdentifier(for address: Address?) -> String? {
        guard let address = address else { return nil }
        let normalizedState = normalizeStateKey(address.state)
        guard !normalizedState.isEmpty else { return nil }

        if let mapped = stateToRegionMap[normalizedState] {
            return mapped
        }

        if let abbreviation = regionAbbreviations.first(where: { normalizedState.contains($0) }) {
            return abbreviation
        }

        return nil
    }

    private nonisolated static func normalizeStateKey(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let scalars = trimmed.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        return String(String.UnicodeScalarView(scalars)).uppercased()
    }

    nonisolated private static func applyVersionFilterStatic(_ items: [NDISItem], versionFilter: ItemVersionFilter) -> [NDISItem] {
        let now = Date()

        switch versionFilter {
        case .currentOnly:
            let currentItems = items.filter { item in
                let start = item.effectiveStartDate ?? .distantPast
                let end = item.effectiveEndDate ?? .distantFuture
                let isEffectiveNow = (start <= now && now <= end)
                return item.isCurrent || isEffectiveNow
            }
            return deduplicateCurrentItemsStatic(currentItems)

        case .historicalOnly:
            return items.filter { item in
                let end = item.effectiveEndDate ?? .distantPast
                if !item.isCurrent { return true }
                return end < now
            }

        case .all:
            return items
        }
    }

    private func getPaginatedItems(from items: [NDISItem]) -> [NDISItem] {
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
        from items: [NDISItem],
        searchText: String,
        quoteFilter: QuoteFilter,
        selectedCategoryId: String?,
        selectedRegistrationGroup: String?,
        sortOrder: SortOrder,
        currentSelectedFeatures: [String],
        currentSelectedUnits: [String],
        itemVersionFilter: ItemVersionFilter = .currentOnly
    ) -> [NDISItem] {
        Self.getFilteredAndSortedItemsStatic(
            from: items,
            searchText: searchText,
            quoteFilter: quoteFilter,
            selectedCategoryId: selectedCategoryId,
            selectedRegistrationGroup: selectedRegistrationGroup,
            sortOrder: sortOrder,
            currentSelectedFeatures: currentSelectedFeatures,
            currentSelectedUnits: currentSelectedUnits,
            itemVersionFilter: itemVersionFilter
        )
    }

    // Version of filtering that runs on background thread (no version filtering)
    nonisolated private static func getFilteredAndSortedItemsStatic(
        from items: [NDISItem],
        searchText: String,
        quoteFilter: QuoteFilter,
        selectedCategoryId: String?,
        selectedRegistrationGroup: String?,
        sortOrder: SortOrder,
        currentSelectedFeatures: [String],
        currentSelectedUnits: [String],
        itemVersionFilter: ItemVersionFilter = .currentOnly
    ) -> [NDISItem] {
        let versionFilteredItems = applyVersionFilterStatic(items, versionFilter: itemVersionFilter)
        return getFilteredAndSortedItemsWithoutVersionFilterStatic(
            from: versionFilteredItems,
            searchText: searchText,
            quoteFilter: quoteFilter,
            selectedCategoryId: selectedCategoryId,
            selectedRegistrationGroup: selectedRegistrationGroup,
            sortOrder: sortOrder,
            currentSelectedFeatures: currentSelectedFeatures,
            currentSelectedUnits: currentSelectedUnits
        )
    }

    nonisolated private static func getFilteredAndSortedItemsWithoutVersionFilterStatic(
        from items: [NDISItem],
        searchText: String,
        quoteFilter: QuoteFilter,
        selectedCategoryId: String?,
        selectedRegistrationGroup: String?,
        sortOrder: SortOrder,
        currentSelectedFeatures: [String],
        currentSelectedUnits: [String]
    ) -> [NDISItem] {
        let lowercasedSearchText = searchText.lowercased()

        var result = items

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
            result = result.filter { !$0.regionalPrices.isEmpty }
        case .all:
            break
        }

        if !lowercasedSearchText.isEmpty {
            result = result.filter { item in
                item.name.localizedCaseInsensitiveContains(lowercasedSearchText) ||
                item.itemNumber.localizedCaseInsensitiveContains(lowercasedSearchText) ||
                (item.description ?? "").localizedCaseInsensitiveContains(lowercasedSearchText)
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
    private func getFilteredAndSortedItems(from items: [NDISItem]) -> [NDISItem] {
        return Self.getFilteredAndSortedItemsStatic(
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
    nonisolated private static func getSortedItems(from items: [NDISItem], with sortOrder: SortOrder) -> [NDISItem] {
        guard items.count > 1 else { return items }

        switch sortOrder {
        case .nameAsc:
            return items.sorted { lhs, rhs in
                compareNames(lhs, rhs, ascending: true)
            }
        case .nameDesc:
            return items.sorted { lhs, rhs in
                compareNames(lhs, rhs, ascending: false)
            }
        case .itemNumberAsc:
            return items.sorted { lhs, rhs in
                compareItemNumbers(lhs, rhs, ascending: true)
            }
        case .itemNumberDesc:
            return items.sorted { lhs, rhs in
                compareItemNumbers(lhs, rhs, ascending: false)
            }
        case .priceAsc:
            return items.sorted { lhs, rhs in
                comparePrices(lhs, rhs, ascending: true)
            }
        case .priceDesc:
            return items.sorted { lhs, rhs in
                comparePrices(lhs, rhs, ascending: false)
            }
        case .registrationGroupAsc:
            return items.sorted { lhs, rhs in
                compareRegistrationGroups(lhs, rhs, ascending: true)
            }
        case .registrationGroupDesc:
            return items.sorted { lhs, rhs in
                compareRegistrationGroups(lhs, rhs, ascending: false)
            }
        }
    }

    nonisolated private static func compareNames(_ lhs: NDISItem, _ rhs: NDISItem, ascending: Bool) -> Bool {
        let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if comparison == .orderedSame {
            return tieBreak(lhs: lhs, rhs: rhs, ascending: ascending)
        }
        return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
    }

    nonisolated private static func compareItemNumbers(_ lhs: NDISItem, _ rhs: NDISItem, ascending: Bool) -> Bool {
        let comparison = lhs.itemNumber.localizedStandardCompare(rhs.itemNumber)
        if comparison == .orderedSame {
            return compareNames(lhs, rhs, ascending: ascending)
        }
        return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
    }

    nonisolated private static func compareRegistrationGroups(_ lhs: NDISItem, _ rhs: NDISItem, ascending: Bool) -> Bool {
        let lhsGroup = normalizedOptional(lhs.registrationGroup)
        let rhsGroup = normalizedOptional(rhs.registrationGroup)

        switch (lhsGroup, rhsGroup) {
        case let (l?, r?):
            let comparison = l.localizedCaseInsensitiveCompare(r)
            if comparison == .orderedSame {
                return tieBreak(lhs: lhs, rhs: rhs, ascending: ascending)
            }
            return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
        case (nil, nil):
            return tieBreak(lhs: lhs, rhs: rhs, ascending: ascending)
        case (nil, _?):
            return !ascending
        case (_?, nil):
            return ascending
        }
    }

    nonisolated private static func comparePrices(_ lhs: NDISItem, _ rhs: NDISItem, ascending: Bool) -> Bool {
        let lhsPrice = primaryPrice(for: lhs)
        let rhsPrice = primaryPrice(for: rhs)

        switch (lhsPrice, rhsPrice) {
        case let (l?, r?):
            if l == r {
                return tieBreak(lhs: lhs, rhs: rhs, ascending: ascending)
            }
            return ascending ? l < r : l > r
        case (nil, nil):
            return tieBreak(lhs: lhs, rhs: rhs, ascending: ascending)
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        }
    }

    nonisolated private static func tieBreak(lhs: NDISItem, rhs: NDISItem, ascending: Bool) -> Bool {
        let numberComparison = lhs.itemNumber.localizedStandardCompare(rhs.itemNumber)
        if numberComparison != .orderedSame {
            return ascending ? numberComparison == .orderedAscending : numberComparison == .orderedDescending
        }

        return ascending
            ? lhs.id.uuidString < rhs.id.uuidString
            : lhs.id.uuidString > rhs.id.uuidString
    }

    nonisolated private static func normalizedOptional(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    nonisolated private static func primaryPrice(for item: NDISItem) -> Double? {
        if let nationalPrice = item.regionalPrices.first(where: { ($0.regionIdentifier ?? "").caseInsensitiveCompare("NATIONAL") == .orderedSame })?.amount {
            return nationalPrice
        }
        return item.regionalPrices.map { $0.amount }.min()
    }
    
    // MARK: - Caching and Data Update Logic
    
    nonisolated private static func buildCaches(from items: [NDISItem]) -> (categories: [String], features: [String], registrationGroups: [String], units: [String], topFeatures: [String], topUnits: [String]) {
        let categories = Array(Set(items.compactMap { $0.category })).sorted()
        let features = Array(Set(
            items
                .compactMap { $0.features }
                .flatMap { $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        )).sorted()
        let regGroups = Array(Set(items.map { $0.registrationGroup ?? "" })).sorted()
        let units = Array(Set(items.map { $0.unit ?? "" })).sorted()
        let topFeatures = Self.getTopFeaturesStatic(from: items, count: 10)
        let topUnits = Self.getTopUnitsStatic(from: items, count: 10)
        return (categories, features, regGroups, units, topFeatures, topUnits)
    }
    
    private func updateDynamicMenus(basedOn items: [NDISItem]) {
        let topFeatures = Self.getTopFeaturesStatic(from: items, count: 10)
        let topUnits = Self.getTopUnitsStatic(from: items, count: 10)
        featuresForToolbarMenu = topFeatures
        unitsForToolbarMenu = topUnits
    }
    
    nonisolated private static func getTopFeaturesStatic(from items: [NDISItem], count: Int) -> [String] {
        let allFeatures = items.flatMap { ($0.features ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        let featureCounts = allFeatures.reduce(into: [:]) { counts, feature in // Use non-optional features
            counts[feature, default: 0] += 1
        }
        
        let sortedFeatures = featureCounts.keys.sorted {
            (featureCounts[$0] ?? 0) > (featureCounts[$1] ?? 0)
        }
        
        return Array(sortedFeatures.prefix(count))
    }
    
    nonisolated private static func getTopUnitsStatic(from items: [NDISItem], count: Int) -> [String] {
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
    nonisolated private static func deduplicateCurrentItemsStatic(_ items: [NDISItem]) -> [NDISItem] {
        var itemsDict: [String: NDISItem] = [:]
        
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
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
            let sortedItems = Self.getSortedItems(from: self.allSupportItems, with: self.sortOrder)
            self.filteredItems = sortedItems
            self.totalLoadedItems = min(50, sortedItems.count)
            self.paginatedItems = self.getPaginatedItems(from: sortedItems)

            // Reset dynamic menus and filter cache
            self.updateDynamicMenus(basedOn: self.allSupportItems)
            self.lastFilterParameters = (nil, nil, .all, [], [], "")
            self.cachedFilteredItems = []
            
            Task { await self.fetchAndProcessAllItems() } // Trigger a re-fetch and process to ensure fresh data
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
    private func handleItemSelectionChange(_ newItem: NDISItem?) {
        let oldItem = displayedItem
        
        if let oldItem = oldItem, let newItem = newItem, oldItem.id != newItem.id {
            // Case 1: Switching between two different items
            isTransitioningToBlack = true
            
            withAnimation(.easeInOut(duration: 0.1)) {
                displayedItem = nil
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
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
    
    func findItem(by id: UUID) -> NDISItem? {
        if let cached = selectedItemsCache[id] {
            return cached
        }
        
        if let memoryItem = allSupportItems.first(where: { $0.id == id }) {
            return memoryItem
        }
        
        // If not in memory, we assume it's not available in the current context or unloaded.
        // Since we load all items, this should be rare.
        return nil
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
