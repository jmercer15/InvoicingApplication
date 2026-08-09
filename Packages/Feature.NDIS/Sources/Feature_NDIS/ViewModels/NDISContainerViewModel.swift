import SwiftUI
import SwiftData
import Core
import PersistenceModels
import DataInterfaces
import Observation

@Observable
@MainActor
public class NDISContainerViewModel {
    // MARK: - Dependencies
    let catalogueFetching: any NDISCatalogueFetching
    private let storeChangeMonitor: (any StoreChangeMonitoring)?
    
    // MARK: - Published State for UI
    public var selectedItemID: UUID? = nil
    public var searchText: String = "" {
        didSet { scheduleDataProcessing(debounceMilliseconds: 300) }
    }
    
    // Historical Analysis State
    public var changesSummary: NDISChangesSummary?
    public var itemChanges: [NDISItemChange] = []
    public var isAnalyzingChanges: Bool = false
    
    // Filtering State
    var quoteFilter: QuoteFilter = .all {
        didSet { scheduleDataProcessing() }
    }
    var currentSelectedFeatures: [String] = [] {
        didSet { scheduleDataProcessing() }
    }
    var featuresForToolbarMenu: [String] = []
    var currentSelectedUnits: [String] = [] {
        didSet { scheduleDataProcessing() }
    }
    var unitsForToolbarMenu: [String] = []

    var selectedCategoryId: String? = nil {
        didSet {
            updateRegistrationGroupsForSelectedCategory()
            scheduleDataProcessing()
        }
    }
    var selectedRegistrationGroup: String? = nil {
        didSet { scheduleDataProcessing() }
    }
    var showHistoricalItems: Bool = false
    var itemVersionFilter: ItemVersionFilter = .currentOnly {
        didSet { scheduleDataProcessing() }
    }
    
    // Dynamic menu content
    private(set) var registrationGroupsForMenu: [String] = []
    private(set) var activeFilters: [ActiveFilter] = []

    // Sorting
    var sortOrder: SortOrder = .nameAsc {
        didSet { scheduleDataProcessing() }
    }
    
    // Performance-Optimized Data Properties
    var catalogueProjection: NDISCatalogueProjection = .empty()
    @ObservationTracked public var hasLoadedCatalogue = false
    @ObservationTracked public var loadError: Error? = nil
    @ObservationTracked public var changesError: Error? = nil
    public var dataRevision: Int = 0
    
    // Internal Data Storage
    var allSupportItemIDs: [UUID] = []
    var supportItemSnapshotsByID: [UUID: NDISItemSnapshot] = [:]
    let projectionActor = NDISCatalogueProjectionActor()
    var activeProjectionRequestID: UUID?

    // Caching
    var cachedCategories: [String] = []
    var cachedFeatures: [String] = []
    var cachedRegistrationGroups: [String] = []
    var cachedUnits: [String] = []

    var preferredRegionIdentifier: String? = nil
    var hasResolvedPreferredRegion = false
    
    var catalogueLoadTask: Task<Void, Never>?
    var catalogueLoadRequestID: UUID?
    var processingTask: Task<Void, Never>?
    
    // MARK: - Catalogue Types
    typealias QuoteFilter = NDISCatalogueQuoteFilter
    typealias ItemVersionFilter = NDISCatalogueItemVersionFilter
    typealias SortOrder = NDISCatalogueSortOrder

    var catalogueQuerySpec: NDISCatalogueQuerySpec {
        NDISCatalogueQuerySpec(
            searchText: searchText,
            quoteFilter: quoteFilter,
            selectedCategoryId: selectedCategoryId,
            selectedRegistrationGroup: selectedRegistrationGroup,
            sortOrder: sortOrder,
            selectedFeatures: currentSelectedFeatures,
            selectedUnits: currentSelectedUnits,
            itemVersionFilter: itemVersionFilter
        )
    }

    var resolvedSelectedItem: NDISItemSnapshot? {
        guard let selectedItemID else { return nil }
        if let currentItem = catalogueProjection.itemLookup[selectedItemID] {
            return currentItem
        }
        return Self.resolveSelectedItem(
            selectedItemID: selectedItemID,
            from: allSupportItemSnapshots()
        )
    }
    
    // MARK: - Initializer
    public init(
        catalogueFetching: any NDISCatalogueFetching,
        storeChangeMonitor: (any StoreChangeMonitoring)? = nil
    ) {
        self.catalogueFetching = catalogueFetching
        self.storeChangeMonitor = storeChangeMonitor
        
        setupDataProcessingPipeline()
        setupDynamicRegistrationGroupPipeline()

        StoreChangeMonitoringSubscription.subscribe(monitor: storeChangeMonitor) { [weak self] revision in
            self?.dataRevision = revision
        }
    }
    
    public func loadCatalogueIfNeeded() {
        loadCatalogue(force: false)
    }

    public func loadCatalogue(force: Bool) {
        guard force || !hasLoadedCatalogue else { return }
        catalogueLoadTask?.cancel()
        let requestID = UUID()
        catalogueLoadRequestID = requestID
        let fetcher = catalogueFetching

        catalogueLoadTask = Task { [weak self] in
            do {
                let snapshots = try await fetcher.fetchNDISItemSnapshots()
                try Task.checkCancellation()
                guard let self, self.catalogueLoadRequestID == requestID else { return }
                await self.refreshItems(snapshots)
                guard self.catalogueLoadRequestID == requestID else { return }
                self.hasLoadedCatalogue = true
                self.loadError = nil
            } catch {
                guard !Task.isCancelled,
                      let self,
                      self.catalogueLoadRequestID == requestID else { return }
                self.loadError = error
            }
        }
    }

    isolated deinit {
        catalogueLoadTask?.cancel()
        processingTask?.cancel()
    }
    
    /// Inspector window / coordinator fallback when selection is driven by id before the catalogue column updates ``selectedItemID``.
    public func selectItemForInspectorFocus(id: UUID) {
        selectedItemID = id
    }

    /// Clears active item focus in inspector and catalogue detail columns.
    public func clearSelection() {
        selectedItemID = nil
    }

    // MARK: - Private Methods
    
    private func setupDataProcessingPipeline() {
        scheduleDataProcessing()
    }
    
    private func setupDynamicRegistrationGroupPipeline() {
        updateRegistrationGroupsForSelectedCategory()
    }

    func scheduleDataProcessing(debounceMilliseconds: UInt64 = 0) {
        guard hasLoadedCatalogue || !allSupportItemIDs.isEmpty else { return }
        let context = makeProcessingContext()
        _ = submitProjectionUpdate(context: context, debounceMilliseconds: debounceMilliseconds)
    }

    func submitProjectionUpdate(
        context: CatalogueProcessingContext,
        debounceMilliseconds: UInt64 = 0
    ) -> Task<Void, Never> {
        processingTask?.cancel()
        let actor = projectionActor
        let requestID = context.requestID
        activeProjectionRequestID = requestID

        let task = Task { [weak self] in
            do {
                if debounceMilliseconds > 0 {
                    try await Task.sleep(nanoseconds: debounceMilliseconds * 1_000_000)
                }
                try Task.checkCancellation()
                guard let self else { return }
                let processed = await actor.process(contract: context)
                try Task.checkCancellation()
                guard requestID == self.activeProjectionRequestID,
                      requestID == processed.requestID else { return }
                self.apply(processedState: processed.state)
            } catch {
                return
            }
        }

        processingTask = task
        return task
    }

    func updateRegistrationGroupsForSelectedCategory() {
        let newGroups = Self.registrationGroupsForMenu(
            selectedCategoryId: selectedCategoryId,
            items: allSupportItemSnapshots(),
            fallbackGroups: cachedRegistrationGroups
        )
        registrationGroupsForMenu = newGroups
        if let selectedRegistrationGroup, !newGroups.contains(selectedRegistrationGroup) {
            self.selectedRegistrationGroup = nil
        }
    }
    
    // MARK: - Filter Management
    
    public func toggleFeatureSelection(_ feature: String) {
        if currentSelectedFeatures.contains(feature) {
            currentSelectedFeatures.removeAll { $0 == feature }
        } else {
            currentSelectedFeatures.append(feature)
        }
    }
    
    public func clearAllFilters() {
        quoteFilter = .all
        currentSelectedFeatures.removeAll()
        currentSelectedUnits.removeAll()
        selectedCategoryId = nil
        selectedRegistrationGroup = nil
        searchText = ""
        itemVersionFilter = .currentOnly
    }
    
    public func clearFeatureFilters() {
        currentSelectedFeatures.removeAll()
    }
    


    // MARK: - Filtering and Pagination Logic

    func makeProcessingContext() -> CatalogueProcessingContext {
        makeProcessingContext(using: allSupportItemSnapshots())
    }
    
    func makeProcessingContext(using items: [NDISItemSnapshot]) -> CatalogueProcessingContext {
        CatalogueProcessingContext(
            requestID: UUID(),
            items: items,
            querySpec: catalogueQuerySpec,
            selectedItemID: selectedItemID,
            preferredRegionIdentifier: preferredRegionIdentifier
        )
    }
    
    func allSupportItems(from itemIDs: [UUID]) -> [NDISItemSnapshot] {
        guard !itemIDs.isEmpty else { return [] }
        
        let snapshotLookup = allSupportItemSnapshotsByID()
        let orderedItems = itemIDs.compactMap { snapshotLookup[$0] }
        return orderedItems.isEmpty ? Array(snapshotLookup.values) : orderedItems
    }
    
    func allSupportItemSnapshots() -> [NDISItemSnapshot] {
        allSupportItems(from: allSupportItemIDs)
    }
    
    func allSupportItemSnapshotsByID() -> [UUID: NDISItemSnapshot] {
        supportItemSnapshotsByID
    }

    func apply(processedState: ProcessedCatalogueState) {
        cachedCategories = processedState.caches.categories
        cachedFeatures = processedState.caches.features
        cachedRegistrationGroups = processedState.caches.registrationGroups
        cachedUnits = processedState.caches.units
        featuresForToolbarMenu = processedState.projection.featuresForToolbarMenu
        unitsForToolbarMenu = processedState.projection.unitsForToolbarMenu
        registrationGroupsForMenu = processedState.projection.registrationGroupsForMenu
        activeFilters = processedState.projection.activeFilters
        catalogueProjection = processedState.projection
    }

    static let stateToRegionMap: [String: String] = {
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

    static let regionAbbreviations: [String] = ["ACT", "NSW", "NT", "QLD", "SA", "TAS", "VIC", "WA"]

    static func regionIdentifier(for address: Address?) -> String? {
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

    nonisolated static func normalizeStateKey(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let scalars = trimmed.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        return String(String.UnicodeScalarView(scalars)).uppercased()
    }
}
 
