//
//  Payee.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class Payee {
    #Index<Payee>([\.fullName], [\.email], [\.phone], [\.relationToClient])
    public var id: UUID = UUID()
    public var fullName: String = ""
    public var email: String?
    public var phone: String?
    public var relationToClient: String?
    public var status: String?
    // notes property removed - violates architectural guidelines (payees should not have notes)

    @Relationship(deleteRule: .nullify) public var address: Address?

    @Relationship(deleteRule: .nullify, inverse: \Client.payee) public var guardedClients: [Client]?
    @Relationship(deleteRule: .nullify, inverse: \Invoice.payee) public var invoices: [Invoice]?
    public init(id: UUID = UUID(), fullName: String) {
        self.id = id
        self.fullName = fullName
    }
}
