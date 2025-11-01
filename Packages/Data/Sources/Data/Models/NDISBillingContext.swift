import Foundation

// MARK: - Enhanced Billing Context Data Structure

public struct NDISBillingContext: Hashable, Sendable {
    // Support Item
    public var supportItemNumber: String = ""

    // Service Type
    public var isComplexBehavior: Bool = false
    public var isHighIntensity: Bool = false
    public var isGroupSupport: Bool = false
    public var isTelehealth: Bool = false
    public var isNonFaceToFace: Bool = false

    // Geographic and Time
    public var isRemoteArea: Bool = false
    public var isVeryRemoteArea: Bool = false
    public var isPublicHoliday: Bool = false
    public var isWeekend: Bool = false
    public var isEvening: Bool = false
    public var isNight: Bool = false

    // Travel and Transport
    public var isProviderTravel: Bool = false
    public var isActivityTransport: Bool = false
    public var travelDistance: Double = 0
    public var travelTime: Double = 0
    public var travelTolls: Double = 0
    public var travelParking: Double = 0

    // Special Circumstances
    public var isShadowShift: Bool = false
    public var isSilUnplannedExit: Bool = false
    public var isNdiaReport: Bool = false
    public var isShortNoticeCancellation: Bool = false
    public var isPrepayment: Bool = false

    // Group Support
    public var groupSize: Int = 1

    // Co-payment
    public var coPaymentAmount: Double = 0

    // Auto-determination tracking
    public var autoDeterminedValues: Set<AutoDeterminedValue> = []

    public enum AutoDeterminedValue: String, CaseIterable, Sendable {
        case complexBehavior = "complexBehavior"
        case highIntensity = "highIntensity"
        case groupSupport = "groupSupport"
        case telehealth = "telehealth"
        case nonFaceToFace = "nonFaceToFace"
        case remoteArea = "remoteArea"
        case veryRemoteArea = "veryRemoteArea"
        case publicHoliday = "publicHoliday"
        case weekend = "weekend"
        case evening = "evening"
        case night = "night"
        case providerTravel = "providerTravel"
        case activityTransport = "activityTransport"
        case shadowShift = "shadowShift"
        case silUnplannedExit = "silUnplannedExit"
        case ndiaReport = "ndiaReport"
        case shortNoticeCancellation = "shortNoticeCancellation"
        case travelDetails = "travelDetails"
        case prepayment = "prepayment"
    }

    public mutating func setAutoDetermined(_ value: AutoDeterminedValue) {
        autoDeterminedValues.insert(value)
    }

    public func isAutoDetermined(_ value: AutoDeterminedValue) -> Bool {
        autoDeterminedValues.contains(value)
    }

    // Computed properties for convenience
    public var hasTravel: Bool {
        isProviderTravel || isActivityTransport || travelDistance > 0
    }

    public var isAfterHours: Bool {
        isEvening || isNight || isWeekend || isPublicHoliday
    }

    public var requiresSpecialConsideration: Bool {
        isComplexBehavior || isHighIntensity || isShadowShift || isSilUnplannedExit
    }
    
    public init() {
        // Default initializer - all properties have default values
    }
}
