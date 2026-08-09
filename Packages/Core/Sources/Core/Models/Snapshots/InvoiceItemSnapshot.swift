//
//  InvoiceItemSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation

// MARK: - InvoiceItemSnapshot

public struct InvoiceItemSnapshot: Sendable, Equatable, Hashable {
    public let id: UUID
    public let itemDescription: String
    public let position: Int32
    public let quantity: Decimal
    public let rate: Decimal
    public let serviceDate: Date
    public let unit: String?
    public let gstCode: String?
    public let taxRate: Decimal
    public let ndisItemNumber: String?
    public let claimType: NDISClaimType?
    public let ndisSupportCategory: String?
    public let ndisRegistrationGroup: String?
    public let ndisOutcomeDomain: String?
    public let ndisSupportPurpose: String?
    public let isComplexBehaviour: Bool
    public let isHighIntensity: Bool
    public let geographicLoading: Double
    public let timeModifier: Double
    public let groupModifier: Double
    public let finalRateLimit: Double
    public let invoiceId: UUID?
    public let sessionId: UUID?
    public let clientServiceId: UUID?


    public init(
        id: UUID,
        itemDescription: String,
        position: Int32,
        quantity: Decimal,
        rate: Decimal,
        serviceDate: Date,
        unit: String?,
        gstCode: String?,
        taxRate: Decimal,
        ndisItemNumber: String?,
        claimType: NDISClaimType?,
        ndisSupportCategory: String?,
        ndisRegistrationGroup: String?,
        ndisOutcomeDomain: String?,
        ndisSupportPurpose: String?,
        isComplexBehaviour: Bool,
        isHighIntensity: Bool,
        geographicLoading: Double,
        timeModifier: Double,
        groupModifier: Double,
        finalRateLimit: Double,
        invoiceId: UUID?,
        sessionId: UUID?,
        clientServiceId: UUID?
    ) {
        self.id = id
        self.itemDescription = itemDescription
        self.position = position
        self.quantity = quantity
        self.rate = rate
        self.serviceDate = serviceDate
        self.unit = unit
        self.gstCode = gstCode
        self.taxRate = taxRate
        self.ndisItemNumber = ndisItemNumber
        self.claimType = claimType
        self.ndisSupportCategory = ndisSupportCategory
        self.ndisRegistrationGroup = ndisRegistrationGroup
        self.ndisOutcomeDomain = ndisOutcomeDomain
        self.ndisSupportPurpose = ndisSupportPurpose
        self.isComplexBehaviour = isComplexBehaviour
        self.isHighIntensity = isHighIntensity
        self.geographicLoading = geographicLoading
        self.timeModifier = timeModifier
        self.groupModifier = groupModifier
        self.finalRateLimit = finalRateLimit
        self.invoiceId = invoiceId
        self.sessionId = sessionId
        self.clientServiceId = clientServiceId
    }

}
