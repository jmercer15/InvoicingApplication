//
//  InvoiceItem.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class InvoiceItem {
    #Index<InvoiceItem>([\.itemDescription], [\.ndisItemNumber], [\.ndisSupportCategory], [\.ndisRegistrationGroup], [\.serviceDate], [\.rate], [\.quantity])
    public var id: UUID = UUID()
    public var itemDescription: String = "" // Non-optional with default
    public var position: Int32 = 0
    public var quantity: Double = 1.0 // Non-optional with default
    public var rate: Double = 0.0 // Non-optional with default
    public var serviceDate: Date = Date()
    public var unit: String?
    public var gstCode: String?
    public var taxRate: Double = 0.0 // Non-optional with default
    
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
    
    /// Calculated line total (rate * quantity)
    public var lineTotal: Double {
        rate * quantity
    }
    
}
