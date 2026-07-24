//
//  NDISItemSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation
import SwiftData

// MARK: - NDISItemSnapshot

public struct NDISItemSnapshot: Sendable, Equatable, Hashable {
    public let itemNumber: String
    public let name: String
    public let versionIdentifier: String
    public let id: UUID
    public let isCurrent: Bool
    public let category: String?
    public let categoryNamePACE: String?
    public let categoryNumber: String?
    public let categoryNumberPACE: String?
    public let effectiveStartDate: Date?
    public let effectiveEndDate: Date?
    public let features: String?
    public let itemDescription: String?
    public let ndiaRequestedReports: Bool?
    public let nonFaceToFaceProvision: Bool?
    public let providerTravel: Bool?
    public let quoteRequired: Bool?
    public let registrationGroup: String?
    public let registrationGroupNumber: String?
    public let shortNoticeCancellations: Bool?
    public let irregularSILSupports: Bool?
    public let status: String?
    public let type: String?
    public let unit: String?
    public let regionalPrices: [RegionalPriceSnapshot]
    /// Flat convenience price (mirrors `NDISItem.price` heuristics).
    public let price: Double?
    public let effectiveDateRange: String

    public init(
        itemNumber: String,
        name: String,
        versionIdentifier: String,
        id: UUID,
        isCurrent: Bool,
        category: String?,
        categoryNamePACE: String?,
        categoryNumber: String?,
        categoryNumberPACE: String?,
        effectiveStartDate: Date?,
        effectiveEndDate: Date?,
        features: String?,
        itemDescription: String?,
        ndiaRequestedReports: Bool?,
        nonFaceToFaceProvision: Bool?,
        providerTravel: Bool?,
        quoteRequired: Bool?,
        registrationGroup: String?,
        registrationGroupNumber: String?,
        shortNoticeCancellations: Bool?,
        irregularSILSupports: Bool?,
        status: String?,
        type: String?,
        unit: String?,
        regionalPrices: [RegionalPriceSnapshot],
        price: Double?,
        effectiveDateRange: String
    ) {
        self.itemNumber = itemNumber
        self.name = name
        self.versionIdentifier = versionIdentifier
        self.id = id
        self.isCurrent = isCurrent
        self.category = category
        self.categoryNamePACE = categoryNamePACE
        self.categoryNumber = categoryNumber
        self.categoryNumberPACE = categoryNumberPACE
        self.effectiveStartDate = effectiveStartDate
        self.effectiveEndDate = effectiveEndDate
        self.features = features
        self.itemDescription = itemDescription
        self.ndiaRequestedReports = ndiaRequestedReports
        self.nonFaceToFaceProvision = nonFaceToFaceProvision
        self.providerTravel = providerTravel
        self.quoteRequired = quoteRequired
        self.registrationGroup = registrationGroup
        self.registrationGroupNumber = registrationGroupNumber
        self.shortNoticeCancellations = shortNoticeCancellations
        self.irregularSILSupports = irregularSILSupports
        self.status = status
        self.type = type
        self.unit = unit
        self.regionalPrices = regionalPrices
        self.price = price
        self.effectiveDateRange = effectiveDateRange
    }

    public init(
        id: UUID,
        itemNumber: String,
        name: String,
        versionIdentifier: String,
        isCurrent: Bool,
        category: String?,
        effectiveStartDate: Date?,
        effectiveEndDate: Date?,
        features: String?,
        itemDescription: String?,
        ndiaRequestedReports: Bool?,
        nonFaceToFaceProvision: Bool?,
        providerTravel: Bool?,
        quoteRequired: Bool?,
        registrationGroup: String?,
        registrationGroupNumber: String?,
        shortNoticeCancellations: Bool?,
        irregularSILSupports: Bool?,
        status: String?,
        type: String?,
        unit: String?,
        regionalPrices: [RegionalPriceSnapshot],
        price: Double?,
        effectiveDateRange: String
    ) {
        self.init(
            itemNumber: itemNumber,
            name: name,
            versionIdentifier: versionIdentifier,
            id: id,
            isCurrent: isCurrent,
            category: category,
            categoryNamePACE: nil,
            categoryNumber: nil,
            categoryNumberPACE: nil,
            effectiveStartDate: effectiveStartDate,
            effectiveEndDate: effectiveEndDate,
            features: features,
            itemDescription: itemDescription,
            ndiaRequestedReports: ndiaRequestedReports,
            nonFaceToFaceProvision: nonFaceToFaceProvision,
            providerTravel: providerTravel,
            quoteRequired: quoteRequired,
            registrationGroup: registrationGroup,
            registrationGroupNumber: registrationGroupNumber,
            shortNoticeCancellations: shortNoticeCancellations,
            irregularSILSupports: irregularSILSupports,
            status: status,
            type: type,
            unit: unit,
            regionalPrices: regionalPrices,
            price: price,
            effectiveDateRange: effectiveDateRange
        )
    }

    public init(_ item: NDISItem) {
        self.itemNumber = item.itemNumber
        self.name = item.name
        self.versionIdentifier = item.versionIdentifier
        self.id = item.id
        self.isCurrent = item.isCurrent
        self.category = item.category
        self.categoryNamePACE = item.categoryNamePACE
        self.categoryNumber = item.categoryNumber
        self.categoryNumberPACE = item.categoryNumberPACE
        self.effectiveStartDate = item.effectiveStartDate
        self.effectiveEndDate = item.effectiveEndDate
        self.features = item.features
        self.itemDescription = item.itemDescription
        self.ndiaRequestedReports = item.ndiaRequestedReports
        self.nonFaceToFaceProvision = item.nonFaceToFaceProvision
        self.providerTravel = item.providerTravel
        self.quoteRequired = item.quoteRequired
        self.registrationGroup = item.registrationGroup
        self.registrationGroupNumber = item.registrationGroupNumber
        self.shortNoticeCancellations = item.shortNoticeCancellations
        self.irregularSILSupports = item.irregularSILSupports
        self.status = item.status
        self.type = item.type
        self.unit = item.unit
        self.regionalPrices = (item.regionalPrices ?? []).map(RegionalPriceSnapshot.init)
        self.price = item.price
        self.effectiveDateRange = item.effectiveDateRange
    }
}

