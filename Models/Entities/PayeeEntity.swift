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
    public var id: UUID
    var fullName: String = ""
    var colorHex: String = ""
    var email: String?
    var notes: String?
    var payeeID: Int32? = 0
    var phone: String?
    var relationToClient: String?
    var status: String?

    var address: AddressEntity?

    var guardedClients: [ClientEntity]?
    @Relationship(deleteRule: .nullify) var invoices: [InvoiceEntity]?
    public init(id: UUID, fullName: String, colorHex: String) {
        self.id = id
        self.fullName = fullName
        self.colorHex = colorHex
    }
    // Computed property for Color (not persisted)
    var color: Color {
        Color(hex: colorHex)
    }
}

extension PayeeEntity: DropdownRepresentable {
    var displayName: String { fullName }
}
