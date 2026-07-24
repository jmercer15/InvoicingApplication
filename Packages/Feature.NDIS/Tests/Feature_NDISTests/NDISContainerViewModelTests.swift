import Core
import XCTest
import SwiftData
@testable import Feature_NDIS

@MainActor
final class NDISContainerViewModelTests: XCTestCase {
    func testUpdateSourceItemsBuildsProjectionOnce() async {
        let context = try! makeInMemoryContext()
        insertSampleItems(into: context)
        let viewModel = makeViewModel(modelContext: context)
        let sourceItems = try! context.fetch(FetchDescriptor<NDISItem>())

        await viewModel.refreshItems(sourceItems.map { $0.snapshot() })

        XCTAssertEqual(viewModel.catalogueProjection.totalItemCount, 3)
        XCTAssertEqual(viewModel.catalogueProjection.filteredItems.count, 3)
        XCTAssertEqual(viewModel.catalogueProjection.categories, ["Capacity Building", "Core"])

        await viewModel.refreshItems(sourceItems.map { $0.snapshot() })
        XCTAssertEqual(viewModel.catalogueProjection.totalItemCount, 3)
    }

    func testSearchAndCategoryFiltersReuseCachedItems() async {
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

    func testSelectionResolvesImmediatelyAgainstCachedItems() async {
        let context = try! makeInMemoryContext()
        insertSampleItems(into: context)
        let viewModel = makeViewModel(modelContext: context)
        let sourceItems = try! context.fetch(FetchDescriptor<NDISItem>())

        await viewModel.refreshItems(sourceItems.map { $0.snapshot() })

        viewModel.selectedItemID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")

        XCTAssertEqual(viewModel.resolvedSelectedItem?.itemNumber, "15_001")
        XCTAssertEqual(viewModel.resolvedSelectedItem?.name, "Plan Management Setup")
    }

    func testLoadCatalogueStateChanges() async {
        let context = try! makeInMemoryContext()
        let viewModel = makeViewModel(modelContext: context)

        XCTAssertFalse(viewModel.hasLoadedCatalogue)
        XCTAssertNil(viewModel.loadError)

        viewModel.loadCatalogue(force: true)
        
        await assertEventually("hasLoadedCatalogue becomes true") {
            viewModel.hasLoadedCatalogue == true
        }
        XCTAssertNil(viewModel.loadError)
    }

    func testRegionIdentifierMappingAndPreferredRegion() async {
        let context = try! makeInMemoryContext()
        let viewModel = makeViewModel(modelContext: context)
        
        // Test nil business
        viewModel.refreshPreferredRegion(using: nil)
        XCTAssertTrue(viewModel.hasResolvedPreferredRegion)
        XCTAssertNil(viewModel.preferredRegionIdentifier)
        
        // Test unknown state
        let address1 = Address()
        address1.state = "UnknownState"
        let business1 = Business(abn: "123")
        business1.address = address1
        viewModel.refreshPreferredRegion(using: business1)
        XCTAssertNil(viewModel.preferredRegionIdentifier)
        
        // Test various representations of NSW
        for state in ["NSW", "New South Wales", "N.S.W.", "nsw", "  N.S.W.  "] {
            let address = Address()
            address.state = state
            let business = Business(abn: "123")
            business.address = address
            viewModel.refreshPreferredRegion(using: business)
            XCTAssertEqual(viewModel.preferredRegionIdentifier, "NSW", "Should resolve \(state) to NSW")
        }
        
        // Test abbreviation matching fallback
        let addressACT = Address()
        addressACT.state = "ACT (Canberra)"
        let businessACT = Business(abn: "123")
        businessACT.address = addressACT
        viewModel.refreshPreferredRegion(using: businessACT)
        XCTAssertEqual(viewModel.preferredRegionIdentifier, "ACT")
    }

    func testLoadCatalogueConcurrentlyDoesNotCrash() async {
        let context = try! makeInMemoryContext()
        insertSampleItems(into: context)
        let viewModel = makeViewModel(modelContext: context)

        for _ in 0..<10 {
            viewModel.loadCatalogue(force: true)
        }

        await assertEventually("hasLoadedCatalogue becomes true") {
            viewModel.hasLoadedCatalogue == true
        }

        XCTAssertNil(viewModel.loadError)
        XCTAssertEqual(viewModel.catalogueProjection.totalItemCount, 3)
    }

    func testFetchChangesSummarySuccess() async {
        let context = try! makeInMemoryContext()
        insertSampleItems(into: context)
        let viewModel = makeViewModel(modelContext: context)

        await viewModel.fetchChangesSummary()
        XCTAssertFalse(viewModel.isAnalyzingChanges)
        XCTAssertNotNil(viewModel.changesSummary)
        XCTAssertNil(viewModel.changesError)
        XCTAssertEqual(viewModel.changesSummary?.totalUniqueItems, 3)
    }

    func testLoadItemHistoryDoesNotCrashWithAtLeastOneVersion() async {
        let context = try! makeInMemoryContext()
        insertSampleItems(into: context)
        let viewModel = makeViewModel(modelContext: context)

        XCTAssertFalse(viewModel.isAnalyzingChanges)
        XCTAssertTrue(viewModel.itemChanges.isEmpty)

        await viewModel.loadItemHistory(for: "15_001")

        XCTAssertFalse(viewModel.isAnalyzingChanges)
        XCTAssertTrue(viewModel.itemChanges.isEmpty)
    }

    func testClearAllFiltersResetsState() async {
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

        XCTAssertEqual(viewModel.quoteFilter, .all)
        XCTAssertTrue(viewModel.currentSelectedFeatures.isEmpty)
        XCTAssertTrue(viewModel.currentSelectedUnits.isEmpty)
        XCTAssertNil(viewModel.selectedCategoryId)
        XCTAssertNil(viewModel.selectedRegistrationGroup)
        XCTAssertEqual(viewModel.searchText, "")
        XCTAssertEqual(viewModel.itemVersionFilter, .currentOnly)
    }

    private func makeViewModel(modelContext: ModelContext) -> NDISContainerViewModel {
        NDISContainerViewModel(modelContext: modelContext)
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
            try? await Task.sleep(for: pollInterval)
        }

        XCTFail(description)
    }
}
