//
//  PayeeEntity.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData
import SwiftUI


@Model public class PayeeEntity {
    #Index<PayeeEntity>([\.fullName], [\.email], [\.phone], [\.relationToClient])
    public var id: UUID
    public var fullName: String = ""
    public var email: String?
    public var payeeID: Int32? = 0
    public var phone: String?
    public var relationToClient: String?
    public var status: String?
    // notes property removed - violates architectural guidelines (payees should not have notes)

    @Relationship(deleteRule: .nullify) public var address: AddressEntity?

    @Relationship(deleteRule: .nullify, inverse: \ClientEntity.payee) public var guardedClients: [ClientEntity] = []
    @Relationship(deleteRule: .nullify, inverse: \InvoiceEntity.payee) public var invoices: [InvoiceEntity] = []
    public init(id: UUID, fullName: String) {
        self.id = id
        self.fullName = fullName
    }
}


