//
//  NDISItem.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class NDISItem {
    #Index<NDISItem>([\.itemNumber], [\.name], [\.isCurrent], [\.category], [\.registrationGroup], [\.effectiveStartDate], [\.effectiveEndDate], [\.itemDescription], [\.quoteRequired], [\.status], [\.type])
    
    public var itemNumber: String = ""
    public var name: String = ""
    public var versionIdentifier: String = ""
    public var id: UUID = UUID()
    public var isCurrent: Bool = true
    public var category: String?
    public var categoryNamePACE: String?
    public var categoryNumber: String?
    public var categoryNumberPACE: String?
    public var effectiveStartDate: Date?
    public var effectiveEndDate: Date?
    public var features: String?
    public var itemDescription: String?
    public var ndiaRequestedReports: Bool?
    public var nonFaceToFaceProvision: Bool?
    public var providerTravel: Bool?
    public var quoteRequired: Bool?
    public var registrationGroup: String?
    public var registrationGroupNumber: String?
    public var shortNoticeCancellations: Bool?
    public var irregularSILSupports: Bool?
    public var status: String?
    public var type: String?
    public var unit: String?
    public var regionalPrices: [RegionalPrice]?
    @Relationship(deleteRule: .nullify) var clientServices: [ClientService]?
    public init(
        id: UUID = UUID(),
        itemNumber: String = "",
        name: String = "",
        versionIdentifier: String = "",
        category: String? = nil,
        itemDescription: String? = nil,
        unit: String? = nil,
        status: String? = nil,
        nonFaceToFaceProvision: Bool? = nil,
        quoteRequired: Bool? = nil,
        effectiveStartDate: Date? = nil,
        effectiveEndDate: Date? = nil
    ) {
        self.id = id
        self.itemNumber = itemNumber
        self.name = name
        self.versionIdentifier = versionIdentifier
        self.category = category
        self.itemDescription = itemDescription
        self.unit = unit
        self.status = status
        self.nonFaceToFaceProvision = nonFaceToFaceProvision
        self.quoteRequired = quoteRequired
        self.effectiveStartDate = effectiveStartDate
        self.effectiveEndDate = effectiveEndDate
    }

    /// Returns a thread-safe snapshot of this NDIS item.
    public func snapshot() -> NDISItemSnapshot {
        NDISItemSnapshot(self)
    }
    
    // MARK: - Computed Properties
    
    public var effectiveDateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if let startDate = effectiveStartDate, let endDate = effectiveEndDate {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        } else if let startDate = effectiveStartDate {
            return "From \(formatter.string(from: startDate))"
        } else if let endDate = effectiveEndDate {
            return "Until \(formatter.string(from: endDate))"
        } else {
            return "No date range"
        }
    }

    /// Convenience flat price accessor relying on Regional Prices.
    public var price: Double? {
        if let basePrice = regionalPrices?.first(where: { $0.regionIdentifier == "National" })?.amount {
            return basePrice
        }
        return regionalPrices?.first?.amount
    }
}

