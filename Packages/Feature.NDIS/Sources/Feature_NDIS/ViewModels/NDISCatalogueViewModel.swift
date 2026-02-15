import SwiftUI
import Core
import Data

@MainActor
public class NDISCatalogueViewModel: ObservableObject {
    private let unitOfWork: UnitOfWorkService
    
    @Published public var searchText = ""
    @Published private(set) var ndisItems: [NDISItem] = []
    @Published public var isLoading = false
    
    public init(unitOfWork: UnitOfWorkService) {
        self.unitOfWork = unitOfWork
        
        Task {
            await fetchNDISItems()
        }
    }
    
    public func fetchNDISItems() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Fetch current items using repository
            let items = try await unitOfWork.ndisItems.fetchEffective()
            self.ndisItems = items
        } catch {
            print("❌ [NDISCatalogueViewModel] Failed to fetch NDIS items: \(error)")
            self.ndisItems = []
        }
    }
    
    public var sectionedItems: [CatalogueSection] {
        // 1. Pre-process items
        let processableItems = ndisItems.map { item in
            ProcessableNDISItem(
                item: item,
                groupingCategory: (item.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Uncategorized" : (item.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                itemNumberForSort: item.itemNumber,
                name: item.name,
                itemNumber: item.itemNumber,
                itemDescription: item.description ?? "",
                quoteRequired: item.quoteRequired ?? false
            )
        }
        
        // 2. Filter based on search text
        let filteredProcessableItems: [ProcessableNDISItem]
        if searchText.isEmpty {
            filteredProcessableItems = processableItems
        } else {
            let lowercasedSearchText = searchText.lowercased()
            filteredProcessableItems = processableItems.filter {
                $0.name.lowercased().contains(lowercasedSearchText) ||
                $0.itemNumber.lowercased().contains(lowercasedSearchText) ||
                $0.itemDescription.lowercased().contains(lowercasedSearchText)
            }
        }
        
        // 3. Group by category
        let groupedByCategory = Dictionary(grouping: filteredProcessableItems) { $0.groupingCategory }
        
        // 4. Create section models
        var mappedSections: [CatalogueSection] = []
        for (categoryName, itemsInGroup) in groupedByCategory {
            let sortedItems = itemsInGroup.map { $0.item }.sorted { lhs, rhs in
                if lhs.isCurrent != rhs.isCurrent {
                    return lhs.isCurrent && !rhs.isCurrent
                }
                return lhs.itemNumber < rhs.itemNumber
            }
            mappedSections.append(CatalogueSection(id: categoryName, header: categoryName, items: sortedItems))
        }
        
        // 5. Sort the sections
        return mappedSections.sorted { $0.header < $1.header }
    }
    
    private struct ProcessableNDISItem {
        let item: NDISItem
        let groupingCategory: String
        let itemNumberForSort: String
        let name: String
        let itemNumber: String
        let itemDescription: String
        let quoteRequired: Bool
    }
}

public struct CatalogueSection: Identifiable {
    public let id: String
    public var header: String
    public var items: [NDISItem]
}
