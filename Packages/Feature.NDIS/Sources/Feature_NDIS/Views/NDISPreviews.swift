#if DEBUG
import Core
import DataInterfaces
import PersistenceModels
import SwiftData
import SwiftUI

private struct PreviewNDISCatalogueFetcher: NDISCatalogueFetching {
    let items: [NDISItemSnapshot]

    func fetchNDISItemSnapshots() async throws -> [NDISItemSnapshot] { items }

    func getChangesSummary() async throws -> NDISChangesSummary {
        NDISChangesSummary(
            totalUniqueItems: items.count,
            totalVersions: items.count,
            currentItems: items.count,
            historicalItems: 0,
            itemsWithChanges: 1
        )
    }

    func analyzeItemChanges(itemNumber: String) async throws -> [NDISItemChange] { [] }
}

@MainActor
private enum NDISPreviewSupport {
    static let item = NDISItemSnapshot(
        id: UUID(uuidString: "7D6C40C2-BB7D-4A67-97F6-E809D6699E2B")!,
        itemNumber: "01_011_0107_1_1",
        name: "Assistance With Self-Care Activities",
        versionIdentifier: "2026-07",
        isCurrent: true,
        category: "Assistance with Daily Life",
        effectiveStartDate: Date(timeIntervalSinceReferenceDate: 773_280_000),
        effectiveEndDate: nil,
        features: "Non-Face-to-Face, Provider Travel",
        itemDescription: "Support for self-care activities in standard weekday delivery.",
        ndiaRequestedReports: false,
        nonFaceToFaceProvision: true,
        providerTravel: true,
        quoteRequired: false,
        registrationGroup: "Daily Personal Activities",
        registrationGroupNumber: "0107",
        shortNoticeCancellations: true,
        irregularSILSupports: false,
        status: "Active",
        type: "Standard",
        unit: "Hour",
        regionalPrices: [
            RegionalPriceSnapshot(id: UUID(), amount: 74.63, regionIdentifier: "NSW")
        ],
        price: 74.63,
        effectiveDateRange: "1 July 2026 - Current"
    )

    static func makeContainer() -> ModelContainer {
        let schema = Schema(PersistenceSchema.appModels)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try! ModelContainer(for: schema, configurations: [configuration])
    }

    static func makeViewModel(selected: Bool = false) -> NDISContainerViewModel {
        let viewModel = NDISContainerViewModel(catalogueFetching: PreviewNDISCatalogueFetcher(items: [item]))
        viewModel.hasLoadedCatalogue = true
        viewModel.catalogueProjection = NDISCatalogueProjection(
            totalItemCount: 1,
            filteredItems: [item],
            itemLookup: [item.id: item],
            resolvedSelectedItem: selected ? item : nil,
            navigationTree: [
                NDISCatalogueTreeNode(
                    id: "daily-life",
                    title: "Assistance with Daily Life",
                    subtitle: "1 support item",
                    children: [
                        NDISCatalogueTreeNode(
                            id: item.id.uuidString,
                            title: item.name,
                            subtitle: item.itemNumber,
                            entityID: item.id.uuidString,
                            entityType: "ndisItem"
                        )
                    ],
                    descendantCount: 1
                )
            ],
            categories: ["Assistance with Daily Life"],
            registrationGroupsForMenu: ["Daily Personal Activities"],
            featuresForToolbarMenu: ["Provider Travel", "Non-Face-to-Face"],
            unitsForToolbarMenu: ["Hour"],
            activeFilters: [],
            preferredRegionIdentifier: "NSW"
        )
        if selected {
            viewModel.selectedItemID = item.id
        }
        return viewModel
    }
}

#Preview("NDIS Catalogue") {
    let container = NDISPreviewSupport.makeContainer()
    let viewModel = NDISPreviewSupport.makeViewModel()

    NavigationStack {
        NDISCatalogueContentColumn(viewModel: viewModel)
    }
    .modelContainer(container)
    .frame(width: 820, height: 560)
}

#Preview("NDIS Detail") {
    let viewModel = NDISPreviewSupport.makeViewModel(selected: true)

    NDISCatalogueDetailColumn(viewModel: viewModel)
        .frame(width: 620, height: 560)
}
#endif
