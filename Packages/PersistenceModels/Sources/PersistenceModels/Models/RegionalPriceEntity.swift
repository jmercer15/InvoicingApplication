//
//  RegionalPrice.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import Core
import SwiftData


@Model public class RegionalPrice {
    #Index<RegionalPrice>([\.regionIdentifier], [\.amount])
    public var id: UUID = UUID()
    public var amount: Decimal = 0
    public var regionIdentifier: String?
    @Relationship(deleteRule: .nullify, inverse: \NDISItem.regionalPrices) public var ndisItem: NDISItem?
    public init(id: UUID = UUID()) {
        self.id = id
    }
    
    /// Returns a thread-safe snapshot of the RegionalPrice.
    public func snapshot() -> RegionalPriceSnapshot {
        RegionalPriceSnapshot(self)
    }
}
