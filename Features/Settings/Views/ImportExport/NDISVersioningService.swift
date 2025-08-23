import Foundation
import SwiftData // Import SwiftData

/// Service for managing NDIS item versioning and historical tracking
class NDISVersioningService {
    
    // MARK: - Current Item Determination
    
    /// Determines if an NDIS item is currently effective based on its effective date range.
    /// This checks if an item is effective on a given date, not if it's part of the current dataset.
    /// For current dataset determination, use updateCurrentStatusForAllItems() which sets isCurrent flags.
    static func isItemCurrent(_ item: NDISItemEntity, asOf date: Date = Date()) -> Bool { // Change to NDISItemEntity
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
    
    /// Updates the isCurrent flag for all NDIS items based on the most recent effective start date
    /// Items with the most recent effective start date are marked as current, all others as historical
    static func updateCurrentStatusForAllItems(in context: ModelContext, asOf date: Date = Date()) throws { // Change to ModelContext
        let descriptor = FetchDescriptor<NDISItemEntity>() // Fetch all NDISItemEntity
        let allItems = try context.fetch(descriptor)
        
        // Find the most recent effective start date across all items
        let mostRecentEffectiveDate = findMostRecentEffectiveStartDate(from: allItems)
        
        guard let mostRecent = mostRecentEffectiveDate else {
            // If no items have effective start dates, mark all as current for backward compatibility
            for item in allItems {
                item.isCurrent = true
            }
            try context.save()
            return
        }
        
        // Set isCurrent based on whether the item's effective start date matches the most recent
        for item in allItems {
            let itemStartDate = item.effectiveStartDate // Use non-optional
            let isCurrent = itemStartDate == mostRecent
            item.isCurrent = isCurrent
        }
        
        try context.save()
        
        print("Updated current status: \(allItems.filter { $0.isCurrent }.count) items marked as current with effective date \(DateFormatter.logFormatter.string(from: mostRecent))")
    }
    
    /// Finds the most recent effective start date from a collection of NDIS items
    private static func findMostRecentEffectiveStartDate(from items: [NDISItemEntity]) -> Date? { // Change to NDISItemEntity
        var mostRecentDate: Date?
        
        for item in items {
            let startDate = item.effectiveStartDate ?? Date() // Use optional with default
            if mostRecentDate == nil || startDate > mostRecentDate! {
                mostRecentDate = startDate
            }
        }
        
        return mostRecentDate
    }
    
    /// Convenience method to manually update current status - useful for testing or corrections
    static func recalculateAllCurrentFlags(in context: ModelContext) throws { // Change to ModelContext
        print("Manually recalculating isCurrent flags for all NDIS items...")
        try updateCurrentStatusForAllItems(in: context)
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
    
    /// Creates a composite key for uniquely identifying an NDIS item
    static func createCompositeKey(itemNumber: String, itemName: String) -> String {
        return "\(itemNumber)_\(itemName.hash.magnitude)"
    }
    
    /// Finds all versions of an NDIS item by composite key (item number + name)
    static func findAllVersions(itemNumber: String, itemName: String, in context: ModelContext) throws -> [NDISItemEntity] { // Change to ModelContext and NDISItemEntity
        let descriptor = FetchDescriptor<NDISItemEntity>(predicate: #Predicate {
            $0.itemNumber == itemNumber && $0.name == itemName
        }, sortBy: [
            SortDescriptor(\.effectiveStartDate, order: .reverse),
            SortDescriptor(\.effectiveEndDate, order: .reverse)
        ])
        
        return try context.fetch(descriptor)
    }
    
    /// Legacy method - finds all versions by item number only (may return multiple different items)
    static func findAllVersionsByItemNumber(of itemNumber: String, in context: ModelContext) throws -> [NDISItemEntity] { // Change to ModelContext and NDISItemEntity
        let descriptor = FetchDescriptor<NDISItemEntity>(predicate: #Predicate {
            $0.itemNumber == itemNumber
        }, sortBy: [
            SortDescriptor(\.name, order: .forward),
            SortDescriptor(\.effectiveStartDate, order: .reverse),
            SortDescriptor(\.effectiveEndDate, order: .reverse)
        ])
        
        return try context.fetch(descriptor)
    }
    
    /// Gets the current version of an NDIS item using composite key
    static func getCurrentVersion(itemNumber: String, itemName: String, in context: ModelContext, asOf date: Date = Date()) throws -> NDISItemEntity? { // Change to ModelContext and NDISItemEntity
        let allVersions = try findAllVersions(itemNumber: itemNumber, itemName: itemName, in: context)
        return allVersions.first { isItemCurrent($0, asOf: date) }
    }
    
    /// Gets all current NDIS items (only the current versions)
    static func getCurrentItems(in context: ModelContext, asOf date: Date = Date()) throws -> [NDISItemEntity] { // Change to ModelContext and NDISItemEntity
        let descriptor = FetchDescriptor<NDISItemEntity>(predicate: #Predicate {
            $0.isCurrent == true
        }, sortBy: [SortDescriptor(\.itemNumber, order: .forward)])
        
        return try context.fetch(descriptor)
    }
    
    // MARK: - Historical Analysis
    
    /// Analyzes how an NDIS item has changed over time
    static func analyzeItemChanges(itemNumber: String, in context: ModelContext) throws -> [NDISItemChange] { // Change to ModelContext
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
    static func getChangesSummary(in context: ModelContext) throws -> NDISChangesSummary { // Change to ModelContext
        let descriptor = FetchDescriptor<NDISItemEntity>() // Fetch all NDISItemEntity
        let allItems = try context.fetch(descriptor)
        
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
                if isItemCurrent(version) {
                    currentItems += 1
                } else {
                    historicalItems += 1
                }
            }
        }
        
        return NDISChangesSummary(
            totalUniqueItems: groupedItems.count,
            totalVersions: totalItems,
            currentItems: currentItems,
            historicalItems: historicalItems,
            itemsWithChanges: itemsWithChanges
        )
    }
    
    // MARK: - Private Helpers
    
    private static func extractItemData(from item: NDISItemEntity) -> NDISItemSnapshot { // Change to NDISItemEntity
        return NDISItemSnapshot(
            name: item.name,
            category: item.category ?? "",
            categoryNamePACE: item.categoryNamePACE ?? "",
            categoryNumber: item.categoryNumber ?? "",
            categoryNumberPACE: item.categoryNumberPACE ?? "",
            registrationGroup: item.registrationGroup ?? "",
            registrationGroupNumber: item.registrationGroupNumber ?? "",
            unit: item.unit ?? "",
            itemDescription: item.itemDescription ?? "",
            features: item.features?.components(separatedBy: ",").filter { !$0.isEmpty } ?? [],
            quoteRequired: item.quoteRequired ?? false,
            type: item.type ?? "",
            nonFaceToFaceProvision: item.nonFaceToFaceProvision ?? false,
            providerTravel: item.providerTravel ?? false,
            shortNoticeCancellations: item.shortNoticeCancellations ?? false,
            ndiaRequestedReports: item.ndiaRequestedReports ?? false,
            irregularSILSupports: item.irregularSILSupports ?? false,
            effectiveStartDate: item.effectiveStartDate ?? Date(),
            effectiveEndDate: item.effectiveEndDate,
            isCurrent: item.isCurrent,
            versionIdentifier: item.versionIdentifier
        )
    }
    
    private static func determineChangeType(from previous: NDISItemEntity, to current: NDISItemEntity) -> NDISChangeType { // Change to NDISItemEntity

        if previous.name != current.name { return .nameChanged }
        if previous.category != current.category { return .categoryChanged }
        if previous.unit != current.unit { return .unitChanged }
        if previous.quoteRequired != current.quoteRequired { return .quoteRequirementChanged }
        
        // New comparisons for other attributes (ensure these are added to NDISChangeType enum)
        if previous.itemDescription != current.itemDescription { return .descriptionChanged }
        if previous.type != current.type { return .typeChanged }
        if previous.categoryNumber != current.categoryNumber { return .categoryNumberChanged }
        if previous.categoryNamePACE != current.categoryNamePACE { return .categoryNamePACEChanged }
        if previous.categoryNumberPACE != current.categoryNumberPACE { return .categoryNumberPACEChanged }
        if previous.registrationGroup != current.registrationGroup { return .registrationGroupChanged }
        if previous.registrationGroupNumber != current.registrationGroupNumber { return .registrationGroupNumberChanged }
        if previous.nonFaceToFaceProvision != current.nonFaceToFaceProvision { return .nonFaceToFaceProvisionChanged }
        if previous.providerTravel != current.providerTravel { return .providerTravelChanged }
        if previous.shortNoticeCancellations != current.shortNoticeCancellations { return .shortNoticeCancellationsChanged }
        if previous.ndiaRequestedReports != current.ndiaRequestedReports { return .ndiaRequestedReportsChanged }
        if previous.irregularSILSupports != current.irregularSILSupports { return .irregularSILSupportsChanged }
        if previous.regionalPrices != current.regionalPrices { return .regionalPricesChanged }
        
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
    public static func setCurrentStatus(forEffectiveDates dates: Set<Date>, in context: ModelContext) throws -> (updatedCount: Int, totalCount: Int) { // Change to ModelContext
        let fetchRequest = FetchDescriptor<NDISItemEntity>() // Fetch all NDISItemEntity
        let allItems = try context.fetch(fetchRequest)

        guard !allItems.isEmpty else { return (0, 0) }

        var updatedCount = 0
        let calendar = Calendar.current
        let startOfDates = Set(dates.map { calendar.startOfDay(for: $0) })

        for item in allItems {
            let wasCurrent = item.isCurrent
            var isNowCurrent = false
            
            let itemEffectiveDate = item.effectiveStartDate ?? Date() // Use optional with default
            if startOfDates.contains(calendar.startOfDay(for: itemEffectiveDate)) {
                isNowCurrent = true
            }
            
            if wasCurrent != isNowCurrent {
                item.isCurrent = isNowCurrent
                updatedCount += 1
            }
        }

        if updatedCount > 0 {
            try context.save()
        }
        
        return (updatedCount, allItems.count)
    }
}

// MARK: - Supporting Data Structures

struct NDISItemChange {
    let itemNumber: String
    let changeDate: Date
    let previousVersion: NDISItemSnapshot
    let newVersion: NDISItemSnapshot
    let changeType: NDISChangeType
}

struct NDISItemSnapshot {
    let name: String
    let category: String
    let categoryNamePACE: String
    let categoryNumber: String
    let categoryNumberPACE: String
    let registrationGroup: String
    let registrationGroupNumber: String
    let unit: String
    let itemDescription: String
    let features: [String]
    let quoteRequired: Bool
    let type: String
    let nonFaceToFaceProvision: Bool
    let providerTravel: Bool
    let shortNoticeCancellations: Bool
    let ndiaRequestedReports: Bool
    let irregularSILSupports: Bool
    let effectiveStartDate: Date
    let effectiveEndDate: Date?
    let isCurrent: Bool
    let versionIdentifier: String
}

enum NDISChangeType: String, CaseIterable {
    case nameChanged = "Name Changed"
    case categoryChanged = "Category Changed"
    case unitChanged = "Unit Changed"
    case quoteRequirementChanged = "Quote Requirement Changed"
    case priceChanged = "Price Changed"
    case newItem = "New Item"
    case discontinued = "Discontinued"
    
    // New cases for additional attribute comparisons
    case descriptionChanged = "Description Changed"
    case typeChanged = "Type Changed"
    case categoryNumberChanged = "Category Number Changed"
    case categoryNamePACEChanged = "PACE Category Changed"
    case categoryNumberPACEChanged = "PACE Category # Changed"
    case registrationGroupChanged = "Registration Group Changed"
    case registrationGroupNumberChanged = "Registration Group # Changed"
    case nonFaceToFaceProvisionChanged = "Non-Face-to-Face Provision Changed"
    case providerTravelChanged = "Provider Travel Changed"
    case shortNoticeCancellationsChanged = "Short Notice Cancellations Changed"
    case ndiaRequestedReportsChanged = "NDIA Reports Changed"
    case irregularSILSupportsChanged = "Irregular SIL Supports Changed"
    case regionalPricesChanged = "Regional Prices Changed"
    case featuresChanged = "Features Changed"
    case effectiveDateRangeChanged = "Effective Date Range Changed"
}

struct NDISChangesSummary {
    let totalUniqueItems: Int
    let totalVersions: Int
    let currentItems: Int
    let historicalItems: Int
    let itemsWithChanges: Int
    
    var changesPercentage: Double {
        guard totalUniqueItems > 0 else { return 0 }
        return Double(itemsWithChanges) / Double(totalUniqueItems) * 100
    }
}

// MARK: - Date Formatting Extension
extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
} 