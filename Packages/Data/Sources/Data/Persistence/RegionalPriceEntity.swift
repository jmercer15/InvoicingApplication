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
    #Index<RegionalPriceEntity>([\.regionIdentifier], [\.amount])
    public var id: UUID
    public var amount: Double = 0.0
    public var regionIdentifier: String?
    @Relationship(deleteRule: .nullify, inverse: \NDISItemEntity.regionalPrices) public var ndisItem: NDISItemEntity?
    public init(id: UUID) {
        self.id = id
    }
}
