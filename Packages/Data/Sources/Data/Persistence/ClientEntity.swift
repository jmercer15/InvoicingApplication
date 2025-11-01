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
    @Attribute(.unique) public var ndisNumber: String
    public var fullName: String
    public var status: String
    public var email: String? = nil
    public var id: UUID
    public var notes: String? = nil
    public var phone: String? = nil
    public var creditAmount: Double = 0.0
    public var isMinor: Bool = false
    public var hasNdisPlan: Bool = false
    public var planManagementType: String?
    public var billingAuthority: String?
    @Relationship(deleteRule: .nullify) public var address: AddressEntity?
    @Relationship(deleteRule: .cascade) public var clientServices: [ClientServiceEntity] = []
    @Relationship(deleteRule: .nullify) public var invoices: [InvoiceEntity] = []
    @Relationship(deleteRule: .nullify) public var planManager: PlanManagerEntity?
    @Relationship(deleteRule: .cascade) public var creditHistory: [CreditHistoryEntryEntity] = []
    @Relationship(deleteRule: .cascade) public var travelCharges: [TravelChargeEntity] = []
    @Relationship(deleteRule: .nullify) public var sessions: [SessionEntity] = []
    @Relationship(deleteRule: .nullify) public var payee: PayeeEntity?
    
    // Email recipient preferences
    public var sendInvoicesToClient: Bool?
    public var sendInvoicesToPayee: Bool?
    public var sendInvoicesToPlanManager: Bool?
    public init(id: UUID, ndisNumber: String, fullName: String, status: String) {
        self.id = id
        self.ndisNumber = ndisNumber
        self.fullName = fullName
        self.status = status
    }
}


