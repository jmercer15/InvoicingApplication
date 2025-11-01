//
//  NDISItemEntity.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class NDISItemEntity: @unchecked Sendable {
    #Index<NDISItemEntity>([\.itemNumber], [\.name], [\.isCurrent], [\.category], [\.registrationGroup], [\.effectiveStartDate], [\.effectiveEndDate], [\.itemDescription], [\.quoteRequired], [\.status], [\.type])
    
    public var itemNumber: String
    public var name: String
    @Attribute(.unique) public var versionIdentifier: String
    public var id: UUID
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
    public var regionalPrices: [RegionalPriceEntity] = []
    @Relationship(deleteRule: .nullify) var clientServices: [ClientServiceEntity] = []
    public init(id: UUID, itemNumber: String, name: String, versionIdentifier: String) {
        self.id = id
        self.itemNumber = itemNumber
        self.name = name
        self.versionIdentifier = versionIdentifier
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
}

