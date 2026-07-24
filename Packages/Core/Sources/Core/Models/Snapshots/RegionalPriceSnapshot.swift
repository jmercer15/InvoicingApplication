//
//  RegionalPriceSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation
import SwiftData

// MARK: - RegionalPriceSnapshot

public struct RegionalPriceSnapshot: Sendable, Equatable, Hashable {
    public let id: UUID
    public let amount: Double
    public let regionIdentifier: String?

    public init(id: UUID, amount: Double, regionIdentifier: String?) {
        self.id = id
        self.amount = amount
        self.regionIdentifier = regionIdentifier
    }

    public init(_ price: RegionalPrice) {
        self.id = price.id
        self.amount = price.amount
        self.regionIdentifier = price.regionIdentifier
    }
}

