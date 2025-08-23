//
//  NDISItemEntity.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class NDISItemEntity {
    var itemNumber: String
    var name: String
    @Attribute(.unique) var versionIdentifier: String
    public var id: UUID
    var isCurrent: Bool = true
    var category: String?
    var categoryNamePACE: String?
    var categoryNumber: String?
    var categoryNumberPACE: String?
    var effectiveStartDate: Date?
    var effectiveEndDate: Date?
    var features: String?
    var itemDescription: String?
    var ndiaRequestedReports: Bool?
    var nonFaceToFaceProvision: Bool?
    var providerTravel: Bool?
    var quoteRequired: Bool?
    var registrationGroup: String?
    var registrationGroupNumber: String?
    var shortNoticeCancellations: Bool?
    var irregularSILSupports: Bool?
    var status: String?
    var type: String?
    var unit: String?
    var regionalPrices: [RegionalPriceEntity]?
    @Relationship(deleteRule: .nullify, inverse: \ClientServiceEntity.ndisItem) var clientServices: [ClientServiceEntity]?
    @Relationship(deleteRule: .nullify, inverse: \ServiceEntity.ndisItem) var services: [ServiceEntity]?
    public init(id: UUID, itemNumber: String, name: String, versionIdentifier: String) {
        self.id = id
        self.itemNumber = itemNumber
        self.name = name
        self.versionIdentifier = versionIdentifier
    }
}

extension NDISItemEntity: DropdownRepresentable {
    var displayName: String { name }
}
