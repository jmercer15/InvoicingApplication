import SwiftUI
import SwiftData
import Core
import Data
import os

extension NDISContainerViewModel {

    // MARK: - Dedicated Projection Actor
    
    actor NDISCatalogueProjectionActor {
        private static let projectionSignpostLog = OSLog(subsystem: "com.invoicingapplication.app", category: "ndis-projection")

        func process(contract: CatalogueProcessingContext) async -> NDISCatalogueProjectionResult {
        #if DEBUG
            let signpostID = OSSignpostID(log: Self.projectionSignpostLog)
            os_signpost(.begin, log: Self.projectionSignpostLog, name: "NDISCatalogueProjection", signpostID: signpostID, "%{public}d items", contract.items.count)
        #endif
            return await withTaskCancellationHandler {
                let caches = NDISContainerViewModel.buildCaches(from: contract.items)
                let projection = NDISContainerViewModel.makeCatalogueProjection(
                    from: contract.items,
                    querySpec: contract.querySpec,
                    selectedItemID: contract.selectedItemID,
                    preferredRegionIdentifier: contract.preferredRegionIdentifier,
                    caches: caches
                )
                let result = ProcessedCatalogueState(
                    caches: caches,
                    projection: projection
                )
            #if DEBUG
                os_signpost(.end, log: Self.projectionSignpostLog, name: "NDISCatalogueProjection", signpostID: signpostID, "filtered=%{public}d", result.projection.filteredItems.count)
            #endif
                return NDISCatalogueProjectionResult(
                    requestID: contract.requestID,
                    state: result
                )
            } onCancel: { }
        }
    }

    /// Pure filtering/sort; safe to call from any isolation (used from `@MainActor` processing tasks).
    nonisolated static func getFilteredAndSortedItemsStatic(
        from items: [NDISItemSnapshot],
        searchText: String,
        quoteFilter: QuoteFilter,
        selectedCategoryId: String?,
        selectedRegistrationGroup: String?,
        sortOrder: SortOrder,
        currentSelectedFeatures: [String],
        currentSelectedUnits: [String],
        itemVersionFilter: ItemVersionFilter = .currentOnly
    ) -> [NDISItemSnapshot] {
        NDISCatalogueQuery.filteredAndSortedItems(
            from: items,
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

    nonisolated static func makeCatalogueProjection(
        from items: [NDISItemSnapshot],
        querySpec: NDISCatalogueQuerySpec,
        selectedItemID: UUID?,
        preferredRegionIdentifier: String?,
        caches: CatalogueCaches? = nil
    ) -> NDISCatalogueProjection {
        let caches = caches ?? Self.buildCaches(from: items)
        let filteredItems = Self.getFilteredAndSortedItemsStatic(
            from: items,
            searchText: querySpec.searchText,
            quoteFilter: querySpec.quoteFilter,
            selectedCategoryId: querySpec.selectedCategoryId,
            selectedRegistrationGroup: querySpec.selectedRegistrationGroup,
            sortOrder: querySpec.sortOrder,
            currentSelectedFeatures: querySpec.selectedFeatures,
            currentSelectedUnits: querySpec.selectedUnits,
            itemVersionFilter: querySpec.itemVersionFilter
        )
        let registrationGroupsForMenu = Self.registrationGroupsForMenu(
            selectedCategoryId: querySpec.selectedCategoryId,
            items: items,
            fallbackGroups: caches.registrationGroups
        )

        return NDISCatalogueProjection(
            totalItemCount: items.count,
            filteredItems: filteredItems,
            itemLookup: Dictionary(uniqueKeysWithValues: filteredItems.map { ($0.id, $0) }),
            resolvedSelectedItem: Self.resolveSelectedItem(selectedItemID: selectedItemID, from: items),
            navigationTree: Self.makeNavigationTree(from: filteredItems),
            categories: caches.categories,
            registrationGroupsForMenu: registrationGroupsForMenu,
            featuresForToolbarMenu: Self.getTopFeaturesStatic(from: filteredItems, count: 10),
            unitsForToolbarMenu: Self.getTopUnitsStatic(from: filteredItems, count: 10),
            activeFilters: Self.makeActiveFilters(for: querySpec),
            preferredRegionIdentifier: preferredRegionIdentifier
        )
    }
    
    // MARK: - Caching and Data Update Logic
    
    nonisolated static func buildCaches(from items: [NDISItemSnapshot]) -> CatalogueCaches {
        CatalogueCaches(
            categories: Array(Set(items.compactMap { $0.category })).sorted(),
            features: Array(
                Set(
                    items
                        .compactMap { $0.features }
                        .flatMap { $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                )
            ).sorted(),
            registrationGroups: Array(Set(items.map { $0.registrationGroup ?? "" })).sorted(),
            units: Array(Set(items.map { $0.unit ?? "" })).sorted()
        )
    }
    
    nonisolated static func getTopFeaturesStatic(from items: [NDISItemSnapshot], count: Int) -> [String] {
        let allFeatures = items.flatMap { ($0.features ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
        let featureCounts = allFeatures.reduce(into: [:]) { counts, feature in // Use non-optional features
            counts[feature, default: 0] += 1
        }
        
        let sortedFeatures = featureCounts.keys.sorted {
            (featureCounts[$0] ?? 0) > (featureCounts[$1] ?? 0)
        }
        
        return Array(sortedFeatures.prefix(count))
    }
    
    nonisolated static func getTopUnitsStatic(from items: [NDISItemSnapshot], count: Int) -> [String] {
        let allUnits = items.map { $0.unit ?? "" }.filter { !$0.isEmpty }
        let unitCounts = allUnits.reduce(into: [:]) { counts, unit in
            counts[unit, default: 0] += 1
        }
        
        let sortedUnits = unitCounts.keys.sorted { (unitCounts[$0] ?? 0) > (unitCounts[$1] ?? 0) }
        
        return Array(sortedUnits.prefix(count))
    }
    
    nonisolated static func displayString(forUnit unitCode: String) -> String {
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
    
    nonisolated static func makeActiveFilters(for spec: NDISCatalogueQuerySpec) -> [ActiveFilter] {
        var filters: [ActiveFilter] = []
        if let category = spec.selectedCategoryId {
            filters.append(ActiveFilter(type: .category, name: "Category: \(category)"))
        }
        if let group = spec.selectedRegistrationGroup, group != "All" {
            filters.append(ActiveFilter(type: .group, name: "Group: \(group)"))
        }
        if spec.quoteFilter != .all {
            filters.append(ActiveFilter(type: .quote, name: "Pricing: \(spec.quoteFilter.rawValue)"))
        }
        spec.selectedFeatures.forEach { feature in
            filters.append(ActiveFilter(type: .feature(feature), name: "Feature: \(feature)"))
        }
        spec.selectedUnits.forEach { unit in
            filters.append(ActiveFilter(type: .unit(unit), name: "Unit: \(Self.displayString(forUnit: unit))"))
        }
        return filters
    }

    nonisolated static func resolveSelectedItem(selectedItemID: UUID?, from items: [NDISItemSnapshot]) -> NDISItemSnapshot? {
        guard let selectedItemID else { return nil }
        return items.first(where: { $0.id == selectedItemID })
    }

    nonisolated static func registrationGroupsForMenu(
        selectedCategoryId: String?,
        items: [NDISItemSnapshot],
        fallbackGroups: [String]
    ) -> [String] {
        if let categoryId = selectedCategoryId {
            let itemsInCategory = items.filter { ($0.category ?? "") == categoryId }
            let groups = Array(
                Set(itemsInCategory.map { ($0.registrationGroup ?? "").isEmpty ? "Unassigned" : ($0.registrationGroup ?? "") })
            ).sorted()
            return ["All"] + groups
        }

        return ["All"] + fallbackGroups
    }

    nonisolated static func makeNavigationTree(from items: [NDISItemSnapshot]) -> [NDISCatalogueTreeNode] {
        let groupedByCategory = Dictionary(grouping: items) { item in
            let value = (item.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? "Uncategorized" : value
        }

        return groupedByCategory
            .sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending })
            .map { category, categoryItems in
                let groupedByRegistration = Dictionary(grouping: categoryItems) { item in
                    let value = (item.registrationGroup ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                    return value.isEmpty ? "No Group" : value
                }

                let categoryChildren = groupedByRegistration
                    .sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending })
                    .map { group, groupItems in
                        let sortedItems = groupItems.sorted { lhs, rhs in
                            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                        }

                        let itemChildren = sortedItems.map { item in
                            NDISCatalogueTreeNode(
                                id: "ndis_item_\(item.id.uuidString)",
                                title: item.name,
                                subtitle: item.itemNumber,
                                children: nil,
                                entityID: item.id.uuidString,
                                entityType: "ndisItem",
                                descendantCount: 1
                            )
                        }

                        return NDISCatalogueTreeNode(
                            id: "group_\(category)_\(group)",
                            title: group,
                            subtitle: "\(groupItems.count) \(groupItems.count == 1 ? "item" : "items")",
                            children: itemChildren,
                            descendantCount: groupItems.count
                        )
                    }

                return NDISCatalogueTreeNode(
                    id: "category_\(category)",
                    title: category,
                    subtitle: "\(categoryItems.count) \(categoryItems.count == 1 ? "item" : "items")",
                    children: categoryChildren,
                    descendantCount: categoryItems.count
                )
            }
    }
}
