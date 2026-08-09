//
//  ClientSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation

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
    public let creditAmount: Decimal
    public let isMinor: Bool
    public let hasNdisPlan: Bool
    public let planManagementType: String?
    public let billingAuthority: BillingAuthority?
    public let address: AddressSnapshot?
    public let sendInvoicesToClient: Bool?
    public let sendInvoicesToPayee: Bool?
    public let sendInvoicesToPlanManager: Bool?


    public init(
        id: UUID,
        ndisNumber: String,
        fullName: String,
        effectiveStatus: ClientStatus,
        email: String?,
        notes: String?,
        phoneNumber: String?,
        dateOfBirth: Date?,
        supportStartDate: Date?,
        latitude: Double,
        longitude: Double,
        creditAmount: Decimal,
        isMinor: Bool,
        hasNdisPlan: Bool,
        planManagementType: String?,
        billingAuthority: BillingAuthority?,
        address: AddressSnapshot?,
        sendInvoicesToClient: Bool?,
        sendInvoicesToPayee: Bool?,
        sendInvoicesToPlanManager: Bool?
    ) {
        self.id = id
        self.ndisNumber = ndisNumber
        self.fullName = fullName
        self.effectiveStatus = effectiveStatus
        self.email = email
        self.notes = notes
        self.phoneNumber = phoneNumber
        self.dateOfBirth = dateOfBirth
        self.supportStartDate = supportStartDate
        self.latitude = latitude
        self.longitude = longitude
        self.creditAmount = creditAmount
        self.isMinor = isMinor
        self.hasNdisPlan = hasNdisPlan
        self.planManagementType = planManagementType
        self.billingAuthority = billingAuthority
        self.address = address
        self.sendInvoicesToClient = sendInvoicesToClient
        self.sendInvoicesToPayee = sendInvoicesToPayee
        self.sendInvoicesToPlanManager = sendInvoicesToPlanManager
    }

}
