//
//  InvoiceItemEntity.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class InvoiceItemEntity {
    #Index<InvoiceItemEntity>([\.itemDescription], [\.ndisItemNumber], [\.ndisSupportCategory], [\.ndisRegistrationGroup], [\.serviceDate], [\.rate], [\.amount], [\.quantity])
    public var id: UUID
    public var itemDescription: String = "" // Non-optional with default
    public var amount: Double = 0.0 // Non-optional with default
    public var date: Date = Date() // Non-optional with default
    public var position: Int32 = 0
    public var quantity: Double = 1.0 // Non-optional with default
    public var rate: Double = 0.0 // Non-optional with default
    public var serviceDate: Date = Date()
    public var unit: String?
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
    

    @Relationship(deleteRule: .nullify) public var invoice: InvoiceEntity?
    @Relationship(deleteRule: .nullify) public var session: SessionEntity?
    @Relationship(deleteRule: .nullify) public var clientService: ClientServiceEntity?
    
    public init(id: UUID, itemDescription: String) {
        self.id = id
        self.itemDescription = itemDescription
    }
    
    // MARK: - Computed Properties
    
    /// Calculated line total (rate * quantity)
    public var lineTotal: Double {
        rate * quantity
    }
    
    /// Calculated tax amount for this line item
    var lineTaxAmount: Double {
        lineTotal * (taxRate / 100.0)
    }
    
    /// Total including tax
    var lineTotalWithTax: Double {
        lineTotal + lineTaxAmount
    }
    
    /// Formatted line total for display
    var formattedLineTotal: String {
        String(format: "%.2f", lineTotal)
    }
    
    /// Formatted rate for display
    var formattedRate: String {
        String(format: "%.2f", rate)
    }
    
    /// Formatted quantity for display
    var formattedQuantity: String {
        String(format: "%.1f", quantity)
    }
    
    /// Check if line item is valid
    var isValid: Bool {
        !itemDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        quantity > 0 &&
        rate >= 0
    }
    
    /// Check if this is an NDIS line item
    var isNDISItem: Bool {
        ndisItemNumber != nil && !ndisItemNumber!.isEmpty
    }
    
    /// Get the NDIS claim type display name
    var ndisClaimTypeDisplay: String {
        guard let claimType = claimType else { return "Standard" }
        
        switch claimType {
        case .direct:
            return "Direct Support"
        case .providerTravel:
            return "Provider Travel"
        case .cancellation:
            return "Cancellation Fee"
        case .prepayment:
            return "Prepayment"
        case .telehealth:
            return "Telehealth"
        case .nonFaceToFace:
            return "Non-Face-to-Face"
        case .ndiaReport:
            return "NDIA Report"
        case .irregularSILSupport:
            return "Irregular SIL Support"
        case .bereavement:
            return "Bereavement Support"
        default:
            return claimType.rawValue
        }
    }
    
    /// Get the total rate modifiers applied
    var totalRateModifiers: Double {
        geographicLoading * timeModifier * groupModifier
    }
    
    /// Get a summary of applied modifiers for display
    var rateModifiersSummary: String {
        var modifiers: [String] = []
        
        if geographicLoading != 1.0 {
            modifiers.append("Geo: \(String(format: "%.2f", geographicLoading))")
        }
        if timeModifier != 1.0 {
            modifiers.append("Time: \(String(format: "%.2f", timeModifier))")
        }
        if groupModifier != 1.0 {
            modifiers.append("Group: \(String(format: "%.2f", groupModifier))")
        }
        
        return modifiers.isEmpty ? "None" : modifiers.joined(separator: ", ")
    }
}


