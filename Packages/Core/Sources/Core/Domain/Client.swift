import Foundation

/// Domain model for a client
public struct Client: Identifiable, Codable, Equatable, Sendable {
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
    public let sendInvoicesToClient: Bool?
    public let sendInvoicesToPayee: Bool?
    public let sendInvoicesToPlanManager: Bool?
    
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
public struct Address: Codable, Equatable, Sendable {
    public let id: UUID
    public let street: String?
    public let city: String?
    public let state: String?
    public let postcode: String?
    public let country: String?
    
    public init(
        id: UUID,
        street: String? = nil,
        city: String? = nil,
        state: String? = nil,
        postcode: String? = nil,
        country: String? = nil
    ) {
        self.id = id
        self.street = street
        self.city = city
        self.state = state
        self.postcode = postcode
        self.country = country
    }
    
    public var fullFormattedAddress: String {
        var components: [String] = []
        if let street = street, !street.isEmpty { components.append(street) }
        if let city = city, !city.isEmpty { components.append(city) }
        if let state = state, !state.isEmpty { components.append(state) }
        if let postcode = postcode, !postcode.isEmpty { components.append(postcode) }
        if let country = country, !country.isEmpty { components.append(country) }
        return components.joined(separator: ", ")
    }
}

/// Domain model for a plan manager
public struct PlanManager: Codable, Equatable, Sendable {
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
public struct Payee: Codable, Equatable, Sendable {
    public let id: UUID
    public let fullName: String
    public let email: String?
    public let phone: String?
    public let address: Address?
    public let status: String?
    
    public init(
        id: UUID,
        fullName: String,
        email: String? = nil,
        phone: String? = nil,
        address: Address? = nil,
        status: String? = nil
    ) {
        self.id = id
        self.fullName = fullName
        self.email = email
        self.phone = phone
        self.address = address
        self.status = status
    }
}
