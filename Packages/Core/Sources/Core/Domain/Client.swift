import Foundation

/// Domain model for a client
public struct Client: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let ndisNumber: String
    public let fullName: String
    public let status: String
    public let email: String?
    public let notes: String?
    public let phone: String?
    public let creditAmount: Double
    public let isMinor: Bool
    public let hasNdisPlan: Bool
    public let planManagementType: String?
    public let billingAuthority: String?
    public let address: Address?
    public let planManager: PlanManager?
    public let payee: Payee?
    
    // Email recipient preferences
    public var sendInvoicesToClient: Bool?
    public var sendInvoicesToPayee: Bool?
    public var sendInvoicesToPlanManager: Bool?
    
    public init(
        id: UUID,
        ndisNumber: String,
        fullName: String,
        status: String,
        email: String? = nil,
        notes: String? = nil,
        phone: String? = nil,
        creditAmount: Double = 0.0,
        isMinor: Bool = false,
        hasNdisPlan: Bool = false,
        planManagementType: String? = nil,
        billingAuthority: String? = nil,
        address: Address? = nil,
        planManager: PlanManager? = nil,
        payee: Payee? = nil,
        sendInvoicesToClient: Bool? = nil,
        sendInvoicesToPayee: Bool? = nil,
        sendInvoicesToPlanManager: Bool? = nil
    ) {
        self.id = id
        self.ndisNumber = ndisNumber
        self.fullName = fullName
        self.status = status
        self.email = email
        self.notes = notes
        self.phone = phone
        self.creditAmount = creditAmount
        self.isMinor = isMinor
        self.hasNdisPlan = hasNdisPlan
        self.planManagementType = planManagementType
        self.billingAuthority = billingAuthority
        self.address = address
        self.planManager = planManager
        self.payee = payee
        self.sendInvoicesToClient = sendInvoicesToClient
        self.sendInvoicesToPayee = sendInvoicesToPayee
        self.sendInvoicesToPlanManager = sendInvoicesToPlanManager
    }
}

/// Domain model for an address
public struct Address: Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let unitNumber: String
    public let streetNumber: String
    public let streetName: String
    public let suburb: String
    public let city: String
    public let state: String
    public let postcode: String
    public let country: String
    public let poBox: String
    public let latitude: Double
    public let longitude: Double
    
    // Legacy compatibility: computed property that combines street components
    public var street: String? {
        let combined = "\(streetNumber) \(streetName)".trimmingCharacters(in: .whitespaces)
        return combined.isEmpty ? nil : combined
    }
    
    public init(
        id: UUID,
        unitNumber: String = "",
        streetNumber: String = "",
        streetName: String = "",
        suburb: String = "",
        city: String = "",
        state: String = "",
        postcode: String = "",
        country: String = "",
        poBox: String = "",
        latitude: Double = 0.0,
        longitude: Double = 0.0
    ) {
        self.id = id
        self.unitNumber = unitNumber
        self.streetNumber = streetNumber
        self.streetName = streetName
        self.suburb = suburb
        self.city = city
        self.state = state
        self.postcode = postcode
        self.country = country
        self.poBox = poBox
        self.latitude = latitude
        self.longitude = longitude
    }
    
    public var fullFormattedAddress: String {
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
        
        // Add locality components (prefer city over suburb, or use suburb if city is empty)
        let locality = !city.isEmpty ? city : suburb
        if !locality.isEmpty {
            components.append(locality)
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
}

/// Domain model for a plan manager
public struct PlanManager: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let email: String?
    public let phone: String?
    public let address: Address?
    public let abn: String
    
    public init(
        id: UUID,
        name: String,
        email: String? = nil,
        phone: String? = nil,
        address: Address? = nil,
        abn: String
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.address = address
        self.abn = abn
    }
}

/// Domain model for a payee
public struct Payee: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let fullName: String
    public let email: String?
    public let phone: String?
    public let address: Address?
    public let status: String?
    public let relationToClient: String?
    
    public init(
        id: UUID,
        fullName: String,
        email: String? = nil,
        phone: String? = nil,
        address: Address? = nil,
        status: String? = nil,
        relationToClient: String? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.phone = phone
        self.address = address
        self.status = status
        self.relationToClient = relationToClient
    }
}
