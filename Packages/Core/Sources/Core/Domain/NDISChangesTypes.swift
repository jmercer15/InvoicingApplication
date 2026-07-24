import Foundation

// MARK: - NDIS Change Tracking Types

public enum NDISChangeType: String, Codable, Sendable {
    case newItem = "New Item"
    case removed = "Removed"
    case priceChanged = "Price Changed"
    case registrationChanged = "Registration Changed"
    case featuresChanged = "Features Changed"
    case regionalPricesChanged = "Regional Prices Changed"
    case effectiveDateRangeChanged = "Effective Date Range Changed"
    case nameChanged = "Name Changed"
    case categoryChanged = "Category Changed"
    case unitChanged = "Unit Changed"
    case quoteRequirementChanged = "Quote Requirement Changed"
    case discontinued = "Discontinued"
    case descriptionChanged = "Description Changed"
    case typeChanged = "Type Changed"
    case categoryNumberChanged = "Category Number Changed"
    case categoryNamePACEChanged = "Category Name PACE Changed"
    case categoryNumberPACEChanged = "Category Number PACE Changed"
    case registrationGroupChanged = "Registration Group Changed"
    case registrationGroupNumberChanged = "Registration Group Number Changed"
    case nonFaceToFaceProvisionChanged = "Non Face To Face Provision Changed"
    case providerTravelChanged = "Provider Travel Changed"
    case shortNoticeCancellationsChanged = "Short Notice Cancellations Changed"
    case ndiaRequestedReportsChanged = "NDIA Requested Reports Changed"
    case irregularSILSupportsChanged = "Irregular SIL Supports Changed"
}

public struct NDISChangesSummary: Sendable {
    public let totalUniqueItems: Int
    public let totalVersions: Int
    public let currentItems: Int
    public let historicalItems: Int
    public let itemsWithChanges: Int

    public var changesPercentage: Double {
        guard totalUniqueItems > 0 else { return 0 }
        return Double(itemsWithChanges) / Double(totalUniqueItems) * 100.0
    }

    public init(totalUniqueItems: Int, totalVersions: Int, currentItems: Int, historicalItems: Int, itemsWithChanges: Int) {
        self.totalUniqueItems = totalUniqueItems
        self.totalVersions = totalVersions
        self.currentItems = currentItems
        self.historicalItems = historicalItems
        self.itemsWithChanges = itemsWithChanges
    }
}


public struct NDISItemChange: Sendable {
    public let itemNumber: String
    public let changeDate: Date
    public let previousVersion: NDISItemSnapshot
    public let newVersion: NDISItemSnapshot
    public let changeType: NDISChangeType

    public init(itemNumber: String, changeDate: Date, previousVersion: NDISItemSnapshot, newVersion: NDISItemSnapshot, changeType: NDISChangeType) {
        self.itemNumber = itemNumber
        self.changeDate = changeDate
        self.previousVersion = previousVersion
        self.newVersion = newVersion
        self.changeType = changeType
    }
}
