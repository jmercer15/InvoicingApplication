//
//  RegionalPriceEntity.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class RegionalPriceEntity {
    public var id: UUID
    var amount: Double = 0.0
    var regionIdentifier: String?
    @Relationship(deleteRule: .nullify, inverse: \NDISItemEntity.regionalPrices) var ndisItem: NDISItemEntity?
    public init(id: UUID) {
        self.id = id
    }
}
