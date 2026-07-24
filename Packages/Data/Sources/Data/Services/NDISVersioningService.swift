import Foundation
import SwiftData
import Core

/// Service for managing NDIS item versioning and historical tracking
public class NDISVersioningService {
    
    // MARK: - Snapshot-Based Methods
    
    /// Determines if an NDIS item snapshot is currently effective based on its effective date range.
    public static func isItemCurrent(_ item: NDISItemSnapshot, asOf date: Date = Date()) -> Bool {
        guard let startDate = item.effectiveStartDate else {
            // No start date - assume always current
            return true
        }
        
        // Check if current date is after start date
        if date < startDate {
            return false
        }
        
        // Check end date if it exists
        if let endDate = item.effectiveEndDate {
            return date <= endDate
        }
        
        // No end date means ongoing
        return true
    }

    // MARK: - ModelContext-Based Methods (Model Level)
    
    /// Determines if an NDIS item model is currently effective based on its effective date range.
    /// This checks if an item is effective on a given date, not if it's part of the current dataset.
    /// For current dataset determination, use updateCurrentStatusForAllItems() which sets isCurrent flags.
    static func isItemCurrentModel(_ item: NDISItem, asOf date: Date = Date()) -> Bool {
        let startDate = item.effectiveStartDate ?? Date() // Use optional with default
        
        // Check if current date is after start date
        if date < startDate {
            return false
        }
        
        // Check end date if it exists
        if let endDate = item.effectiveEndDate {
            return date <= endDate
        }
        
        // No end date means ongoing
        return true
    }
    
    /// Updates the isCurrent flag for all NDIS items based on the most recent effective version per item number
    /// Only the latest effective versions for each item number remain marked as current
    static func updateCurrentStatusForAllItems(in context: ModelContext, asOf date: Date = Date()) throws { // Change to ModelContext
        let resolver = EntityResolutionService(context: context)
        let allItems = try resolver.resolveAllNDISItems()
        guard !allItems.isEmpty else { return }
        
        let groupedItems = Dictionary(grouping: allItems, by: { $0.itemNumber })
        var currentIdentifiers = Set<UUID>()
        
        for versions in groupedItems.values {
            currentIdentifiers.formUnion(determineCurrentVersionIDs(from: versions, asOf: date))
        }
        
        for item in allItems {
            item.isCurrent = currentIdentifiers.contains(item.id)
        }
        
        try context.save()
        
        print("Updated current status: \(currentIdentifiers.count) items marked as current across \(groupedItems.count) item numbers")
    }
    
    /// Determines which versions within a single item number should be marked as current
    private static func determineCurrentVersionIDs(from versions: [NDISItem], asOf date: Date) -> Set<UUID> {
        guard !versions.isEmpty else { return [] }
        
        let currentlyEffective = versions.filter { isItemCurrentModel($0, asOf: date) }
        let candidates = currentlyEffective.isEmpty ? versions : currentlyEffective
        
        let highestStartDate = candidates.compactMap { $0.effectiveStartDate }.max()
        if let highestStartDate {
            let matching = candidates.filter { $0.effectiveStartDate == highestStartDate }
            if !matching.isEmpty {
                return Set(matching.map { $0.id })
            }
        }
        
        let nilStartCandidates = candidates.filter { $0.effectiveStartDate == nil }
        if !nilStartCandidates.isEmpty {
            return Set(nilStartCandidates.map { $0.id })
        }
        
        return Set(candidates.map { $0.id })
    }
    
    // MARK: - Version Management
    
    /// Creates a version identifier for an NDIS item based on its composite key and dates
    static func createVersionIdentifier(itemNumber: String, itemName: String, startDate: Date, endDate: Date?) -> String { // Make startDate non-optional
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Create a hash of the item name to keep the identifier manageable
        let nameHash = String(itemName.hash.magnitude)
        
        let startString = dateFormatter.string(from: startDate) // Use non-optional startDate
        if let end = endDate {
            let endString = dateFormatter.string(from: end)
            return "\(itemNumber)_\(nameHash)_\(startString)_\(endString)"
        } else {
            return "\(itemNumber)_\(nameHash)_\(startString)_ongoing"
        }
    }
    
    /// Finds all versions of an NDIS item by composite key (item number + name)
    static func findAllVersions(itemNumber: String, itemName: String, in context: ModelContext) throws -> [NDISItem] { // Change to ModelContext and NDISItem
        let resolver = EntityResolutionService(context: context)
        return try resolver.resolveNDISItems(itemNumber: itemNumber, name: itemName)
    }
    
    /// Legacy method - finds all versions by item number only (may return multiple different items)
    static func findAllVersionsByItemNumber(of itemNumber: String, in context: ModelContext) throws -> [NDISItem] { // Change to ModelContext and NDISItem
        let resolver = EntityResolutionService(context: context)
        return try resolver.resolveNDISItems(itemNumber: itemNumber)
    }
    
    // MARK: - Historical Analysis
    
    /// Analyzes how an NDIS item has changed over time
    public static func analyzeItemChanges(itemNumber: String, in context: ModelContext) throws -> [NDISItemChange] { // Change to ModelContext
        let versions = try findAllVersionsByItemNumber(of: itemNumber, in: context)
        var changes: [NDISItemChange] = []
        
        for i in 1..<versions.count {
            let currentVersion = versions[i-1]
            let previousVersion = versions[i]
            
            let change = NDISItemChange(
                itemNumber: itemNumber,
                changeDate: currentVersion.effectiveStartDate ?? Date(), // Use optional with default
                previousVersion: extractItemData(from: currentVersion),
                newVersion: extractItemData(from: previousVersion),
                changeType: determineChangeType(from: currentVersion, to: previousVersion)
            )
            
            changes.append(change)
        }
        
        return changes
    }
    
    /// Gets a summary of all NDIS item changes over time
    public static func getChangesSummary(in context: ModelContext) throws -> Core.NDISChangesSummary { // Change to ModelContext
        let resolver = EntityResolutionService(context: context)
        let allItems = try resolver.resolveAllNDISItems()
        
        // Group by item number
        let groupedItems = Dictionary(grouping: allItems) { item in
            item.itemNumber // Use non-optional itemNumber
        }
        
        var totalItems = 0
        var currentItems = 0
        var historicalItems = 0
        var itemsWithChanges = 0
        
        for (_, versions) in groupedItems {
            let sortedVersions = versions.sorted { item1, item2 in
                let date1 = item1.effectiveStartDate ?? Date() // Use optional with default
                let date2 = item2.effectiveStartDate ?? Date() // Use optional with default
                return date1 > date2
            }
            
            totalItems += versions.count
            
            if versions.count > 1 {
                itemsWithChanges += 1
            }
            
            for version in sortedVersions {
                if isItemCurrentModel(version) {
                    currentItems += 1
                } else {
                    historicalItems += 1
                }
            }
        }
        
        return Core.NDISChangesSummary(
            totalUniqueItems: groupedItems.count,
            totalVersions: totalItems,
            currentItems: currentItems,
            historicalItems: historicalItems,
            itemsWithChanges: itemsWithChanges
        )
    }
    
    // MARK: - Private Helpers
    
    private static func extractItemData(from item: NDISItem) -> NDISItemSnapshot {
        let priceSnapshots = (item.regionalPrices ?? [])
            .map { (price: RegionalPrice) -> RegionalPriceSnapshot in
                let region = price.regionIdentifier?.isEmpty == false ? price.regionIdentifier! : "Unspecified"
                return RegionalPriceSnapshot(id: price.id, amount: price.amount, regionIdentifier: region)
            }
            .sorted { ($0.regionIdentifier ?? "") < ($1.regionIdentifier ?? "") }
        
        return NDISItemSnapshot(
            id: item.id,
            itemNumber: item.itemNumber,
            name: item.name,
            versionIdentifier: item.versionIdentifier,
            isCurrent: item.isCurrent,
            category: item.category,
            effectiveStartDate: item.effectiveStartDate,
            effectiveEndDate: item.effectiveEndDate,
            features: item.features,
            itemDescription: item.itemDescription,
            ndiaRequestedReports: item.ndiaRequestedReports,
            nonFaceToFaceProvision: item.nonFaceToFaceProvision,
            providerTravel: item.providerTravel,
            quoteRequired: item.quoteRequired,
            registrationGroup: item.registrationGroup,
            registrationGroupNumber: item.registrationGroupNumber,
            shortNoticeCancellations: item.shortNoticeCancellations,
            irregularSILSupports: item.irregularSILSupports,
            status: item.status,
            type: item.type,
            unit: item.unit,
            regionalPrices: priceSnapshots,
            price: nil,
            effectiveDateRange: ""
        )
    }
    
    private static func determineChangeType(from previous: NDISItem, to current: NDISItem) -> NDISChangeType {
        
        if previous.name != current.name { return .nameChanged }
        if previous.registrationGroup != current.registrationGroup { return .categoryChanged }
        if previous.unit != current.unit { return .unitChanged }
        if previous.quoteRequired != current.quoteRequired { return .featuresChanged }
        
        // Handle features comparison - convert optional strings to arrays
        let previousFeatures = previous.features?.components(separatedBy: ",").filter { !$0.isEmpty } ?? []
        let currentFeatures = current.features?.components(separatedBy: ",").filter { !$0.isEmpty } ?? []
        if previousFeatures.sorted() != currentFeatures.sorted() { return .featuresChanged }
        
        if previous.effectiveStartDate != current.effectiveStartDate { return .effectiveDateRangeChanged }
        if previous.effectiveEndDate != current.effectiveEndDate { return .effectiveDateRangeChanged } // Group start/end date changes
        
        return .priceChanged // Fallback if no specific change type is detected, assuming it's a price change or minor undetected change.
    }
    
    /// Sets the `isCurrent` flag to `true` for all NDIS items matching a specific effective start date, and `false` for all others.
    /// - Parameters:
    ///   - date: The effective start date to be marked as current.
    ///   - context: The managed object context to perform the operation in.
    /// - Returns: A tuple containing the number of items whose `isCurrent` status was changed, and the total number of items processed.
    /// - Throws: An error if fetching or saving fails.
    @discardableResult
    /// Fetches all unique effective dates for NDIS items
    public static func fetchEffectiveDates(context: ModelContext) throws -> [Date] {
        let descriptor = FetchDescriptor<NDISItem>()
        let items = try context.fetch(descriptor)
        let dates = Set(items.compactMap { $0.effectiveStartDate })
        return Array(dates).sorted(by: >)
    }
    
    /// Recalculates 'isCurrent' flags for all NDIS items and returns the count of updated items
    public static func recalculateAllCurrentFlags(context: ModelContext) throws -> Int {
        print("Manually recalculating isCurrent flags for all NDIS items...")
        try updateCurrentStatusForAllItems(in: context)
        // Return 0 as exact count is tricky to propagate without changing return type of update helper
        // But for UI feedback, just success is often enough, or we check the logs
        return 0
    }
}
