import Foundation

/// Input vector for the NDIS billing algorithm.
public struct NDISBillingInputVector: Sendable {
    public let participant: NDISParticipantInfo
    public let provider: NDISProviderInfo
    public let service: NDISServiceInfo
    public let agreement: NDISAgreementInfo
    public let context: NDISContextInfo
    public let travel: NDISTravelInfo?
    public let transport: NDISTransportInfo?
    public let cancellation: NDISCancellationInfo?
    public let prepayment: NDISPrepaymentInfo?

    public init(
        participant: NDISParticipantInfo,
        provider: NDISProviderInfo,
        service: NDISServiceInfo,
        agreement: NDISAgreementInfo,
        context: NDISContextInfo,
        travel: NDISTravelInfo? = nil,
        transport: NDISTransportInfo? = nil,
        cancellation: NDISCancellationInfo? = nil,
        prepayment: NDISPrepaymentInfo? = nil
    ) {
        self.participant = participant
        self.provider = provider
        self.service = service
        self.agreement = agreement
        self.context = context
        self.travel = travel
        self.transport = transport
        self.cancellation = cancellation
        self.prepayment = prepayment
    }
}

/// Participant identity and plan context supplied to the billing algorithm.
public struct NDISParticipantInfo: Sendable {
    public let ndisNumber: String
    public let planManagementType: String
    public let location: NDISLocation

    public init(ndisNumber: String, planManagementType: String, location: NDISLocation) {
        self.ndisNumber = ndisNumber
        self.planManagementType = planManagementType
        self.location = location
    }
}

/// Registered provider identity and location for claim-path validation.
public struct NDISProviderInfo: Sendable {
    public let abn: String
    public let location: NDISLocation
    public let foundAlternativeWork: Bool

    public init(abn: String, location: NDISLocation, foundAlternativeWork: Bool) {
        self.abn = abn
        self.location = location
        self.foundAlternativeWork = foundAlternativeWork
    }
}

/// Delivered support session details including timing, quantity, and catalogue item.
public struct NDISServiceInfo: Sendable {
    public let supportItemNumber: String
    public let startTime: Date
    public let endTime: Date
    public let duration: Double
    public let quantity: Double
    public let date: Date
    public let hoursPerMonth: Double?
    public let consecutiveMonths: Int?
    public let category: String?
    public let silVacancyId: String?

    public init(
        supportItemNumber: String,
        startTime: Date,
        endTime: Date,
        duration: Double,
        quantity: Double,
        date: Date,
        hoursPerMonth: Double? = nil,
        consecutiveMonths: Int? = nil,
        category: String? = nil,
        silVacancyId: String? = nil
    ) {
        self.supportItemNumber = supportItemNumber
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.quantity = quantity
        self.date = date
        self.hoursPerMonth = hoursPerMonth
        self.consecutiveMonths = consecutiveMonths
        self.category = category
        self.silVacancyId = silVacancyId
    }
}

/// Service-agreement pricing and travel-rate terms for a billed session.
public struct NDISAgreementInfo: Sendable {
    public let agreedPrice: Double
    public let agreedCancellationPolicy: String?
    public let agreedTravelRatePerKM: Double?

    public init(agreedPrice: Double, agreedCancellationPolicy: String? = nil, agreedTravelRatePerKM: Double? = nil) {
        self.agreedPrice = agreedPrice
        self.agreedCancellationPolicy = agreedCancellationPolicy
        self.agreedTravelRatePerKM = agreedTravelRatePerKM
    }
}

/// Claim modifiers, group sizing, attendance, and provider classification flags.
public struct NDISContextInfo: Sendable {
    public let isPrepaymentClaim: Bool
    public let isSubscriptionClaim: Bool
    public let isBereavementClaim: Bool
    public let isCancellation: Bool
    public let isProviderTravel: Bool
    public let isActivityTransport: Bool
    public let isNonFaceToFace: Bool
    public let isNDIAReport: Bool
    public let isShadowShift: Bool
    public let isSilUnplannedExit: Bool
    public let isComplexBehaviour: Bool
    public let isHighIntensity: Bool
    public let isGroupSupport: Bool
    public let isTelehealth: Bool
    public let isIrregularSil: Bool
    public let isDirectService: Bool

    public let groupSize: Int
    public let travelGroupSize: Int
    public let transportGroupSize: Int
    public let participantAttended: Bool
    public let nonFaceToFaceDuration: Double?
    public let ndiaReportDuration: Double?
    public let nonFaceToFaceActivityDescription: String?
    public let coPaymentAmount: Double

    public let travelTimeTo: Double?
    public let travelTimeFrom: Double?
    public let travelKilometres: Double?
    public let travelTolls: Double?
    public let travelParking: Double?

    /// Worker classification for time-of-day loadings (`"DSW"`, `"Therapist"`, `"Nurse"`).
    public let providerType: String

    public init(
        isPrepaymentClaim: Bool = false,
        isSubscriptionClaim: Bool = false,
        isBereavementClaim: Bool = false,
        isCancellation: Bool = false,
        isProviderTravel: Bool = false,
        isActivityTransport: Bool = false,
        isNonFaceToFace: Bool = false,
        isNDIAReport: Bool = false,
        isShadowShift: Bool = false,
        isSilUnplannedExit: Bool = false,
        isComplexBehaviour: Bool = false,
        isHighIntensity: Bool = false,
        isGroupSupport: Bool = false,
        isTelehealth: Bool = false,
        isIrregularSil: Bool = false,
        isDirectService: Bool = true,
        groupSize: Int = 1,
        travelGroupSize: Int = 1,
        transportGroupSize: Int = 1,
        participantAttended: Bool = true,
        nonFaceToFaceDuration: Double? = nil,
        ndiaReportDuration: Double? = nil,
        nonFaceToFaceActivityDescription: String? = nil,
        coPaymentAmount: Double = 0,
        travelTimeTo: Double? = nil,
        travelTimeFrom: Double? = nil,
        travelKilometres: Double? = nil,
        travelTolls: Double? = nil,
        travelParking: Double? = nil,
        providerType: String = TravelChargeProviderType.dsw.rawValue
    ) {
        self.isPrepaymentClaim = isPrepaymentClaim
        self.isSubscriptionClaim = isSubscriptionClaim
        self.isBereavementClaim = isBereavementClaim
        self.isCancellation = isCancellation
        self.isProviderTravel = isProviderTravel
        self.isActivityTransport = isActivityTransport
        self.isNonFaceToFace = isNonFaceToFace
        self.isNDIAReport = isNDIAReport
        self.isShadowShift = isShadowShift
        self.isSilUnplannedExit = isSilUnplannedExit
        self.isComplexBehaviour = isComplexBehaviour
        self.isHighIntensity = isHighIntensity
        self.isGroupSupport = isGroupSupport
        self.isTelehealth = isTelehealth
        self.isIrregularSil = isIrregularSil
        self.isDirectService = isDirectService
        self.groupSize = groupSize
        self.travelGroupSize = travelGroupSize
        self.transportGroupSize = transportGroupSize
        self.participantAttended = participantAttended
        self.nonFaceToFaceDuration = nonFaceToFaceDuration
        self.ndiaReportDuration = ndiaReportDuration
        self.nonFaceToFaceActivityDescription = nonFaceToFaceActivityDescription
        self.coPaymentAmount = coPaymentAmount
        self.travelTimeTo = travelTimeTo
        self.travelTimeFrom = travelTimeFrom
        self.travelKilometres = travelKilometres
        self.travelTolls = travelTolls
        self.travelParking = travelParking
        self.providerType = providerType
    }
}

/// Provider-travel time, distance, and parking/toll inputs for travel line items.
public struct NDISTravelInfo: Sendable {
    public let timeTo: Double
    public let timeFrom: Double
    public let kilometres: Double
    public let tolls: Double
    public let parking: Double
    /// When set, ProviderTravel_Labour uses this total instead of hours × rate.
    public let preferredLabourChargeAmount: Double?
    /// When set, ProviderTravel_NonLabour uses this total instead of km × rate.
    public let preferredNonLabourChargeAmount: Double?

    public init(
        timeTo: Double = 0,
        timeFrom: Double = 0,
        kilometres: Double = 0,
        tolls: Double = 0,
        parking: Double = 0,
        preferredLabourChargeAmount: Double? = nil,
        preferredNonLabourChargeAmount: Double? = nil
    ) {
        self.timeTo = timeTo
        self.timeFrom = timeFrom
        self.kilometres = kilometres
        self.tolls = tolls
        self.parking = parking
        self.preferredLabourChargeAmount = preferredLabourChargeAmount
        self.preferredNonLabourChargeAmount = preferredNonLabourChargeAmount
    }
}

/// Activity-transport distance and charge overrides for transport line items.
public struct NDISTransportInfo: Sendable {
    public let kilometres: Double
    public let tolls: Double
    public let parking: Double
    public let isModifiedVehicle: Bool
    /// When set, ActivityTransport uses this total instead of recomputing from km/tolls/parking.
    public let preferredChargeAmount: Double?

    public init(
        kilometres: Double = 0,
        tolls: Double = 0,
        parking: Double = 0,
        isModifiedVehicle: Bool = false,
        preferredChargeAmount: Double? = nil
    ) {
        self.kilometres = kilometres
        self.tolls = tolls
        self.parking = parking
        self.isModifiedVehicle = isModifiedVehicle
        self.preferredChargeAmount = preferredChargeAmount
    }
}

/// Cancellation notice timestamp used for short-notice policy evaluation.
public struct NDISCancellationInfo: Sendable {
    public let noticeTime: Date

    public init(noticeTime: Date) {
        self.noticeTime = noticeTime
    }
}

/// Prepayment or subscription claim amounts tied to a quoted support item.
public struct NDISPrepaymentInfo: Sendable {
    public let supportItemNumber: String
    public let totalCost: Double
    public let currentClaimAmount: Double
    public let isFinalClaim: Bool
    public let quoteId: String

    public init(supportItemNumber: String, totalCost: Double, currentClaimAmount: Double, isFinalClaim: Bool, quoteId: String) {
        self.supportItemNumber = supportItemNumber
        self.totalCost = totalCost
        self.currentClaimAmount = currentClaimAmount
        self.isFinalClaim = isFinalClaim
        self.quoteId = quoteId
    }
}
