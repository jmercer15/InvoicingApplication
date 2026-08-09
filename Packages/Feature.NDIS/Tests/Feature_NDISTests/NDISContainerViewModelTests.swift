import Core
import DataInterfaces
import Foundation
import PersistenceModels
import Testing
import SwiftData
@testable import Feature_NDIS

@MainActor
@Suite struct NDISContainerViewModelTests {
    @Test func UpdateSourceItemsBuildsProjectionOnce() async {
        let context = try! makeInMemoryContext()
        insertSampleItems(into: context)
        let viewModel = makeViewModel(modelContext: context)
        let sourceItems = try! context.fetch(FetchDescriptor<NDISItem>())

        await viewModel.refreshItems(sourceItems.map { $0.snapshot() })

        #expect(viewModel.catalogueProjection.totalItemCount == 3)
        #expect(viewModel.catalogueProjection.filteredItems.count == 3)
        #expect(viewModel.catalogueProjection.categories == ["Capacity Building", "Core"])

        await viewModel.refreshItems(sourceItems.map { $0.snapshot() })
        #expect(viewModel.catalogueProjection.totalItemCount == 3)
    }

    @Test func SearchAndCategoryFiltersReuseCachedItems() async {
        let context = try! makeInMemoryContext()
        insertSampleItems(into: context)
        let viewModel = makeViewModel(modelContext: context)
        let sourceItems = try! context.fetch(FetchDescriptor<NDISItem>())

        await viewModel.refreshItems(sourceItems.map { $0.snapshot() })
        viewModel.searchText = "setup"

        await assertEventually("search should narrow the cached projection") {
            viewModel.catalogueProjection.filteredItems.map(\.itemNumber) == ["15_001"]
        }

        viewModel.searchText = ""
        viewModel.selectedCategoryId = "Capacity Building"

        await assertEventually("category filtering should rebuild from cached items") {
            viewModel.catalogueProjection.filteredItems.count == 2
                && viewModel.catalogueProjection.registrationGroupsForMenu == ["All", "TAS"]
        }
    }

    @Test func SelectionResolvesImmediatelyAgainstCachedItems() async {
        let context = try! makeInMemoryContext()
        insertSampleItems(into: context)
        let viewModel = makeViewModel(modelContext: context)
        let sourceItems = try! context.fetch(FetchDescriptor<NDISItem>())

        await viewModel.refreshItems(sourceItems.map { $0.snapshot() })

        viewModel.selectedItemID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")

        #expect(viewModel.resolvedSelectedItem?.itemNumber == "15_001")
        #expect(viewModel.resolvedSelectedItem?.name == "Plan Management Setup")
    }

    @Test func LoadCatalogueStateChanges() async {
        let context = try! makeInMemoryContext()
        let viewModel = makeViewModel(modelContext: context)

        #expect(!(viewModel.hasLoadedCatalogue))
        #expect(viewModel.loadError == nil)

        viewModel.loadCatalogue(force: true)
        
        await assertEventually("hasLoadedCatalogue becomes true") {
            viewModel.hasLoadedCatalogue == true
        }
        #expect(viewModel.loadError == nil)
    }

    @Test func RegionIdentifierMappingAndPreferredRegion() async {
        let context = try! makeInMemoryContext()
        let viewModel = makeViewModel(modelContext: context)
        
        // Test nil business
        viewModel.refreshPreferredRegion(using: nil)
        #expect(viewModel.hasResolvedPreferredRegion)
        #expect(viewModel.preferredRegionIdentifier == nil)
        
        // Test unknown state
        let address1 = Address()
        address1.state = "UnknownState"
        let business1 = Business(abn: "123")
        business1.address = address1
        viewModel.refreshPreferredRegion(using: business1)
        #expect(viewModel.preferredRegionIdentifier == nil)
        
        // Test various representations of NSW
        for state in ["NSW", "New South Wales", "N.S.W.", "nsw", "  N.S.W.  "] {
            let address = Address()
            address.state = state
            let business = Business(abn: "123")
            business.address = address
            viewModel.refreshPreferredRegion(using: business)
            #expect(viewModel.preferredRegionIdentifier == "NSW", "Should resolve \(state) to NSW")
        }
        
        // Test abbreviation matching fallback
        let addressACT = Address()
        addressACT.state = "ACT (Canberra)"
        let businessACT = Business(abn: "123")
        businessACT.address = addressACT
        viewModel.refreshPreferredRegion(using: businessACT)
        #expect(viewModel.preferredRegionIdentifier == "ACT")
    }

    @Test func LoadCatalogueConcurrentlyDoesNotCrash() async {
        let context = try! makeInMemoryContext()
        insertSampleItems(into: context)
        let viewModel = makeViewModel(modelContext: context)

        for _ in 0..<10 {
            viewModel.loadCatalogue(force: true)
        }

        await assertEventually("hasLoadedCatalogue becomes true") {
            viewModel.hasLoadedCatalogue == true
        }

        await assertEventually("catalogue projection loads three items") {
            viewModel.catalogueProjection.totalItemCount == 3
        }
    }

    @Test func LoadCatalogueIgnoresStaleCompletion() async {
        let fetcher = SequencedCatalogueFetcher()
        let viewModel = NDISContainerViewModel(catalogueFetching: fetcher)
        let oldItem = makeSnapshot(id: 1, itemNumber: "01_OLD", name: "Old Catalogue")
        let newItem = makeSnapshot(id: 2, itemNumber: "01_NEW", name: "New Catalogue")

        viewModel.loadCatalogue(force: true)
        await assertEventually("first load is pending") {
            fetcher.pendingCallCount == 1
        }

        viewModel.loadCatalogue(force: true)
        await assertEventually("second load is pending") {
            fetcher.pendingCallCount == 2
        }

        fetcher.completeCall(at: 1, with: [newItem])
        await assertEventually("newer load wins") {
            viewModel.catalogueProjection.filteredItems.map(\.itemNumber) == ["01_NEW"]
        }

        fetcher.completeCall(at: 0, with: [oldItem])
        _ = await Task.waitUnlessCancelled(for: .milliseconds(100))

        #expect(viewModel.catalogueProjection.filteredItems.map(\.itemNumber) == ["01_NEW"])
        #expect(viewModel.loadError == nil)
    }

    @Test func FetchChangesSummarySuccess() async {
        let context = try! makeInMemoryContext()
        insertSampleItems(into: context)
        let viewModel = makeViewModel(modelContext: context)

        await viewModel.fetchChangesSummary()
        #expect(!(viewModel.isAnalyzingChanges))
        #expect(viewModel.changesSummary != nil)
        #expect(viewModel.changesError == nil)
        #expect(viewModel.changesSummary?.totalUniqueItems == 3)
    }

    @Test func LoadItemHistoryDoesNotCrashWithAtLeastOneVersion() async {
        let context = try! makeInMemoryContext()
        insertSampleItems(into: context)
        let viewModel = makeViewModel(modelContext: context)

        #expect(!(viewModel.isAnalyzingChanges))
        #expect(viewModel.itemChanges.isEmpty)

        await viewModel.loadItemHistory(for: "15_001")

        #expect(!(viewModel.isAnalyzingChanges))
        #expect(viewModel.itemChanges.isEmpty)
    }

    @Test func ClearAllFiltersResetsState() async {
        let context = try! makeInMemoryContext()
        let viewModel = makeViewModel(modelContext: context)

        viewModel.quoteFilter = .quoteRequired
        viewModel.currentSelectedFeatures = ["test"]
        viewModel.currentSelectedUnits = ["hour"]
        viewModel.selectedCategoryId = "Core"
        viewModel.selectedRegistrationGroup = "Group"
        viewModel.searchText = "findme"
        viewModel.itemVersionFilter = .all

        viewModel.clearAllFilters()

        #expect(viewModel.quoteFilter == .all)
        #expect(viewModel.currentSelectedFeatures.isEmpty)
        #expect(viewModel.currentSelectedUnits.isEmpty)
        #expect(viewModel.selectedCategoryId == nil)
        #expect(viewModel.selectedRegistrationGroup == nil)
        #expect(viewModel.searchText == "")
        #expect(viewModel.itemVersionFilter == .currentOnly)
    }

    private func makeViewModel(modelContext: ModelContext) -> NDISContainerViewModel {
        NDISContainerViewModel(catalogueFetching: TestCatalogueFetcher(context: modelContext))
    }

    private func makeInMemoryContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: NDISItem.self,
            RegionalPrice.self,
            Business.self,
            Address.self,
            configurations: config
        )
        return ModelContext(container)
    }

    private func insertSampleItems(into context: ModelContext) {
        let item1 = NDISItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            itemNumber: "01_001",
            name: "Assistance with Daily Life",
            versionIdentifier: "v1",
            category: "Core",
            itemDescription: "Daily living support",
            unit: "Hour"
        )
        item1.registrationGroup = "NSW/ACT"
        item1.quoteRequired = false
        let price1 = RegionalPrice()
        price1.regionIdentifier = "NATIONAL"
        price1.amount = 75
        item1.regionalPrices = [price1]

        let item2 = NDISItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            itemNumber: "15_001",
            name: "Plan Management Setup",
            versionIdentifier: "v1",
            category: "Capacity Building",
            itemDescription: "One-time plan setup",
            unit: "Each"
        )
        item2.registrationGroup = "TAS"
        item2.quoteRequired = true
        item2.features = "plan,setup"
        let price2 = RegionalPrice()
        price2.regionIdentifier = "NATIONAL"
        price2.amount = 100
        item2.regionalPrices = [price2]

        let item3 = NDISItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            itemNumber: "15_002",
            name: "Plan Management Monthly",
            versionIdentifier: "v1",
            category: "Capacity Building",
            itemDescription: "Monthly plan oversight",
            unit: "Month"
        )
        item3.registrationGroup = "TAS"
        item3.quoteRequired = false
        item3.features = "plan,monthly"
        let price3 = RegionalPrice()
        price3.regionIdentifier = "NATIONAL"
        price3.amount = 125
        item3.regionalPrices = [price3]

        context.insert(item1)
        context.insert(item2)
        context.insert(item3)
        try? context.save()
    }

    private func makeSnapshot(id: Int, itemNumber: String, name: String) -> NDISItemSnapshot {
        NDISItemSnapshot(
            id: UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", id))")!,
            itemNumber: itemNumber,
            name: name,
            versionIdentifier: "v1",
            isCurrent: true,
            category: "Core",
            effectiveStartDate: nil,
            effectiveEndDate: nil,
            features: nil,
            itemDescription: nil,
            ndiaRequestedReports: false,
            nonFaceToFaceProvision: false,
            providerTravel: false,
            quoteRequired: false,
            registrationGroup: nil,
            registrationGroupNumber: nil,
            shortNoticeCancellations: false,
            irregularSILSupports: false,
            status: "Active",
            type: "Standard",
            unit: "Hour",
            regionalPrices: [],
            price: nil,
            effectiveDateRange: ""
        )
    }

    private func assertEventually(
        _ description: String,
        pollInterval: Duration = .milliseconds(25),
        maxAttempts: Int = 80,
        condition: @escaping @MainActor () -> Bool
    ) async {
        for _ in 0..<maxAttempts {
            if condition() {
                return
            }
            guard await Task.waitUnlessCancelled(for: pollInterval) else { return }
        }

        Issue.record("\(description)")
    }
}

@MainActor
private final class TestCatalogueFetcher: NDISCatalogueFetching {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchNDISItemSnapshots() async throws -> [NDISItemSnapshot] {
        try await MainActor.run {
            try context.fetch(FetchDescriptor<NDISItem>()).map { $0.snapshot() }
        }
    }

    func getChangesSummary() async throws -> NDISChangesSummary {
        try await MainActor.run {
            let items = try context.fetch(FetchDescriptor<NDISItem>())
            let unique = Set(items.map(\.itemNumber)).count
            return NDISChangesSummary(
                totalUniqueItems: unique,
                totalVersions: items.count,
                currentItems: items.filter(\.isCurrent).count,
                historicalItems: items.filter { !$0.isCurrent }.count,
                itemsWithChanges: 0
            )
        }
    }

    func analyzeItemChanges(itemNumber: String) async throws -> [NDISItemChange] { [] }
}

@MainActor
private final class SequencedCatalogueFetcher: NDISCatalogueFetching {
    private var continuations: [CheckedContinuation<[NDISItemSnapshot], any Error>] = []

    var pendingCallCount: Int { continuations.count }

    func fetchNDISItemSnapshots() async throws -> [NDISItemSnapshot] {
        try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func completeCall(at index: Int, with snapshots: [NDISItemSnapshot]) {
        continuations[index].resume(returning: snapshots)
    }

    func getChangesSummary() async throws -> NDISChangesSummary {
        NDISChangesSummary(
            totalUniqueItems: 0,
            totalVersions: 0,
            currentItems: 0,
            historicalItems: 0,
            itemsWithChanges: 0
        )
    }

    func analyzeItemChanges(itemNumber: String) async throws -> [NDISItemChange] { [] }
}
