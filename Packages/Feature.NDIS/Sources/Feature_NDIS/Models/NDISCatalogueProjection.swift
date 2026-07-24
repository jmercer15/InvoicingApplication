import Core
import Foundation

struct NDISCatalogueProjection {
    let totalItemCount: Int
    let filteredItems: [NDISItemSnapshot]
    let itemLookup: [UUID: NDISItemSnapshot]
    let resolvedSelectedItem: NDISItemSnapshot?
    let navigationTree: [NDISCatalogueTreeNode]
    let categories: [String]
    let registrationGroupsForMenu: [String]
    let featuresForToolbarMenu: [String]
    let unitsForToolbarMenu: [String]
    let activeFilters: [NDISContainerViewModel.ActiveFilter]
    let preferredRegionIdentifier: String?

    static func empty(preferredRegionIdentifier: String? = nil) -> Self {
        Self(
            totalItemCount: 0,
            filteredItems: [],
            itemLookup: [:],
            resolvedSelectedItem: nil,
            navigationTree: [],
            categories: [],
            registrationGroupsForMenu: ["All"],
            featuresForToolbarMenu: [],
            unitsForToolbarMenu: [],
            activeFilters: [],
            preferredRegionIdentifier: preferredRegionIdentifier
        )
    }
}

struct NDISCatalogueTreeNode: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let children: [NDISCatalogueTreeNode]?
    let entityID: String?
    let entityType: String?
    let descendantCount: Int

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        children: [NDISCatalogueTreeNode]? = nil,
        entityID: String? = nil,
        entityType: String? = nil,
        descendantCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.children = children
        self.entityID = entityID
        self.entityType = entityType
        self.descendantCount = descendantCount
    }
}
