//
//  Address.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import Core
import SwiftData


@Model public class Address {
    #Index<Address>([\.country], [\.state], [\.city], [\.suburb], [\.postcode])
    public var id: UUID = UUID()
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
    /// Optional to avoid SwiftData cast failure when store has nil (e.g. CloudKit sync).
    @Attribute(originalName: "validationStatus") private var validationStatusData: Data? = PersistenceAttributeCoder.encodeEnum(AddressValidationStatus.unvalidated)

    public var validationStatus: AddressValidationStatus? {
        get { PersistenceAttributeCoder.decodeEnum(from: validationStatusData) }
        set { validationStatusData = PersistenceAttributeCoder.encodeEnum(newValue) }
    }
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
        
        // Add locality components. Preserve compatibility with records that still
        // populate suburb while city is empty.
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSuburb = suburb.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCity.isEmpty {
            components.append(trimmedCity)
            if !trimmedSuburb.isEmpty,
               trimmedSuburb.caseInsensitiveCompare(trimmedCity) != .orderedSame {
                components.append(trimmedSuburb)
            }
        } else if !trimmedSuburb.isEmpty {
            components.append(trimmedSuburb)
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
    
    @Relationship(deleteRule: .nullify, inverse: \Business.address) var business: Business?
    @Relationship(deleteRule: .nullify, inverse: \Client.address) var client: Client?
    @Relationship(deleteRule: .nullify, inverse: \Payee.address) var payee: Payee?
    @Relationship(deleteRule: .nullify, inverse: \PlanManager.address) var planManager: PlanManager?
    @Relationship(deleteRule: .nullify, inverse: \Session.address) var session: Session?
    public var invoiceBusinessAddress: Invoice?
    public var invoiceClientAddress: Invoice?
    public var invoiceBillToAddress: Invoice?
    public var invoicePayeeAddress: Invoice?
    
    public init() {
        self.id = UUID()
    }

    /// Initializes an Address entity from a snapshot.
    public convenience init(from snapshot: AddressSnapshot) {
        self.init()
        update(from: snapshot)
    }

    /// Updates the entity's properties from a snapshot.
    public func update(from snapshot: AddressSnapshot) {
        self.id = snapshot.id
        self.country = snapshot.country
        self.postcode = snapshot.postcode
        self.state = snapshot.state
        self.streetName = snapshot.streetName
        self.streetNumber = snapshot.streetNumber
        self.city = snapshot.city
        self.suburb = snapshot.suburb
        self.unitNumber = snapshot.unitNumber
        self.poBox = snapshot.poBox
        self.fullAddressText = snapshot.fullAddressText
        self.latitude = snapshot.latitude
        self.longitude = snapshot.longitude
    }
    
    /// Returns a thread-safe snapshot of the Address.
    public func snapshot() -> AddressSnapshot {
        AddressSnapshot(self)
    }
    
}
