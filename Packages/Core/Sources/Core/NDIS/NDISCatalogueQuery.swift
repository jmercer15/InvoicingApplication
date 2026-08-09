import Foundation

public enum NDISCatalogueQuery {
    public typealias QuoteFilter = NDISCatalogueQuoteFilter
    public typealias ItemVersionFilter = NDISCatalogueItemVersionFilter
    public typealias SortOrder = NDISCatalogueSortOrder

    public static func filteredAndSortedItems(
        from items: [NDISItemSnapshot],
        spec: NDISCatalogueQuerySpec
    ) -> [NDISItemSnapshot] {
        filteredAndSortedItems(
            from: items,
            searchText: spec.searchText,
            quoteFilter: spec.quoteFilter,
            selectedCategoryId: spec.selectedCategoryId,
            selectedRegistrationGroup: spec.selectedRegistrationGroup,
            sortOrder: spec.sortOrder,
            selectedFeatures: spec.selectedFeatures,
            selectedUnits: spec.selectedUnits,
            itemVersionFilter: spec.itemVersionFilter
        )
    }

    public static func filteredAndSortedItems(
        from items: [NDISItemSnapshot],
        searchText: String,
        quoteFilter: QuoteFilter,
        selectedCategoryId: String?,
        selectedRegistrationGroup: String?,
        sortOrder: SortOrder,
        selectedFeatures: [String],
        selectedUnits: [String],
        itemVersionFilter: ItemVersionFilter = .currentOnly
    ) -> [NDISItemSnapshot] {
        let versionFilteredItems = applyVersionFilter(items, versionFilter: itemVersionFilter)
        return filteredAndSortedItemsWithoutVersionFilter(
            from: versionFilteredItems,
            searchText: searchText,
            quoteFilter: quoteFilter,
            selectedCategoryId: selectedCategoryId,
            selectedRegistrationGroup: selectedRegistrationGroup,
            sortOrder: sortOrder,
            selectedFeatures: selectedFeatures,
            selectedUnits: selectedUnits
        )
    }

    private static func applyVersionFilter(
        _ items: [NDISItemSnapshot],
        versionFilter: ItemVersionFilter
    ) -> [NDISItemSnapshot] {
        let now = Date()

        switch versionFilter {
        case .currentOnly:
            let currentItems = items.filter { item in
                let start = item.effectiveStartDate ?? .distantPast
                let end = item.effectiveEndDate ?? .distantFuture
                let isEffectiveNow = start <= now && now <= end
                return item.isCurrent || isEffectiveNow
            }
            return deduplicateCurrentItems(currentItems)

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

    private static func filteredAndSortedItemsWithoutVersionFilter(
        from items: [NDISItemSnapshot],
        searchText: String,
        quoteFilter: QuoteFilter,
        selectedCategoryId: String?,
        selectedRegistrationGroup: String?,
        sortOrder: SortOrder,
        selectedFeatures: [String],
        selectedUnits: [String]
    ) -> [NDISItemSnapshot] {
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
        case .noQuoteRequired:
            result = result.filter { $0.quoteRequired != true }
        case .priceLimited:
            result = result.filter { !$0.regionalPrices.isEmpty }
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

        if !selectedFeatures.isEmpty {
            result = result.filter { item in
                let features = (item.features ?? "")
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                return selectedFeatures.allSatisfy { selectedFeature in
                    features.contains { $0.localizedCaseInsensitiveContains(selectedFeature) }
                }
            }
        }

        if !selectedUnits.isEmpty {
            result = result.filter { item in
                let unit = item.unit ?? ""
                return selectedUnits.contains { selectedUnit in
                    unit.localizedCaseInsensitiveCompare(selectedUnit) == .orderedSame
                }
            }
        }

        return sortedItems(from: result, with: sortOrder)
    }

    private static func sortedItems(from items: [NDISItemSnapshot], with sortOrder: SortOrder) -> [NDISItemSnapshot] {
        guard items.count > 1 else { return items }

        switch sortOrder {
        case .nameAsc:
            return items.sorted { compareNames($0, $1, ascending: true) }
        case .nameDesc:
            return items.sorted { compareNames($0, $1, ascending: false) }
        case .itemNumberAsc:
            return items.sorted { compareItemNumbers($0, $1, ascending: true) }
        case .itemNumberDesc:
            return items.sorted { compareItemNumbers($0, $1, ascending: false) }
        case .priceAsc:
            return items.sorted { comparePrices($0, $1, ascending: true) }
        case .priceDesc:
            return items.sorted { comparePrices($0, $1, ascending: false) }
        case .registrationGroupAsc:
            return items.sorted { compareRegistrationGroups($0, $1, ascending: true) }
        case .registrationGroupDesc:
            return items.sorted { compareRegistrationGroups($0, $1, ascending: false) }
        }
    }

    private static func compareNames(_ lhs: NDISItemSnapshot, _ rhs: NDISItemSnapshot, ascending: Bool) -> Bool {
        let comparison = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if comparison == .orderedSame {
            return tieBreak(lhs: lhs, rhs: rhs, ascending: ascending)
        }
        return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
    }

    private static func compareItemNumbers(_ lhs: NDISItemSnapshot, _ rhs: NDISItemSnapshot, ascending: Bool) -> Bool {
        let comparison = lhs.itemNumber.localizedStandardCompare(rhs.itemNumber)
        if comparison == .orderedSame {
            return compareNames(lhs, rhs, ascending: ascending)
        }
        return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
    }

    private static func compareRegistrationGroups(_ lhs: NDISItemSnapshot, _ rhs: NDISItemSnapshot, ascending: Bool) -> Bool {
        let lhsGroup = normalizedOptional(lhs.registrationGroup)
        let rhsGroup = normalizedOptional(rhs.registrationGroup)

        switch (lhsGroup, rhsGroup) {
        case let (left?, right?):
            let comparison = left.localizedCaseInsensitiveCompare(right)
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

    private static func comparePrices(_ lhs: NDISItemSnapshot, _ rhs: NDISItemSnapshot, ascending: Bool) -> Bool {
        let lhsPrice = primaryPrice(for: lhs)
        let rhsPrice = primaryPrice(for: rhs)

        switch (lhsPrice, rhsPrice) {
        case let (left?, right?):
            if left == right {
                return tieBreak(lhs: lhs, rhs: rhs, ascending: ascending)
            }
            return ascending ? left < right : left > right
        case (nil, nil):
            return tieBreak(lhs: lhs, rhs: rhs, ascending: ascending)
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        }
    }

    private static func tieBreak(lhs: NDISItemSnapshot, rhs: NDISItemSnapshot, ascending: Bool) -> Bool {
        let numberComparison = lhs.itemNumber.localizedStandardCompare(rhs.itemNumber)
        if numberComparison != .orderedSame {
            return ascending ? numberComparison == .orderedAscending : numberComparison == .orderedDescending
        }

        return ascending
            ? lhs.id.uuidString < rhs.id.uuidString
            : lhs.id.uuidString > rhs.id.uuidString
    }

    private static func normalizedOptional(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func primaryPrice(for item: NDISItemSnapshot) -> Decimal? {
        if let nationalPrice = item.regionalPrices.first(where: { ($0.regionIdentifier ?? "").caseInsensitiveCompare("NATIONAL") == .orderedSame })?.amount {
            return nationalPrice
        }
        return item.regionalPrices.map(\.amount).min()
    }

    /// Keeps the newest effective-dated row per item number + name (used by catalogue and client service pickers).
    public static func deduplicatedCatalogueItems(_ items: [NDISItemSnapshot]) -> [NDISItemSnapshot] {
        deduplicateCurrentItems(items)
    }

    private static func deduplicateCurrentItems(_ items: [NDISItemSnapshot]) -> [NDISItemSnapshot] {
        var itemsByKey: [String: NDISItemSnapshot] = [:]

        for item in items {
            let key = "\(item.itemNumber)|\(item.name)"
            guard let existing = itemsByKey[key] else {
                itemsByKey[key] = item
                continue
            }

            let existingStartDate = existing.effectiveStartDate ?? .distantPast
            let itemStartDate = item.effectiveStartDate ?? .distantPast
            if itemStartDate > existingStartDate {
                itemsByKey[key] = item
            }
        }

        return Array(itemsByKey.values)
    }
}
