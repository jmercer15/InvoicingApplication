import os
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
    /// Minutes travelling to the session (before). Prefer over collapsing into `travelTime`.
    public var travelTimeTo: Double = 0
    /// Minutes travelling from the session (after).
    public var travelTimeFrom: Double = 0
    public var travelTolls: Double = 0
    public var travelParking: Double = 0
    public var travelMMMZoneDescriptor: String?
    /// Prefer this amount for ActivityTransport when set (from persisted `TravelCharge.chargeAmount`).
    public var activityTransportChargeAmount: Double?
    /// Prefer this amount for ProviderTravel_Labour when set (from labour `TravelCharge.chargeAmount`).
    public var providerTravelLabourChargeAmount: Double?
    /// Prefer this amount for ProviderTravel_NonLabour when set (from non-labour `TravelCharge.chargeAmount`).
    public var providerTravelNonLabourChargeAmount: Double?
    /// From persisted `TravelCharge.vehicleType` (modified/bus → true).
    public var isModifiedVehicle: Bool = false

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

// MARK: - Automation Result

public struct AutomationResult: Sendable {
    public enum Status: Sendable {
        case notStarted
        case validating
        case geocoding
        case calculatingTravel
        case determiningGeographic
        case determiningTime
        case determiningTravel
        case determiningServiceType
        case completed
        case failed
    }
    
    public private(set) var status: Status = .notStarted
    public private(set) var errors: [String] = []
    public private(set) var warnings: [String] = []
    public private(set) var isCompleted = false
    public private(set) var startTime = Date()
    public private(set) var endTime: Date?
    
    public var hasErrors: Bool { !errors.isEmpty }
    public var hasWarnings: Bool { !warnings.isEmpty }
    public var duration: TimeInterval { 
        guard let endTime = endTime else { return Date().timeIntervalSince(startTime) }
        return endTime.timeIntervalSince(startTime)
    }
    
    public init() {}
    
    public mutating func updateStatus(_ newStatus: Status) {
        status = newStatus
    }
    
    public mutating func addError(_ error: String) {
        errors.append(error)
        Logger.automation.warning("❌ [NDIS Automation] Error: \(error)")
    }
    
    public mutating func addWarning(_ warning: String) {
        warnings.append(warning)
        Logger.automation.warning("⚠️ [NDIS Automation] Warning: \(warning)")
    }
    
    public mutating func markCompleted() {
        isCompleted = true
        status = .completed
        endTime = Date()
        let totalDuration = duration
        Logger.automation.info("✅ [NDIS Automation] Completed in \(String(format: "%.2f", totalDuration)) seconds")
    }
    
    public mutating func markFailed() {
        status = .failed
        endTime = Date()
        let totalDuration = duration
        Logger.automation.error("❌ [NDIS Automation] Failed after \(String(format: "%.2f", totalDuration)) seconds")
    }
}
