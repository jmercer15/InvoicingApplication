import Core
import Foundation
import PersistenceModels
import Testing
@testable import Feature_NDIS

@MainActor
@Suite struct NDISCatalogueQueryTests {
    @Test func FiltersCombineCategorySearchAndQuote() {
        let items = [
            sampleItem(
                id: id(1),
                number: "01_001",
                name: "Daily support",
                category: "Core",
                group: "NSW/ACT",
                quote: false,
                features: "home",
                unit: "Hour"
            ),
            sampleItem(
                id: id(2),
                number: "15_001",
                name: "Setup plan",
                category: "Capacity Building",
                group: "TAS",
                quote: true,
                features: "plan,setup",
                unit: "Each"
            ),
        ]

        let snapshots = items.map { NDISItemSnapshot($0) }

        let narrowed = NDISCatalogueQuery.filteredAndSortedItems(
            from: snapshots,
            searchText: "setup",
            quoteFilter: .all,
            selectedCategoryId: "Capacity Building",
            selectedRegistrationGroup: "All",
            sortOrder: .nameAsc,
            selectedFeatures: [],
            selectedUnits: [],
            itemVersionFilter: .all
        )
        #expect(narrowed.map(\.itemNumber) == ["15_001"])

        let quoteOnly = NDISCatalogueQuery.filteredAndSortedItems(
            from: snapshots,
            searchText: "",
            quoteFilter: .quoteRequired,
            selectedCategoryId: nil,
            selectedRegistrationGroup: nil,
            sortOrder: .itemNumberAsc,
            selectedFeatures: [],
            selectedUnits: [],
            itemVersionFilter: .all
        )
        #expect(quoteOnly.map(\.itemNumber) == ["15_001"])
    }

    @Test func VersionFilterCurrentOnlyKeepsNewerDuplicateByStartDate() {
        let cal = Calendar.current
        let olderStart = cal.date(from: DateComponents(year: 2020, month: 1, day: 1))!
        let newerStart = cal.date(from: DateComponents(year: 2023, month: 6, day: 1))!

        let older = sampleItem(
            id: id(10),
            number: "Dup",
            name: "Same",
            category: "Core",
            group: "NSW",
            quote: false,
            features: "",
            unit: "Hour",
            isCurrent: true,
            effectiveStart: olderStart,
            effectiveEnd: nil
        )
        let newer = sampleItem(
            id: id(11),
            number: "Dup",
            name: "Same",
            category: "Core",
            group: "NSW",
            quote: false,
            features: "",
            unit: "Hour",
            isCurrent: true,
            effectiveStart: newerStart,
            effectiveEnd: nil
        )

        let snapshots = [NDISItemSnapshot(older), NDISItemSnapshot(newer)]
        let filtered = NDISCatalogueQuery.filteredAndSortedItems(
            from: snapshots,
            searchText: "",
            quoteFilter: .all,
            selectedCategoryId: nil,
            selectedRegistrationGroup: nil,
            sortOrder: .nameAsc,
            selectedFeatures: [],
            selectedUnits: [],
            itemVersionFilter: .currentOnly
        )

        #expect(filtered.count == 1)
        #expect(filtered.first?.id == id(11))
    }

    @Test func FeatureAndUnitFiltersConjoin() {
        let a = sampleItem(
            id: id(3),
            number: "X1",
            name: "A",
            category: "Core",
            group: "NSW",
            quote: false,
            features: "alpha, beta",
            unit: "Hour"
        )
        let b = sampleItem(
            id: id(4),
            number: "X2",
            name: "B",
            category: "Core",
            group: "NSW",
            quote: false,
            features: "alpha",
            unit: "Each"
        )
        let snapshots = [NDISItemSnapshot(a), NDISItemSnapshot(b)]

        let bothTags = NDISCatalogueQuery.filteredAndSortedItems(
            from: snapshots,
            searchText: "",
            quoteFilter: .all,
            selectedCategoryId: nil,
            selectedRegistrationGroup: nil,
            sortOrder: .nameAsc,
            selectedFeatures: ["alpha", "beta"],
            selectedUnits: [],
            itemVersionFilter: .all
        )
        #expect(bothTags.map(\.itemNumber) == ["X1"])

        let unitHour = NDISCatalogueQuery.filteredAndSortedItems(
            from: snapshots,
            searchText: "",
            quoteFilter: .all,
            selectedCategoryId: nil,
            selectedRegistrationGroup: nil,
            sortOrder: .nameAsc,
            selectedFeatures: [],
            selectedUnits: ["hour"],
            itemVersionFilter: .all
        )
        #expect(unitHour.map(\.itemNumber) == ["X1"])
    }

    private func id(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
    }

    private func sampleItem(
        id: UUID,
        number: String,
        name: String,
        category: String,
        group: String,
        quote: Bool,
        features: String,
        unit: String,
        isCurrent: Bool = true,
        effectiveStart: Date? = nil,
        effectiveEnd: Date? = nil
    ) -> NDISItem {
        let item = NDISItem(
            id: id,
            itemNumber: number,
            name: name,
            versionIdentifier: "v1",
            category: category,
            itemDescription: "desc",
            unit: unit
        )
        item.isCurrent = isCurrent
        item.registrationGroup = group
        item.quoteRequired = quote
        item.features = features.isEmpty ? nil : features
        item.effectiveStartDate = effectiveStart
        item.effectiveEndDate = effectiveEnd
        let rp = RegionalPrice()
        rp.regionIdentifier = "NATIONAL"
        rp.amount = 10
        item.regionalPrices = [rp]
        return item
    }
}

