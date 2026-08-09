//
//  RegionalPriceSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation

// MARK: - RegionalPriceSnapshot

public struct RegionalPriceSnapshot: Sendable, Equatable, Hashable {
    public let id: UUID
    public let amount: Decimal
    public let regionIdentifier: String?

    public init(id: UUID, amount: Decimal, regionIdentifier: String?) {
        self.id = id
        self.amount = amount
        self.regionIdentifier = regionIdentifier
    }

}

