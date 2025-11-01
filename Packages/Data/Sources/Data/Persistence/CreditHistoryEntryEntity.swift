//
//  CreditHistoryEntryEntity.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class CreditHistoryEntryEntity {
    public var id: UUID
    public var date: Date?
    public var amount: Double = 0.0
    public var type: String?
    public var notes: String?
    public var relatedInvoiceNumber: String?
    @Relationship(deleteRule: .nullify, inverse: \ClientEntity.creditHistory) public var client: ClientEntity?
    public init(id: UUID) {
        self.id = id
    }
}
