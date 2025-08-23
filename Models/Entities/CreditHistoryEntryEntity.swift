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
    var date: Date?
    var amount: Double = 0.0
    var type: String?
    var notes: String?
    var relatedInvoiceNumber: String?
    @Relationship(deleteRule: .nullify, inverse: \ClientEntity.creditHistory) var client: ClientEntity?
    public init(id: UUID) {
        self.id = id
    }
}
