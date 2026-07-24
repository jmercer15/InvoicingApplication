//
//  Client.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData
import SwiftUI


@Model public class Client {
    #Index<Client>([\.fullName], [\.email], [\.phoneNumber], [\.isMinor], [\.hasNdisPlan])
    
    public var ndisNumber: String = ""
    public var fullName: String = ""
    /// Optional to avoid SwiftData cast failure when store has nil (e.g. CloudKit sync). Use `effectiveStatus` for a non-optional value.
    @Attribute(originalName: "status") private var statusData: Data? = PersistenceAttributeCoder.encodeEnum(ClientStatus.active)

    public var status: ClientStatus? {
        get { PersistenceAttributeCoder.decodeEnum(from: statusData) }
        set { statusData = PersistenceAttributeCoder.encodeEnum(newValue) }
    }

    /// Non-optional status for app code; falls back to .active when persistence returns nil.
    public var effectiveStatus: ClientStatus {
        get { status ?? .active }
        set { status = newValue }
    }
    public var email: String? = nil
    public var id: UUID = UUID()
    public var notes: String? = nil
    
    // Core details
    public var phoneNumber: String? = nil
    public var dateOfBirth: Date? = nil
    public var supportStartDate: Date? = nil
    
    // Coordinates (synced from Address or manual)
    public var latitude: Double = 0.0
    public var longitude: Double = 0.0
    
    public var phone: String? { // Legacy alias
        get { phoneNumber }
        set { phoneNumber = newValue }
    }
    public var creditAmount: Double = 0.0
    public var isMinor: Bool = false
    public var hasNdisPlan: Bool = false
    public var planManagementType: String?
    @Attribute(originalName: "billingAuthority") private var billingAuthorityData: Data?

    public var billingAuthority: BillingAuthority? {
        get { PersistenceAttributeCoder.decodeEnum(from: billingAuthorityData) }
        set { billingAuthorityData = PersistenceAttributeCoder.encodeEnum(newValue) }
    }
    @Relationship(deleteRule: .nullify) public var address: Address?
    @Relationship(deleteRule: .cascade) public var clientServices: [ClientService]?
    @Relationship(deleteRule: .nullify) public var invoices: [Invoice]?
    @Relationship(deleteRule: .nullify) public var planManager: PlanManager?
    @Relationship(deleteRule: .cascade) public var creditHistory: [CreditHistoryEntry]?
    @Relationship(deleteRule: .cascade) public var travelCharges: [TravelCharge]?
    @Relationship(deleteRule: .nullify) public var sessions: [Session]?
    @Relationship(deleteRule: .cascade) public var serviceAgreements: [ServiceAgreement]?
    @Relationship(deleteRule: .cascade) public var supportLogs: [SupportLog]?
    @Relationship(deleteRule: .nullify) public var payee: Payee?
    @Relationship(deleteRule: .nullify) public var billableDrafts: [BillableDraft]?
    
    // Email recipient preferences
    public var sendInvoicesToClient: Bool?
    public var sendInvoicesToPayee: Bool?
    public var sendInvoicesToPlanManager: Bool?
    public init(
        id: UUID = UUID(),
        ndisNumber: String = "",
        fullName: String = "",
        status: ClientStatus = .active,
        email: String? = nil,
        phone: String? = nil,
        isMinor: Bool = false,
        hasNdisPlan: Bool = false,
        planManagementType: String? = nil,
        billingAuthority: BillingAuthority? = nil
    ) {
        self.id = id
        self.ndisNumber = ndisNumber
        self.fullName = fullName
        self.status = status
        self.email = email
        self.phone = phone
        self.isMinor = isMinor
        self.hasNdisPlan = hasNdisPlan
        self.planManagementType = planManagementType
        self.billingAuthority = billingAuthority
    }

    /// Returns a thread-safe snapshot of this client.
    public func snapshot() -> ClientSnapshot {
        ClientSnapshot(self)
    }

    /// Convenience init for tests/import when status is provided as string (e.g. domain raw value).
    public convenience init(id: UUID, ndisNumber: String, fullName: String, status: String) {
        self.init(
            id: id,
            ndisNumber: ndisNumber,
            fullName: fullName,
            status: ClientStatus(rawValue: status) ?? .active
        )
    }
}
