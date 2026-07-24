//
//  ClientSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation
import SwiftData

// MARK: - ClientSnapshot

public struct ClientSnapshot: Sendable, Equatable, Hashable {
    public let id: UUID
    public let ndisNumber: String
    public let fullName: String
    public let effectiveStatus: ClientStatus
    public let email: String?
    public let notes: String?
    public let phoneNumber: String?
    public let dateOfBirth: Date?
    public let supportStartDate: Date?
    public let latitude: Double
    public let longitude: Double
    public let creditAmount: Double
    public let isMinor: Bool
    public let hasNdisPlan: Bool
    public let planManagementType: String?
    public let billingAuthority: BillingAuthority?
    public let address: AddressSnapshot?
    public let sendInvoicesToClient: Bool?
    public let sendInvoicesToPayee: Bool?
    public let sendInvoicesToPlanManager: Bool?

    public init(_ client: Client) {
        self.id = client.id
        self.ndisNumber = client.ndisNumber
        self.fullName = client.fullName
        self.effectiveStatus = client.effectiveStatus
        self.email = client.email
        self.notes = client.notes
        self.phoneNumber = client.phoneNumber
        self.dateOfBirth = client.dateOfBirth
        self.supportStartDate = client.supportStartDate
        self.latitude = client.latitude
        self.longitude = client.longitude
        self.creditAmount = client.creditAmount
        self.isMinor = client.isMinor
        self.hasNdisPlan = client.hasNdisPlan
        self.planManagementType = client.planManagementType
        self.billingAuthority = client.billingAuthority
        self.address = client.address.map(AddressSnapshot.init)
        self.sendInvoicesToClient = client.sendInvoicesToClient
        self.sendInvoicesToPayee = client.sendInvoicesToPayee
        self.sendInvoicesToPlanManager = client.sendInvoicesToPlanManager
    }
}

