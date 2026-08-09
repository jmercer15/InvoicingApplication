//
//  InvoiceItem.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import Core
import SwiftData


@Model public class InvoiceItem {
    #Index<InvoiceItem>([\.itemDescription], [\.ndisItemNumber], [\.ndisSupportCategory], [\.ndisRegistrationGroup], [\.serviceDate], [\.rateDecimal], [\.quantityDecimal])
    public var id: UUID = UUID()
    public var itemDescription: String = "" // Non-optional with default
    public var position: Int32 = 0
    /// CloudKit forbids attribute renames; physical `*Decimal` names stay stable.
    public var quantityDecimal: Decimal = 1
    public var quantity: Decimal {
        get { quantityDecimal }
        set { quantityDecimal = newValue }
    }
    public var rateDecimal: Decimal = 0
    public var rate: Decimal {
        get { rateDecimal }
        set { rateDecimal = newValue }
    }
    public var serviceDate: Date = Date()
    public var unit: String?
    public var gstCode: String?
    public var taxRateDecimal: Decimal = 0
    public var taxRate: Decimal {
        get { taxRateDecimal }
        set { taxRateDecimal = newValue }
    }
    
    // NDIS-specific properties for billing algorithm
    public var ndisItemNumber: String?
    public var claimType: NDISClaimType? // "Direct", "ProviderTravel", "Cancellation", etc.
    public var ndisSupportCategory: String?
    public var ndisRegistrationGroup: String?
    public var ndisOutcomeDomain: String?
    public var ndisSupportPurpose: String?
    public var isComplexBehaviour: Bool = false
    public var isHighIntensity: Bool = false
    public var geographicLoading: Double = 1.0
    public var timeModifier: Double = 1.0
    public var groupModifier: Double = 1.0
    public var finalRateLimit: Double = 0.0
    

    @Relationship(deleteRule: .nullify) public var invoice: Invoice?
    @Relationship(deleteRule: .nullify) public var session: Session?
    @Relationship(deleteRule: .nullify) public var clientService: ClientService?
    @Relationship(deleteRule: .nullify) public var bulkClaimLines: [BulkClaimLine]?
    
    public init(id: UUID = UUID(), itemDescription: String) {
        self.id = id
        self.itemDescription = itemDescription
    }
    
    // MARK: - Computed Properties
    
    /// Returns a thread-safe snapshot of the InvoiceItem.
    public func snapshot() -> InvoiceItemSnapshot {
        InvoiceItemSnapshot(self)
    }

    /// Calculated line total (rate * quantity).
    public var lineTotal: Decimal {
        rate * quantity
    }
    
}
