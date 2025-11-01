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
    @Attribute(.unique) public var abn: String
    public var name: String = ""
    public var email: String = ""
    public var phone: String = ""
    public var id: UUID
    public var logo: Data?
    public var bankAccountName: String?
    public var bankAccountNumber: String?
    public var bankBSB: String?
    public var bankName: String?
    public var accountingMethod: String = "Accrual"
    @Relationship(deleteRule: .nullify) public var address: AddressEntity?
    @Relationship(deleteRule: .nullify, inverse: \InvoiceEntity.business) public var invoices: [InvoiceEntity]?
    public init(id: UUID, abn: String) {
        self.id = id
        self.abn = abn
    }
}


