//
//  CreditHistoryEntry.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import Core
import SwiftData


@Model public class CreditHistoryEntry {
    #Index<CreditHistoryEntry>([\.date], [\.amount], [\.relatedInvoiceNumber])
    public var id: UUID = UUID()
    public var date: Date?
    public var amount: Decimal = 0
    @Attribute(originalName: "type") private var typeData: Data?

    public var type: CreditHistoryType? {
        get { PersistenceAttributeCoder.decodeEnum(from: typeData) }
        set { typeData = PersistenceAttributeCoder.encodeEnum(newValue) }
    }
    public var notes: String?
    public var relatedInvoiceNumber: String?
    @Relationship(deleteRule: .nullify, inverse: \Client.creditHistory) public var client: Client?
    public init(id: UUID = UUID()) {
        self.id = id
    }
}
