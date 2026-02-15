//
//  AddressEntity.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class AddressEntity: @unchecked Sendable {
    #Index<AddressEntity>([\.country], [\.state], [\.city], [\.suburb], [\.postcode])
    public var id: UUID
    public var country: String = ""
    public var postcode: String = ""
    public var state: String = ""
    public var streetName: String = ""
    public var streetNumber: String = ""
    public var city: String = ""
    public var suburb: String = ""
    public var unitNumber: String = ""
    public var poBox: String = ""
    public var fullAddressText: String = ""
    public var latitude: Double = 0.0
    public var longitude: Double = 0.0
    
    // Validation tracking
    public var validationStatus: AddressValidationStatus = AddressValidationStatus.unvalidated
    var lastValidationAttempt: Date?
    var validationError: String?
    
    public var fullFormattedAddress: String {
        // Compose a formatted address string from available fields
        var components: [String] = []
        
        // Handle PO Box
        if !poBox.isEmpty {
            components.append("PO Box \(poBox)")
        } else {
            // Handle street address components
            var streetComponents: [String] = []
            
            if !unitNumber.isEmpty {
                streetComponents.append("Unit \(unitNumber)")
            }
            
            // Combine street number and name without comma
            var streetAddress = ""
            if !streetNumber.isEmpty {
                streetAddress += streetNumber
            }
            if !streetName.isEmpty {
                if !streetAddress.isEmpty {
                    streetAddress += " "
                }
                streetAddress += streetName
            }
            
            if !streetAddress.isEmpty {
                streetComponents.append(streetAddress)
            }
            
            if !streetComponents.isEmpty {
                components.append(streetComponents.joined(separator: ", "))
            }
        }
        
        // Add locality components
        if !city.isEmpty {
            components.append(city)
        }
        if !state.isEmpty {
            components.append(state)
        }
        if !postcode.isEmpty {
            components.append(postcode)
        }
        if !country.isEmpty {
            components.append(country)
        }
        
        return components.joined(separator: ", ")
    }
    
    // Compatibility property for existing code
    public var formattedAddress: String {
        return fullFormattedAddress
    }
    
    
    
    // Helper to check if address is valid for geocoding
    var isValidForGeocoding: Bool {
        return !fullFormattedAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // Helper to check if coordinates are valid
    var hasValidCoordinates: Bool {
        return latitude != 0.0 && longitude != 0.0
    }
    
    @Relationship(deleteRule: .nullify, inverse: \BusinessEntity.address) var business: BusinessEntity?
    @Relationship(deleteRule: .nullify, inverse: \ClientEntity.address) var client: ClientEntity?
    @Relationship(deleteRule: .nullify, inverse: \PayeeEntity.address) var payee: PayeeEntity?
    @Relationship(deleteRule: .nullify, inverse: \PlanManagerEntity.address) var planManager: PlanManagerEntity?
    @Relationship(deleteRule: .nullify, inverse: \SessionEntity.address) var session: SessionEntity?
    @Relationship(deleteRule: .nullify) var invoice: InvoiceEntity?
    
    public init() {
        self.id = UUID()
    }
    
}
