//
//  ExpenseCategoryEntity.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class ExpenseCategoryEntity {
    public var id: UUID
    var name: String = ""
    var iconName: String?
    @Relationship(deleteRule: .nullify, inverse: \ExpenseEntity.category) var expenses: [ExpenseEntity]?
    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}
