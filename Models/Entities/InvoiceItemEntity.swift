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
    public var id: UUID
    var itemDescription: String = "" // Non-optional with default
    var amount: Double = 0.0 // Non-optional with default
    var date: Date = Date() // Non-optional with default
    var position: Int16 = 0
    var quantity: Double = 1.0 // Non-optional with default
    var rate: Double = 0.0 // Non-optional with default
    var serviceDate: Date = Date()
    var unit: String?
    var taxRate: Double = 0.0 // Non-optional with default
    
    // NDIS-specific properties for billing algorithm
    var ndisItemNumber: String?
    var claimType: String? // "Direct", "ProviderTravel", "Cancellation", etc.
    var ndisSupportCategory: String?
    var ndisRegistrationGroup: String?
    var ndisOutcomeDomain: String?
    var ndisSupportPurpose: String?
    var isComplexBehaviour: Bool = false
    var isHighIntensity: Bool = false
    var geographicLoading: Double = 1.0
    var timeModifier: Double = 1.0
    var groupModifier: Double = 1.0
    var finalRateLimit: Double = 0.0
    

    @Relationship(deleteRule: .nullify) var invoice: InvoiceEntity?
    @Relationship(deleteRule: .nullify) var session: SessionEntity?
    @Relationship(deleteRule: .nullify) var clientService: ClientServiceEntity?
    
    public init(id: UUID, itemDescription: String) {
        self.id = id
        self.itemDescription = itemDescription
    }
    
    // MARK: - Computed Properties
    
    /// Calculated line total (rate * quantity)
    var lineTotal: Double {
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
        case "Direct":
            return "Direct Support"
        case "ProviderTravel":
            return "Provider Travel"
        case "Cancellation":
            return "Cancellation Fee"
        case "Prepayment":
            return "Prepayment"
        case "Telehealth":
            return "Telehealth"
        case "NonFaceToFace":
            return "Non-Face-to-Face"
        case "NDIAReport":
            return "NDIA Report"
        case "IrregularSILSupport":
            return "Irregular SIL Support"
        case "Bereavement":
            return "Bereavement Support"
        default:
            return claimType
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


