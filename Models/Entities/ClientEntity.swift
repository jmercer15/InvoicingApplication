//
//  ClientEntity.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData
import SwiftUI


@Model public class ClientEntity {
    @Attribute(.unique) var ndisNumber: String
    var fullName: String
    var status: String
    var colorHex: String
    var email: String?
    public var id: UUID
    var notes: String?
    var phone: String?
    var creditAmount: Double = 0.0
    var isMinor: Bool = false
    var hasNdisPlan: Bool = false
    var planManagementType: String?
    var billingAuthority: String?
    var address: AddressEntity?
    var clientServices: [ClientServiceEntity]?
    @Relationship(deleteRule: .nullify) var invoices: [InvoiceEntity]?
    var planManager: PlanManagerEntity?
    var creditHistory: [CreditHistoryEntryEntity]?
    var travelCharges: [TravelChargeEntity]?
    var sessions: [SessionEntity]?
    var payee: PayeeEntity?
    
    // Email recipient preferences
    var sendInvoicesToClient: Bool?
    var sendInvoicesToPayee: Bool?
    var sendInvoicesToPlanManager: Bool?
    public init(id: UUID, ndisNumber: String, fullName: String, status: String, colorHex: String) {
        self.id = id
        self.ndisNumber = ndisNumber
        self.fullName = fullName
        self.status = status
        self.colorHex = colorHex
    }
    
    // Computed property for Color (not persisted)
    var color: Color {
        Color(hex: colorHex)
    }
}

extension ClientEntity: DropdownRepresentable {
    var displayName: String { fullName }
}
