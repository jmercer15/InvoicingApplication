//
//  ExpenseEntity.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class ExpenseEntity {
    public var id: UUID
    var date: Date?
    var name: String = ""
    var amount: Double = 0.0
    var assetUsefulLife: Int16 = 5
    var gstAmount: Double = 0.0
    var isCapitalExpense: Bool = false
    var receiptData: Data?
    var notes: String?
    var paidDate: Date?
    @Relationship(deleteRule: .nullify, inverse: \BusinessEntity.expenses) var business: BusinessEntity?
    var category: ExpenseCategoryEntity?
    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}
