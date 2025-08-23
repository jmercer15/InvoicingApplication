//
//  BusinessEntity.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class BusinessEntity {
    @Attribute(.unique) var abn: String
    var name: String = ""
    var email: String = ""
    var phone: String = ""
    public var id: UUID
    var logo: Data?
    var bankAccountName: String?
    var bankAccountNumber: String?
    var bankBSB: String?
    var bankName: String?
    var accountingMethod: String = "Accrual"
    var address: AddressEntity?
    var expenses: [ExpenseEntity]?
    @Relationship(deleteRule: .nullify) var invoices: [InvoiceEntity]?
    public init(id: UUID, abn: String) {
        self.id = id
        self.abn = abn
    }
}


