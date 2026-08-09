import Foundation

// MARK: - Client Status

public enum ClientStatus: String, CaseIterable, Codable, Sendable {
    case active = "Active"
    case inactive = "Inactive"
    case suspended = "Suspended"
    case archived = "Archived"

    public var displayName: String { rawValue }

    public var color: String {
        switch self {
        case .active: return "green"
        case .inactive: return "orange"
        case .suspended: return "red"
        case .archived: return "gray"
        }
    }
}

// MARK: - Invoice Status

public enum InvoiceStatus: String, CaseIterable, Codable, Sendable {
    case reviewDraft = "review_draft"
    case readyToSend = "ready_to_send"
    case pending = "pending"
    case received = "received"
    case overdue = "overdue"
    case cancelled = "cancelled"
    case voided = "voided"

    public var displayName: String {
        switch self {
        case .reviewDraft: return "Review Draft"
        case .readyToSend: return "Ready To Send"
        case .pending: return "Pending"
        case .received: return "Received"
        case .overdue: return "Overdue"
        case .cancelled: return "Cancelled"
        case .voided: return "Voided"
        }
    }

    public var color: String {
        switch self {
        case .reviewDraft: return "gray"
        case .readyToSend: return "yellow"
        case .pending: return "blue"
        case .received: return "green"
        case .overdue: return "red"
        case .cancelled: return "orange"
        case .voided: return "purple"
        }
    }

    public var isSettled: Bool { self == .received }

    public init?(normalized status: String) {
        self.init(rawValue: status)
    }
}

// MARK: - Session Status

public enum SessionStatus: String, CaseIterable, Codable, Sendable {
    case scheduled = "scheduled"
    case completed = "completed"
    case cancelled = "cancelled"
    case noShow = "no_show"
    case rescheduled = "rescheduled"
    case grouped = "grouped"
    case needsTravel = "needs_travel"
    case reviewDraft = "review_draft"
    case readyToSend = "ready_to_send"
    case pending = "pending"
    case received = "received"

    public var displayName: String {
        switch self {
        case .scheduled: return "Scheduled"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .noShow: return "No Show"
        case .rescheduled: return "Rescheduled"
        case .grouped: return "Grouped"
        case .needsTravel: return "Needs Travel"
        case .reviewDraft: return "Review Draft"
        case .readyToSend: return "Ready to Send"
        case .pending: return "Pending"
        case .received: return "Received"
        }
    }

    /// Canonical token used across workflow features.
    public var token: String { rawValue }

    public var color: String {
        switch self {
        case .scheduled: return "blue"
        case .completed: return "green"
        case .cancelled: return "red"
        case .noShow: return "orange"
        case .rescheduled: return "yellow"
        case .grouped: return "indigo"
        case .needsTravel: return "cyan"
        case .reviewDraft: return "orange"
        case .readyToSend: return "blue"
        case .pending: return "gray"
        case .received: return "green"
        }
    }

    public init?(normalized status: String) {
        self.init(rawValue: status)
    }
}

// MARK: - Unit Type

public enum UnitType: String, CaseIterable, Codable, Sendable {
    case hour = "Hour"
    case session = "Session"
    case item = "Item"
    case each = "Each"
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case project = "Project"

    public var displayName: String { rawValue }
}

// MARK: - NDIS Claim Type

public enum NDISClaimType: String, CaseIterable, Codable, Sendable {
    case direct = "Direct"
    case providerTravel = "ProviderTravel"
    case providerTravelLabour = "ProviderTravel_Labour"
    case providerTravelNonLabour = "ProviderTravel_NonLabour"
    case providerTravelOtherCosts = "ProviderTravel_OtherCosts"
    case activityTransport = "ActivityTransport"
    case establishmentFee = "EstablishmentFee"
    case centreCapitalCost = "CentreCapitalCost"
    case nightTimeSleepover = "NightTimeSleepover"
    case shadowShift = "ShadowShift"
    case therapySupervision = "TherapySupervision"
    case subscription = "Subscription"
    case cancellation = "Cancellation"
    case prepayment = "Prepayment"
    case telehealth = "Telehealth"
    case nonFaceToFace = "NonFaceToFace"
    case ndiaReport = "NDIAReport"
    case irregularSILSupport = "IrregularSILSupport"
    case bereavement = "Bereavement"

    public var displayName: String {
        switch self {
        case .direct: return "Direct Support"
        case .providerTravel: return "Provider Travel"
        case .providerTravelLabour: return "Provider Travel (Labour)"
        case .providerTravelNonLabour: return "Provider Travel (Non-Labour)"
        case .providerTravelOtherCosts: return "Provider Travel (Tolls/Parking)"
        case .activityTransport: return "Activity Transport"
        case .establishmentFee: return "Establishment Fee"
        case .centreCapitalCost: return "Centre Capital Cost"
        case .nightTimeSleepover: return "Night-Time Sleepover"
        case .shadowShift: return "Shadow Shift"
        case .therapySupervision: return "Therapy Supervision"
        case .subscription: return "Subscription"
        case .cancellation: return "Cancellation Fee"
        case .prepayment: return "Prepayment"
        case .telehealth: return "Telehealth"
        case .nonFaceToFace: return "Non-Face-to-Face"
        case .ndiaReport: return "NDIA Report"
        case .irregularSILSupport: return "Irregular SIL Support"
        case .bereavement: return "Bereavement Support"
        }
    }

    /// PACE/BPR claim-type code for bulk payment requests. `nil` means standard (blank column).
    /// Establishment / sleepover / shadow / fee lines use support-item identity, not a claim code.
    public var bprClaimTypeCode: BPRClaimTypeCode? {
        switch self {
        case .providerTravel, .providerTravelLabour, .providerTravelNonLabour, .providerTravelOtherCosts,
             .activityTransport:
            return .tran
        case .nonFaceToFace:
            return .nf2f
        case .telehealth:
            return .thlt
        case .cancellation:
            return .canc
        case .ndiaReport:
            return .repw
        case .irregularSILSupport:
            return .irss
        case .direct, .establishmentFee, .centreCapitalCost, .nightTimeSleepover, .shadowShift,
             .therapySupervision, .subscription, .prepayment, .bereavement:
            return nil
        }
    }

    /// Maps engine/persisted claim-type strings onto PACE codes, including `ProviderTravel_*` prefixes.
    public static func bprClaimTypeCode(fromRaw claimType: String?) -> BPRClaimTypeCode? {
        guard let claimType, !claimType.isEmpty else { return nil }
        if let typed = NDISClaimType(rawValue: claimType) {
            return typed.bprClaimTypeCode
        }
        if claimType.hasPrefix(NDISClaimType.providerTravel.rawValue) {
            return .tran
        }
        return nil
    }
}

// MARK: - Travel Charge Type

public enum TravelChargeType: String, CaseIterable, Codable, Sendable {
    case labour = "labour"
    case nonLabour = "non-labour"
    case activityBased = "activity-based"
    case standard = "Standard"
    case tolls = "Tolls"
    case parking = "Parking"
    case fuel = "Fuel"
    case maintenance = "Maintenance"
    case insurance = "Insurance"

    public var displayName: String { rawValue }
}

// MARK: - Vehicle Type

public enum VehicleType: String, CaseIterable, Codable, Sendable {
    case standardCar = "Standard Car"
    case modifiedBus = "Modified/Bus"
    case car = "Car"
    case motorcycle = "Motorcycle"
    case bicycle = "Bicycle"
    case publicTransport = "Public Transport"
    case taxi = "Taxi"
    case rideshare = "Rideshare"
    case walking = "Walking"

    public var displayName: String { rawValue }
}

// MARK: - Travel Direction

public enum TravelChargeDirection: String, CaseIterable, Codable, Sendable {
    case before = "before"
    case after = "after"
    case toClient = "To Client"
    case fromClient = "From Client"
    case roundTrip = "Round Trip"
    case betweenClients = "Between Clients"

    public var displayName: String { rawValue }
}

// MARK: - Credit History Type

public enum CreditHistoryType: String, CaseIterable, Codable, Sendable {
    case credit = "Credit"
    case refund = "Refund"
    case adjustment = "Adjustment"
    case writeOff = "Write Off"
    case payment = "Payment"
    case creditNote = "Credit Note"

    public var displayName: String { rawValue }

    public var color: String {
        switch self {
        case .credit: return "green"
        case .refund: return "blue"
        case .adjustment: return "orange"
        case .writeOff: return "red"
        case .payment: return "purple"
        case .creditNote: return "cyan"
        }
    }
}

// MARK: - Address Validation Status

public enum AddressValidationStatus: String, CaseIterable, Codable, Sendable {
    case unvalidated = "unvalidated"
    case pending = "pending"
    case valid = "valid"
    case failed = "failed"

    public var displayName: String {
        switch self {
        case .unvalidated: return "Not Validated"
        case .pending: return "Validating..."
        case .valid: return "Valid"
        case .failed: return "Validation Failed"
        }
    }

    public var icon: String {
        switch self {
        case .unvalidated: return "questionmark.circle"
        case .pending: return "clock"
        case .valid: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    public var color: String {
        switch self {
        case .unvalidated: return "gray"
        case .pending: return "blue"
        case .valid: return "green"
        case .failed: return "red"
        }
    }
}

// MARK: - Draft Status

/// Status of a billable draft in the billing hub workflow.
public enum DraftStatus: String, CaseIterable, Codable, Sendable {
    case open = "open"
    case locked = "locked"
    case needsReview = "needs_review"
    case needsInfo = "needs_info"
    case ready = "ready"

    public var displayName: String {
        switch self {
        case .open: return "Open"
        case .locked: return "Locked"
        case .needsReview: return "Needs Review"
        case .needsInfo: return "Needs Info"
        case .ready: return "Ready"
        }
    }
}

// MARK: - Draft Issue Severity

/// Severity of a draft validation issue.
public enum DraftIssueSeverity: String, CaseIterable, Codable, Sendable {
    case blocking = "blocking"
    case warning = "warning"
    case info = "info"

    public var displayName: String {
        switch self {
        case .blocking: return "Blocking"
        case .warning: return "Warning"
        case .info: return "Info"
        }
    }
}

// MARK: - Draft Issue Resolution Kind

/// How a draft issue can be resolved.
public enum DraftIssueResolutionKind: String, CaseIterable, Codable, Sendable {
    case userInput = "user_input"
    case overrideWithReason = "override_with_reason"
    case autoFix = "auto_fix"

    public var displayName: String {
        switch self {
        case .userInput: return "User Input"
        case .overrideWithReason: return "Override With Reason"
        case .autoFix: return "Auto Fix"
        }
    }
}

// MARK: - Credential Type

/// Type of sole trader compliance credential.
public enum CredentialType: String, CaseIterable, Codable, Sendable {
    case workerScreening = "worker_screening"
    case publicLiabilityInsurance = "public_liability_insurance"
    case professionalIndemnityInsurance = "professional_indemnity_insurance"
    case codeOfConduct = "code_of_conduct"

    public var displayName: String {
        switch self {
        case .workerScreening: return "NDIS Worker Screening Check"
        case .publicLiabilityInsurance: return "Public Liability Insurance"
        case .professionalIndemnityInsurance: return "Professional Indemnity Insurance"
        case .codeOfConduct: return "NDIS Code of Conduct"
        }
    }
}



// MARK: - Billing Authority

/// Who has authority for billing (client, parent/guardian, etc.).
public enum BillingAuthority: String, CaseIterable, Codable, Sendable {
    case client = "Client"
    case parentGuardian = "Parent/Guardian"
    case planManager = "Plan Manager"
    case ndia = "NDIA"

    public var displayName: String { rawValue }
}

// MARK: - Credential Status

/// Derived status of a credential based on expiry.
public enum CredentialStatus: String, CaseIterable, Sendable {
    case current = "current"
    case expiringSoon = "expiring_soon"
    case expired = "expired"
    case notProvided = "not_provided"

    public var displayName: String {
        switch self {
        case .current: return "Current"
        case .expiringSoon: return "Expiring Soon"
        case .expired: return "Expired"
        case .notProvided: return "Not Provided"
        }
    }
}
