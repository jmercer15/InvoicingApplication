import Foundation

public enum TravelDirection: String, Sendable { case before, after }

public struct BusinessRules {
    public var nonBillableStatuses: Set<String> = ["cancelled", "non-billable"]
    public var maxTravelDistance: Double? = 200.0
    public var maxTravelTime: Double? = 120.0 // minutes
    public var allowedChargeTypes: Set<String>?
    public var defaultTravelTime: Double = 30.0 // minutes
    public var defaultParkingCost: Double? = 3.0 // Default parking cost
    public var defaultTollCost: Double? // Default toll cost

    public init() {}
}

public struct UserPreferences {
    public var averageSpeed: Double? = 50.0 // km/h
    public var preferredVehicleType: String?
    public var preferredParkingCost: Double? // User's preferred parking cost
    public var preferredTollCost: Double? // User's preferred toll cost

    public init() {}
}

