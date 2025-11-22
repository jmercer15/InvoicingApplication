import SwiftUI
import SwiftData // Import SwiftData
import Data
import Core
import SharedUI

// Define a model for the sections
struct CatalogueSection: Identifiable {
    let id: String // Category name will be the ID
    var header: String // Display header for the section
    var items: [NDISItemEntity] // Change to NDISItemEntity
}

struct NDISCatalogueBrowser: View {
    @Environment(\.modelContext) private var modelContext // Change to modelContext
    @Environment(\.dismiss) private var dismiss

    // Action to perform when an item is selected
    let onItemSelected: (NDISItemEntity) -> Void // Change to NDISItemEntity

    @State private var searchText = ""
    
    // Use @Query for NDIS Items - only fetch current items
    @Query(
        sort: [
            SortDescriptor(\NDISItemEntity.itemNumber, order: .forward)
        ]
    ) private var ndisItems: [NDISItemEntity] // Change to NDISItemEntity

    // Intermediate struct for processing
    private struct ProcessableNDISItem {
        let entity: NDISItemEntity // Change to NDISItemEntity
        let groupingCategory: String
        let itemNumberForSort: String
        
        // Relevant fields for searching
        let name: String
        let itemNumber: String
        let itemDescription: String // Change to itemDescription and non-optional
        let quoteRequired: Bool
    }

    // Filtered items based on search text, now grouped into sections
    private var sectionedItems: [CatalogueSection] {
        // 1. Pre-process items
        let processableItems: [ProcessableNDISItem] = ndisItems.map {
            return ProcessableNDISItem(
                entity: $0,
                groupingCategory: ($0.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Uncategorized" : ($0.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                itemNumberForSort: $0.itemNumber,
                name: $0.name,
                itemNumber: $0.itemNumber,
                itemDescription: $0.itemDescription ?? "",
                quoteRequired: $0.quoteRequired ?? false
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
                $0.itemDescription.lowercased().contains(lowercasedSearchText) // Use non-optional itemDescription
            }
        }

        // 3. Group by category
        let groupedByCategory = Dictionary(grouping: filteredProcessableItems) { $0.groupingCategory }

        // 4. Create section models
        var mappedSections: [CatalogueSection] = []
        for (categoryName, itemsInGroup) in groupedByCategory {
            let sortedItemEntities = itemsInGroup.map { $0.entity }.sorted { (a: NDISItemEntity, b: NDISItemEntity) in
                // First sort by current status (current items first)
                if (a.isCurrent != b.isCurrent) {
                    return a.isCurrent && !b.isCurrent
                }
                // Then sort by item number
                return a.itemNumber < b.itemNumber
            }
            mappedSections.append(CatalogueSection(id: categoryName, header: categoryName, items: sortedItemEntities))
        }
        
        // 5. Sort the sections
        let sortedSections = mappedSections.sorted { $0.header < $1.header }
        
        return sortedSections
    }

    var body: some View {
        NavigationView {
            VStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(sectionedItems) { sectionModel in
                            VStack(alignment: .leading, spacing: 8) {
                                // Section header
                                Text(sectionModel.header)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color("Text", bundle: .sharedUI))
                                    .padding(.horizontal, 16)
                                
                                // Section items using native VStack
                                VStack(spacing: 8) {
                                    ForEach(sectionModel.items) { item in
                                        NDISCatalogueItemRow(
                                            item: item,
                                            onItemSelected: onItemSelected,
                                            dismiss: dismiss
                                        )
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("NDIS Catalogue")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.glass)
                        .help("Close catalogue without selecting")
                        .appInteractiveCursor()
                }
            }
            
            .searchable(text: $searchText, prompt: "Search support items...")
            .searchToolbarBehavior(.automatic)
            // Add frame modifier for initial size if presented as sheet
            .frame(minWidth: 500, idealWidth: 600, minHeight: 400, idealHeight: 500) 
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Supporting Views

struct NDISCatalogueItemRow: View {
    let item: NDISItemEntity // Change to NDISItemEntity
    let onItemSelected: (NDISItemEntity) -> Void // Change to NDISItemEntity
    let dismiss: DismissAction
    
    var body: some View {
        VStack(alignment: .leading) {
            itemHeaderView
            itemDetailsView
            itemDescriptionView
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onItemSelected(item)
            dismiss()
        }
    }
    
    private var itemHeaderView: some View {
        HStack {
            Text(item.name) // Use non-optional name
                .fontWeight(.medium)
            
            Spacer()
            
            versionStatusBadge
        }
    }
    
    @ViewBuilder
    private var versionStatusBadge: some View {
        if item.isCurrent {
            Text("CURRENT")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(Color("Active", bundle: .sharedUI))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color("Green20", bundle: .sharedUI))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        } else {
            Text("HISTORICAL")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(Color("Inactive", bundle: .sharedUI))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color("Orange20", bundle: .sharedUI))
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }
    
    private var itemDetailsView: some View {
        HStack {
            Text(item.itemNumber) // Use non-optional itemNumber
            Spacer()
            pricingInfoView
        }
        .font(.subheadline)
        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
    }
    
    @ViewBuilder
    private var pricingInfoView: some View {
        if !item.regionalPrices.isEmpty {
            VStack(alignment: .trailing) {
                let sortedPrices = item.regionalPrices.sorted { (a, b) in (a.regionIdentifier ?? "") < (b.regionIdentifier ?? "") }
                ForEach(sortedPrices, id: \.id) { priceEntity in
                    let priceText = String(format: "%.2f", priceEntity.amount)
                    let unitText = item.unit ?? ""
                    let regionText = priceEntity.regionIdentifier ?? ""
                    Text("\(regionText): $\(priceText) / \(unitText)")
                }
            }
        } else if item.quoteRequired == true {
            Text("Quote Required")
                .foregroundColor(Color("Inactive", bundle: .sharedUI))
        } else {
            Text("No price data")
        }
    }
    
    @ViewBuilder
    private var itemDescriptionView: some View {
        if !(item.itemDescription ?? "").isEmpty {
            Text(item.itemDescription ?? "")
                .font(.caption)
                .foregroundColor(Color("Archived", bundle: .sharedUI))
                .lineLimit(2)
        }
    }
}
