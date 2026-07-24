//
//  InvoiceItemSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation
import SwiftData

// MARK: - InvoiceItemSnapshot

public struct InvoiceItemSnapshot: Sendable, Equatable, Hashable {
    public let id: UUID
    public let itemDescription: String
    public let position: Int32
    public let quantity: Double
    public let rate: Double
    public let serviceDate: Date
    public let unit: String?
    public let gstCode: String?
    public let taxRate: Double
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

    public init(_ item: InvoiceItem) {
        self.id = item.id
        self.itemDescription = item.itemDescription
        self.position = item.position
        self.quantity = item.quantity
        self.rate = item.rate
        self.serviceDate = item.serviceDate
        self.unit = item.unit
        self.gstCode = item.gstCode
        self.taxRate = item.taxRate
        self.ndisItemNumber = item.ndisItemNumber
        self.claimType = item.claimType
        self.ndisSupportCategory = item.ndisSupportCategory
        self.ndisRegistrationGroup = item.ndisRegistrationGroup
        self.ndisOutcomeDomain = item.ndisOutcomeDomain
        self.ndisSupportPurpose = item.ndisSupportPurpose
        self.isComplexBehaviour = item.isComplexBehaviour
        self.isHighIntensity = item.isHighIntensity
        self.geographicLoading = item.geographicLoading
        self.timeModifier = item.timeModifier
        self.groupModifier = item.groupModifier
        self.finalRateLimit = item.finalRateLimit
        self.invoiceId = item.invoice?.id
        self.sessionId = item.session?.id
        self.clientServiceId = item.clientService?.id
    }
}

