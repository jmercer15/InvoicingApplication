import Foundation

public enum NDISCatalogueQuoteFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case quoteRequired = "Quote Req."
    case noQuoteRequired = "No Quote"
    case priceLimited = "Priced"

    public var id: String { rawValue }
}

public enum NDISCatalogueItemVersionFilter: String, CaseIterable, Identifiable, Sendable {
    case currentOnly = "Current Only"
    case historicalOnly = "Historical Only"
    case all = "All Versions"

    public var id: String { rawValue }
}

public enum NDISCatalogueSortOrder: String, CaseIterable, Identifiable, Sendable {
    case nameAsc = "Name (A-Z)"
    case nameDesc = "Name (Z-A)"
    case itemNumberAsc = "Item # (Asc)"
    case itemNumberDesc = "Item # (Desc)"
    case priceAsc = "Price (Low-High)"
    case priceDesc = "Price (High-Low)"
    case registrationGroupAsc = "Group (A-Z)"
    case registrationGroupDesc = "Group (Z-A)"

    public var id: String { rawValue }
}

public struct NDISCatalogueQuerySpec: Equatable, Sendable {
    public let searchText: String
    public let quoteFilter: NDISCatalogueQuoteFilter
    public let selectedCategoryId: String?
    public let selectedRegistrationGroup: String?
    public let sortOrder: NDISCatalogueSortOrder
    public let selectedFeatures: [String]
    public let selectedUnits: [String]
    public let itemVersionFilter: NDISCatalogueItemVersionFilter

    public init(
        searchText: String,
        quoteFilter: NDISCatalogueQuoteFilter,
        selectedCategoryId: String?,
        selectedRegistrationGroup: String?,
        sortOrder: NDISCatalogueSortOrder,
        selectedFeatures: [String],
        selectedUnits: [String],
        itemVersionFilter: NDISCatalogueItemVersionFilter = .currentOnly
    ) {
        self.searchText = searchText
        self.quoteFilter = quoteFilter
        self.selectedCategoryId = selectedCategoryId
        self.selectedRegistrationGroup = selectedRegistrationGroup
        self.sortOrder = sortOrder
        self.selectedFeatures = selectedFeatures
        self.selectedUnits = selectedUnits
        self.itemVersionFilter = itemVersionFilter
    }
}
