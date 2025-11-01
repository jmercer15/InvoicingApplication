import Foundation

/// Domain model for a client service (service assigned to a client)
public struct ClientService: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let clientId: UUID
    public let serviceName: String
    public let rate: Double
    public let unit: String
    public let status: String?
    public let isActive: Bool
    public let startDate: Date?
    public let endDate: Date?
    public let ndisItemId: UUID?
    public let ndisCode: String?
    
    public init(
        id: UUID,
        clientId: UUID,
        serviceName: String,
        rate: Double,
        unit: String,
        status: String? = nil,
        isActive: Bool = true,
        startDate: Date? = nil,
        endDate: Date? = nil,
        ndisItemId: UUID? = nil,
        ndisCode: String? = nil
    ) {
        self.id = id
        self.clientId = clientId
        self.serviceName = serviceName
        self.rate = rate
        self.unit = unit
        self.status = status
        self.isActive = isActive
        self.startDate = startDate
        self.endDate = endDate
        self.ndisItemId = ndisItemId
        self.ndisCode = ndisCode
    }
}

/// Domain model for an NDIS item
public struct NDISItem: Codable, Equatable, Sendable {
    public let id: UUID
    public let itemNumber: String
    public let name: String
    public let description: String?
    public let category: String?
    public let unit: String?
    public let price: Double?
    public let isCurrent: Bool
    public let effectiveStartDate: Date?
    public let effectiveEndDate: Date?
    public let nonFaceToFaceProvision: Bool?
    public let regionalPrices: [RegionalPriceSnapshot]
    
    public init(
        id: UUID,
        itemNumber: String,
        name: String,
        description: String? = nil,
        category: String? = nil,
        unit: String? = nil,
        price: Double? = nil,
        isCurrent: Bool = true,
        effectiveStartDate: Date? = nil,
        effectiveEndDate: Date? = nil,
        nonFaceToFaceProvision: Bool? = nil,
        regionalPrices: [RegionalPriceSnapshot] = []
    ) {
        self.id = id
        self.itemNumber = itemNumber
        self.name = name
        self.description = description
        self.category = category
        self.unit = unit
        self.price = price
        self.isCurrent = isCurrent
        self.effectiveStartDate = effectiveStartDate
        self.effectiveEndDate = effectiveEndDate
        self.nonFaceToFaceProvision = nonFaceToFaceProvision
        self.regionalPrices = regionalPrices
    }
    
    // MARK: - Computed Properties
    
    public var effectiveDateRange: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if let startDate = effectiveStartDate, let endDate = effectiveEndDate {
            return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
        } else if let startDate = effectiveStartDate {
            return "From \(formatter.string(from: startDate))"
        } else if let endDate = effectiveEndDate {
            return "Until \(formatter.string(from: endDate))"
        } else {
            return "No date range"
        }
    }
}
