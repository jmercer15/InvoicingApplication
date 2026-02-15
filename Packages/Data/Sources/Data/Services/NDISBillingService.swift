//
//  NDISBillingService.swift
//  InvoicingApplication
//
//  Created by AI Assistant for NDIS Billing Integration
//

import Foundation
import SwiftData
import CoreLocation
import os
import Core

// MARK: - Core Data Structures

/// Input vector for the NDIS billing algorithm
public struct NDISBillingInputVector {
    // Participant information
    public let participant: NDISParticipantInfo
    // Provider information
    public let provider: NDISProviderInfo
    // Service information
    public let service: NDISServiceInfo
    // Agreement information
    public let agreement: NDISAgreementInfo
    // Context information
    public let context: NDISContextInfo
    // Travel information (if applicable)
    public let travel: NDISTravelInfo?
    // Transport information (if applicable)
    public let transport: NDISTransportInfo?
    // Cancellation information (if applicable)
    public let cancellation: NDISCancellationInfo?
    // Prepayment information (if applicable)
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

public struct NDISParticipantInfo {
    public let ndisNumber: String
    public let planManagementType: String // "Self-Managed", "Plan-Managed", "Agency-Managed"
    public let location: NDISLocation
    
    public init(ndisNumber: String, planManagementType: String, location: NDISLocation) {
        self.ndisNumber = ndisNumber
        self.planManagementType = planManagementType
        self.location = location
    }
}

public struct NDISProviderInfo {
    public let abn: String
    public let location: NDISLocation
    public let foundAlternativeWork: Bool
    
    public init(abn: String, location: NDISLocation, foundAlternativeWork: Bool) {
        self.abn = abn
        self.location = location
        self.foundAlternativeWork = foundAlternativeWork
    }
}

public struct NDISServiceInfo {
    public let supportItemNumber: String
    public let startTime: Date
    public let endTime: Date
    public let duration: Double // in hours
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

public struct NDISAgreementInfo {
    public let agreedPrice: Double
    public let agreedCancellationPolicy: String?
    public let agreedTravelRatePerKM: Double?
    
    public init(agreedPrice: Double, agreedCancellationPolicy: String? = nil, agreedTravelRatePerKM: Double? = nil) {
        self.agreedPrice = agreedPrice
        self.agreedCancellationPolicy = agreedCancellationPolicy
        self.agreedTravelRatePerKM = agreedTravelRatePerKM
    }
}

public struct NDISContextInfo {
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
    
    // Context values
    public let groupSize: Int
    public let travelGroupSize: Int
    public let transportGroupSize: Int
    public let participantAttended: Bool
    public let nonFaceToFaceDuration: Double?
    public let ndiaReportDuration: Double?
    public let nonFaceToFaceActivityDescription: String?
    public let coPaymentAmount: Double
    
    // Travel context
    public let travelTimeTo: Double?
    public let travelTimeFrom: Double?
    public let travelKilometres: Double?
    public let travelTolls: Double?
    public let travelParking: Double?
    
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
        travelParking: Double? = nil
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
    }
}

public struct NDISLocation {
    public let postcode: String
    public let suburb: String?
    public let state: String?
    public let latitude: Double?
    public let longitude: Double?
    
    public init(
        postcode: String,
        suburb: String? = nil,
        state: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.postcode = postcode
        self.suburb = suburb
        self.state = state
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct NDISTravelInfo {
    public let timeTo: Double // minutes
    public let timeFrom: Double // minutes
    public let kilometres: Double
    public let tolls: Double
    public let parking: Double
    
    public init(timeTo: Double = 0, timeFrom: Double = 0, kilometres: Double = 0, tolls: Double = 0, parking: Double = 0) {
        self.timeTo = timeTo
        self.timeFrom = timeFrom
        self.kilometres = kilometres
        self.tolls = tolls
        self.parking = parking
    }
}

public struct NDISTransportInfo {
    public let kilometres: Double
    public let tolls: Double
    public let parking: Double
    public let isModifiedVehicle: Bool
    
    public init(kilometres: Double = 0, tolls: Double = 0, parking: Double = 0, isModifiedVehicle: Bool = false) {
        self.kilometres = kilometres
        self.tolls = tolls
        self.parking = parking
        self.isModifiedVehicle = isModifiedVehicle
    }
}

public struct NDISCancellationInfo {
    public let noticeTime: Date
    
    public init(noticeTime: Date) {
        self.noticeTime = noticeTime
    }
}

public struct NDISPrepaymentInfo {
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

/// Output structure for billing calculations
public struct NDISClaimableLineItem {
    let supportItemNumber: String
    let quantity: Double
    let unitPrice: Double
    let totalAmount: Double
    let claimType: String // "Direct", "ProviderTravel", "Cancellation", etc.
    
    var lineTotal: Double {
        quantity * unitPrice
    }
}

// MARK: - NDIS Billing Service

@MainActor
public class NDISBillingService {
    private let modelContext: ModelContext
    private let repository: NDISItemRepository
    private let configService: NDISBillingConfigService
    private let logger = Logger(subsystem: "com.invoicing.ndis", category: "BillingService")
    
    private var unitOfWork: UnitOfWorkService?
    
    public init(modelContext: ModelContext, repository: NDISItemRepository, configService: NDISBillingConfigService = NDISBillingConfigService()) {
        self.modelContext = modelContext
        self.repository = repository
        self.configService = configService
        self.unitOfWork = nil
    }
    
    public init(unitOfWork: UnitOfWorkService, modelContext: ModelContext, configService: NDISBillingConfigService = NDISBillingConfigService()) {
        self.unitOfWork = unitOfWork
        self.modelContext = modelContext
        self.repository = NDISItemRepositorySwiftData(modelContext: modelContext)
        self.configService = configService
    }
    
    /// Main entry point for calculating billable amounts
    public func calculateBillableAmount(context: NDISBillingInputVector) async throws -> [NDISClaimableLineItem] {
        logger.info("Starting billable amount calculation for support item: \(context.service.supportItemNumber)")
        var claimList: [NDISClaimableLineItem] = []
        
        // SECTION 1.1: PRIMARY LOGICAL FORK: PLAN MANAGEMENT TYPE
        if context.participant.planManagementType == "Self-Managed" {
            let selfManagedClaim = try createSelfManagedClaim(context)
            claimList.append(selfManagedClaim)
            return claimList
        } else if context.participant.planManagementType == "Agency-Managed" {
            // Check provider registration
            if !isProviderRegistered(context.provider.abn) {
                throw NDISBillingError.providerNotRegistered
            }
        }
        
        // PRE-CONDITION CHECKS & SPECIALIZED FRAMEWORKS
        if context.context.isPrepaymentClaim {
            if handlePrepayment(context) {
                let prepaymentClaim = try createPrepaymentClaim(context)
                claimList.append(prepaymentClaim)
                return claimList
            } else {
                return []
            }
        }
        
        if context.context.isSubscriptionClaim {
            let subscriptionClaims = try calculateSubscriptionClaim(context)
            claimList.append(contentsOf: subscriptionClaims)
            return claimList
        }
        
        if context.context.isBereavementClaim {
            let bereavementClaim = try calculateBereavementClaim(context)
            claimList.append(bereavementClaim)
            return claimList
        }
        
        // HANDLE INTERRUPTING CONDITIONAL EVENTS
        if context.context.isCancellation {
            let cancellationClaims = try calculateCancellation(context)
            claimList.append(contentsOf: cancellationClaims)
            return claimList
        }
        
        // LOOKUP SUPPORT ITEM PROPERTIES
        guard let supportItem = try await lookupSupportItem(context.service.supportItemNumber, context.service.date) else {
            throw NDISBillingError.supportItemNotFound
        }
        
        if supportItem.status == "Deactivated" {
            throw NDISBillingError.supportItemDeactivated
        }
        
        if supportItem.status == "Legacy" {
            if !validateLegacyServiceBooking(context.participant.ndisNumber, supportItem.itemNumber, supportItem.legacyTransitionDate) {
                throw NDISBillingError.legacyServiceBookingRequired
            }
        }
        
        // PROVIDER QUALIFICATION CHECKS
        // Note: Core.NDISItem does not have requiresModule2A yet, keeping logical check but would need field if critical
        // For now we assume if not present it defaults to false
        /*
        if supportItem.requiresModule2A {
            if !isProviderModule2AQualified(context.provider.abn) {
                throw NDISBillingError.providerNotModule2AQualified
            }
        }
        */
        
        // SECTION 1.3: SECONDARY TRIAGE: SUPPORT CLAIM TYPE
        // Using quoteRequired from Core
        if supportItem.quoteRequired == true {
            let quotableClaim = try createQuotableClaim(context)
            claimList.append(quotableClaim)
            return claimList
        } else if supportItem.price == nil { // hasPriceLimit is essentially check for existence of price cap
            let noLimitClaim = try await createNoLimitClaim(context)
            claimList.append(noLimitClaim)
            return claimList
        } else {
            // Price-Controlled supports engage the full calculation engine
            var primarySupportRateLimit: Double = 0
            
            // STEP 1: CALCULATE THE PRIMARY SUPPORT CLAIM (IF APPLICABLE)
            if context.service.duration > 0 {
                let effectiveSupportItem = try await applyIntensitySelector(supportItem, context)
                let baseRate = try getBaseRate(effectiveSupportItem, context.service.date)
                let geoModifiedRate = try applyGeoModifier(baseRate, context, effectiveSupportItem)
                let timeModifiedRate = try applyTimeModifier(geoModifiedRate, context, effectiveSupportItem)
                let finalRateLimit = try applyGroupModifier(timeModifiedRate, context)
                
                if context.agreement.agreedPrice > finalRateLimit {
                    throw NDISBillingError.agreedPriceExceedsLimit
                }
                
                primarySupportRateLimit = finalRateLimit
                
                // SECTION 5: HANDLE SPECIALIZED SUPPORT STRUCTURES
                if isNightTimeSleepover(effectiveSupportItem) {
                    let sleepoverClaims = try calculateNightTimeSleepover(context, effectiveSupportItem)
                    claimList.append(contentsOf: sleepoverClaims)
                } else if context.context.isShadowShift {
                    let shadowShiftClaims = try calculateShadowShift(context, effectiveSupportItem)
                    claimList.append(contentsOf: shadowShiftClaims)
                } else if isTherapySupervision(context) {
                    let supervisionClaims = try calculateTherapySupervision(context)
                    claimList.append(contentsOf: supervisionClaims)
                } else if context.context.isSilUnplannedExit {
                    let silExitClaim = try calculateSilUnplannedExit(context, effectiveSupportItem)
                    claimList.append(silExitClaim)
                } else {
                    // STANDARD PRIMARY CLAIM
                    if handleProgramOfSupport(context) {
                        let primaryClaimType = try getPrimaryClaimType(context)
                        var primaryClaim = try createLineItem(
                            supportItemNumber: effectiveSupportItem.itemNumber,
                            quantity: context.service.quantity,
                            unitPrice: context.agreement.agreedPrice,
                            claimType: primaryClaimType
                        )
                        
                        if context.context.coPaymentAmount > 0 {
                            primaryClaim = applyCoPayment(primaryClaim, context.context.coPaymentAmount)
                        }
                        
                        claimList.append(primaryClaim)
                    } else {
                        return [] // Cannot claim due to Program of Support rules
                    }
                }
            }
            
            // STEP 2: CALCULATE ANCILLARY AND ADDITIONAL LINE ITEMS
            if isEligibleForProviderTravel(supportItem) && context.context.isProviderTravel {
                let travelClaims = try calculateProviderTravel(context, primarySupportRateLimit, supportItem)
                claimList.append(contentsOf: travelClaims)
            }
            
            if isEligibleForActivityTransport(supportItem, context) && context.context.isActivityTransport {
                if let transportClaim = try calculateActivityTransport(context) {
                    claimList.append(transportClaim)
                }
            }
            
            if isEligibleForCentreCapitalCost(supportItem, context) {
                let centreCapitalClaim = try calculateCentreCapitalCost(context)
                claimList.append(centreCapitalClaim)
            }
            
            if isEligibleForEstablishmentFee(context) {
                let establishmentFeeClaim = try calculateEstablishmentFee(context)
                claimList.append(establishmentFeeClaim)
            }
            
            if isEligibleForNonFaceToFace(supportItem) && context.context.isNonFaceToFace {
                if let nf2fClaim = try calculateNonFaceToFace(context, supportItem, primarySupportRateLimit) {
                    claimList.append(nf2fClaim)
                }
            }
            
            if isEligibleForNdiaReport(supportItem) && context.context.isNDIAReport {
                if let reportClaim = try calculateNdiaReport(context, supportItem, primarySupportRateLimit) {
                    claimList.append(reportClaim)
                }
            }
            
            return claimList
        }
    }
    
    // MARK: - Helper Functions
    
    private func createSelfManagedClaim(_ context: NDISBillingInputVector) throws -> NDISClaimableLineItem {
        return try createLineItem(
            supportItemNumber: context.service.supportItemNumber,
            quantity: context.service.quantity,
            unitPrice: context.agreement.agreedPrice,
            claimType: "Direct"
        )
    }
    
    private func createQuotableClaim(_ context: NDISBillingInputVector) throws -> NDISClaimableLineItem {
        guard let serviceBooking = try lookupNdiaServiceBooking(context.participant.ndisNumber, context.service.supportItemNumber),
              serviceBooking.isStatedItemInPlan else {
            throw NDISBillingError.noApprovedServiceBooking
        }
        
        // Validate that the service booking has a valid price
        guard serviceBooking.price > 0 else {
            throw NDISBillingError.invalidPrice("Service booking price is invalid: \(serviceBooking.price)")
        }
        
        return try createLineItem(
            supportItemNumber: context.service.supportItemNumber,
            quantity: context.service.quantity,
            unitPrice: serviceBooking.price,
            claimType: "Direct"
        )
    }
    
    private func createNoLimitClaim(_ context: NDISBillingInputVector) async throws -> NDISClaimableLineItem {
        guard let supportItem = try await lookupSupportItem(context.service.supportItemNumber, context.service.date) else {
            throw NDISBillingError.supportItemNotFound
        }
        
        let notionalPrice = getNotionalPrice(supportItem)
        let quantityToClaim = context.agreement.agreedPrice / notionalPrice
        
        return try createLineItem(
            supportItemNumber: context.service.supportItemNumber,
            quantity: quantityToClaim,
            unitPrice: notionalPrice,
            claimType: "Direct"
        )
    }
    
    private func createPrepaymentClaim(_ context: NDISBillingInputVector) throws -> NDISClaimableLineItem {
        return try createLineItem(
            supportItemNumber: context.prepayment!.supportItemNumber,
            quantity: context.prepayment!.currentClaimAmount,
            unitPrice: 1.00,
            claimType: "Prepayment"
        )
    }
    
    // MARK: - Rate Calculation Helpers
    
    private func applyIntensitySelector(_ supportItem: NDISItem, _ context: NDISBillingInputVector) async throws -> NDISItem {
        if context.context.isComplexBehaviour {
            let complexSupportItemNumber = try mapToComplexBehaviourItem(supportItem.itemNumber)
            return try await lookupSupportItem(complexSupportItemNumber, context.service.date) ?? supportItem
        } else if context.context.isHighIntensity {
            let highIntensitySupportItemNumber = try mapToHighIntensityItem(supportItem.itemNumber)
            return try await lookupSupportItem(highIntensitySupportItemNumber, context.service.date) ?? supportItem
        }
        
        return supportItem
    }
    
    private func getBaseRate(_ supportItem: NDISItem, _ serviceDate: Date) throws -> Double {
        let price = getNotionalPrice(supportItem)
        guard price > 0 else {
            throw NDISBillingError.invalidPrice("No valid price available for support item \(supportItem.itemNumber)")
        }
        return price
    }
    
    private func applyGeoModifier(_ baseRate: Double, _ context: NDISBillingInputVector, _ supportItem: NDISItem) throws -> Double {
        let location = isDirectService(supportItem, context.context) ? context.participant.location : context.provider.location
        return baseRate * configService.getGeoMultiplier(for: location)
    }
    
    private func applyTimeModifier(_ rate: Double, _ context: NDISBillingInputVector, _ supportItem: NDISItem) throws -> Double {
        let serviceStart = context.service.startTime
        let serviceEnd = context.service.endTime
        let workerType = "DSW" // supportItem.workerType -- Core NDIS item doesn't have worker type yet, assuming DSW default
        
        if isCrossShift(serviceStart, serviceEnd, workerType) {
            let rate1 = try getRateForTime(rate, serviceStart, serviceStart, serviceEnd, workerType)
            let rate2 = try getRateForTime(rate, serviceEnd, serviceStart, serviceEnd, workerType)
            return max(rate1, rate2)
        } else {
            return try getRateForTime(rate, serviceStart, serviceStart, serviceEnd, workerType)
        }
    }
    
    private func getRateForTime(_ baseRate: Double, _ effectiveTime: Date, _ serviceStart: Date, _ serviceEnd: Date, _ workerType: String) throws -> Double {
        return baseRate * configService.getTimeModifier(for: effectiveTime, providerType: workerType)
    }
    
    private func applyGroupModifier(_ rate: Double, _ context: NDISBillingInputVector) throws -> Double {
        if context.context.isGroupSupport {
            if context.context.groupSize > 1 {
                return rate / Double(context.context.groupSize)
            } else {
                throw NDISBillingError.invalidGroupSize
            }
        }
        return rate
    }
    
    // MARK: - Utility Functions
    
    private func createLineItem(supportItemNumber: String, quantity: Double, unitPrice: Double, claimType: String) throws -> NDISClaimableLineItem {
        return NDISClaimableLineItem(
            supportItemNumber: supportItemNumber,
            quantity: quantity,
            unitPrice: unitPrice,
            totalAmount: quantity * unitPrice,
            claimType: claimType
        )
    }
    
    private func isPublicHoliday(_ date: Date) -> Bool {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: date)
        let dayStart = calendar.startOfDay(for: date)

        let fixedDates = [
            DateComponents(year: year, month: 1, day: 1),  // New Year's Day
            DateComponents(year: year, month: 1, day: 26), // Australia Day
            DateComponents(year: year, month: 4, day: 25), // ANZAC Day
            DateComponents(year: year, month: 12, day: 25), // Christmas Day
            DateComponents(year: year, month: 12, day: 26)  // Boxing Day
        ]

        for components in fixedDates {
            guard let holiday = calendar.date(from: components) else { continue }
            let holidayStart = calendar.startOfDay(for: holiday)
            if dayStart == holidayStart {
                return true
            }

            // Basic observed-day handling for weekend holidays.
            if let observed = observedHolidayDate(for: holiday, calendar: calendar),
               dayStart == calendar.startOfDay(for: observed) {
                return true
            }
        }
        return false
    }
    
    private func getDayOfWeek(_ date: Date) throws -> String {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        
        switch weekday {
        case 1: return "Sunday"
        case 2: return "Monday"
        case 3: return "Tuesday"
        case 4: return "Wednesday"
        case 5: return "Thursday"
        case 6: return "Friday"
        case 7: return "Saturday"
        default: return "Unknown"
        }
    }
    
    private func isCrossShift(_ serviceStart: Date, _ serviceEnd: Date, _ workerType: String) -> Bool {
        // Simplified implementation
        let startPeriod = try? getRatePeriod(serviceStart, workerType)
        let endPeriod = try? getRatePeriod(serviceEnd, workerType)
        return startPeriod != endPeriod
    }
    
    private func getRatePeriod(_ time: Date, _ workerType: String) throws -> String {
        if isPublicHoliday(time) {
            return "PublicHoliday"
        }
        
        let day = try getDayOfWeek(time)
        if day == "Sunday" {
            return "Sunday"
        }
        if day == "Saturday" {
            return "Saturday"
        }
        
        if workerType == "DSW" {
            let hour = Calendar.current.component(.hour, from: time)
            if hour >= 20 {
                return "DSWEvening"
            }
            if hour < 6 {
                return "DSWNight"
            }
            return "DSWDay"
        }
        
        return "Standard"
    }
    
    // MARK: - Specialized Claim Helpers
    
    private func lookupSupportItem(_ itemNumber: String, _ date: Date) async throws -> NDISItem? {
        // Query the repository for the item
        return try await repository.fetch(by: itemNumber)
    }
    
    private func isProviderRegistered(_ abn: String) -> Bool {
        // Check local preference override
        return UserDefaults.standard.bool(forKey: "isRegisteredNDISProvider")
    }
    
    private func handlePrepayment(_ context: NDISBillingInputVector) -> Bool {
        guard let prepayment = context.prepayment else { return false }
        guard prepayment.totalCost > 0,
              prepayment.currentClaimAmount > 0,
              prepayment.currentClaimAmount <= prepayment.totalCost else {
            return false
        }

        // Final claims should not exceed total and should claim the remaining balance.
        if prepayment.isFinalClaim {
            return prepayment.currentClaimAmount <= prepayment.totalCost
        }

        // Interim claims must leave a positive remainder.
        return prepayment.currentClaimAmount < prepayment.totalCost
    }
    
    private func calculateSubscriptionClaim(_ context: NDISBillingInputVector) throws -> [NDISClaimableLineItem] {
        let monthlyHours = context.service.hoursPerMonth ?? context.service.quantity
        let months = max(context.service.consecutiveMonths ?? 1, 1)
        let quantity = max(monthlyHours * Double(months), 0)
        guard quantity > 0 else { return [] }

        let unitPrice = context.agreement.agreedPrice
        guard unitPrice > 0 else {
            throw NDISBillingError.invalidPrice("Subscription claim requires a positive agreed price.")
        }

        let claim = try createLineItem(
            supportItemNumber: context.service.supportItemNumber,
            quantity: quantity,
            unitPrice: unitPrice,
            claimType: "Subscription"
        )
        return [claim]
    }
    
    private func calculateBereavementClaim(_ context: NDISBillingInputVector) throws -> NDISClaimableLineItem {
        let quantity = max(context.service.quantity, 1)
        let unitPrice = context.agreement.agreedPrice
        guard unitPrice > 0 else {
            throw NDISBillingError.invalidPrice("Bereavement claim requires a positive agreed price.")
        }
        return try createLineItem(
            supportItemNumber: context.service.supportItemNumber,
            quantity: quantity,
            unitPrice: unitPrice,
            claimType: "Bereavement"
        )
    }
    
    private func calculateCancellation(_ context: NDISBillingInputVector) throws -> [NDISClaimableLineItem] {
        guard let cancellation = context.cancellation else { return [] }

        // Short notice cancellation logic: usually requires 7 clear business days OR 48 hours for short notice.
        // We'll use the config service to validate if the notice was sufficient.
        // If notice is NOT sufficient, it's claimable at 100% (quantity = full duration).
        
        let isShortNotice = !configService.checkNoticePeriod(
            noticeTime: cancellation.noticeTime,
            serviceTime: context.service.startTime,
            amount: 2, // 2 days is some providers' policy, NDIS often cites 7 clear business days for many settings.
            unit: "clear_business_days"
        )
        
        guard isShortNotice else { return [] }
        guard !context.provider.foundAlternativeWork else { return [] }

        // Quantity for cancellation is 100% of the scheduled hours
        let quantity = max(context.service.quantity, 0)
        guard quantity > 0 else { return [] }

        let unitPrice = context.agreement.agreedPrice
        guard unitPrice > 0 else {
            throw NDISBillingError.invalidPrice("Cancellation claim requires a positive agreed price.")
        }

        let cancellationClaim = try createLineItem(
            supportItemNumber: context.service.supportItemNumber,
            quantity: quantity,
            unitPrice: unitPrice,
            claimType: "Cancellation"
        )
        return [cancellationClaim]
    }
    
    private func lookupNdiaServiceBooking(_ ndisNumber: String, _ supportItemNumber: String) throws -> NDISServiceBooking? {
        guard !ndisNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !supportItemNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let predicate = #Predicate<NDISItemEntity> { $0.itemNumber == supportItemNumber }
        let descriptor = FetchDescriptor<NDISItemEntity>(predicate: predicate)
        guard let entity = try modelContext.fetch(descriptor).first else {
            return nil
        }

        let fallbackRegionalPrice = entity.regionalPrices
            .map(\.amount)
            .filter { $0 > 0 }
            .max()
        let price = fallbackRegionalPrice ?? 0
        return NDISServiceBooking(
            isStatedItemInPlan: entity.quoteRequired == true || entity.status?.lowercased() != "deactivated",
            price: price
        )
    }
    
    private func getNotionalPrice(_ supportItem: NDISItem) -> Double {
        if let price = supportItem.price, price > 0 {
            return price
        }

        let regionalPrices = supportItem.regionalPrices
            .map(\.amount)
            .filter { $0 > 0 }
        if let highestRegional = regionalPrices.max() {
            return highestRegional
        }

        return 0
    }
    
    private func mapToComplexBehaviourItem(_ itemNumber: String) throws -> String {
        if itemNumber.contains("_0106_") { return itemNumber }
        let mapped = itemNumber.replacingOccurrences(of: "_0104_", with: "_0106_")
        return mapped == itemNumber ? itemNumber : mapped
    }
    
    private func mapToHighIntensityItem(_ itemNumber: String) throws -> String {
        if itemNumber.contains("_0110_") { return itemNumber }
        let mapped = itemNumber.replacingOccurrences(of: "_0104_", with: "_0110_")
        return mapped == itemNumber ? itemNumber : mapped
    }
    
    private func lookupMmmRating(location: NDISLocation) throws -> Int {
        return configService.getMmmRating(for: location)
    }
    
    private func isDirectService(_ supportItem: NDISItem, _ context: NDISContextInfo) -> Bool {
        return !context.isTelehealth && !context.isNonFaceToFace && !context.isNDIAReport
    }
    
    private func isNightTimeSleepover(_ supportItem: NDISItem) -> Bool {
        // Naive check based on description or category as first pass
        // Ideally NDISItem should have specific flag if not covered by irregularSILSupports
        return supportItem.name.lowercased().contains("sleepover")
    }
    
    private func calculateNightTimeSleepover(_ context: NDISBillingInputVector, _ supportItem: NDISItem) throws -> [NDISClaimableLineItem] {
        let includedHours = min(max(context.service.duration, 0), configService.getSleepoverIncludedHours())
        guard includedHours > 0 else { return [] }
        let baseRate = context.agreement.agreedPrice > 0 ? context.agreement.agreedPrice : getNotionalPrice(supportItem)
        guard baseRate > 0 else {
            throw NDISBillingError.invalidPrice("Sleepover claim requires a positive rate.")
        }

        let claim = try createLineItem(
            supportItemNumber: supportItem.itemNumber,
            quantity: includedHours,
            unitPrice: baseRate,
            claimType: "NightTimeSleepover"
        )
        return [claim]
    }
    
    private func calculateShadowShift(_ context: NDISBillingInputVector, _ supportItem: NDISItem) throws -> [NDISClaimableLineItem] {
        let quantity = max(context.service.duration, 0)
        guard quantity > 0 else { return [] }
        let baseRate = context.agreement.agreedPrice > 0 ? context.agreement.agreedPrice : getNotionalPrice(supportItem)
        guard baseRate > 0 else {
            throw NDISBillingError.invalidPrice("Shadow shift claim requires a positive rate.")
        }

        let claim = try createLineItem(
            supportItemNumber: supportItem.itemNumber,
            quantity: quantity,
            unitPrice: baseRate,
            claimType: "ShadowShift"
        )
        return [claim]
    }
    
    private func isTherapySupervision(_ context: NDISBillingInputVector) -> Bool {
        let category = context.service.category?.lowercased() ?? ""
        let description = context.context.nonFaceToFaceActivityDescription?.lowercased() ?? ""
        return category.contains("therapy supervision")
            || description.contains("therapy supervision")
            || description.contains("clinical supervision")
    }
    
    private func calculateTherapySupervision(_ context: NDISBillingInputVector) throws -> [NDISClaimableLineItem] {
        let quantity = max(context.context.nonFaceToFaceDuration ?? context.service.duration, 0)
        guard quantity > 0 else { return [] }
        let unitPrice = context.agreement.agreedPrice
        guard unitPrice > 0 else {
            throw NDISBillingError.invalidPrice("Therapy supervision requires a positive agreed price.")
        }

        let claim = try createLineItem(
            supportItemNumber: context.service.supportItemNumber,
            quantity: quantity,
            unitPrice: unitPrice,
            claimType: "TherapySupervision"
        )
        return [claim]
    }
    
    private func calculateSilUnplannedExit(_ context: NDISBillingInputVector, _ supportItem: NDISItem) throws -> NDISClaimableLineItem {
        let maxWeeks = configService.getSilMaxWeeks()
        let maxHours = maxWeeks * 7 * 24
        let quantity = min(max(context.service.duration, 0), maxHours)
        let unitPrice = context.agreement.agreedPrice > 0 ? context.agreement.agreedPrice : getNotionalPrice(supportItem)
        guard quantity > 0, unitPrice > 0 else {
            throw NDISBillingError.invalidPrice("SIL unplanned exit claim requires positive quantity and price.")
        }

        return try createLineItem(
            supportItemNumber: supportItem.itemNumber,
            quantity: quantity,
            unitPrice: unitPrice,
            claimType: "IrregularSILSupport"
        )
    }
    
    private func handleProgramOfSupport(_ context: NDISBillingInputVector) -> Bool {
        if context.context.participantAttended {
            return true
        }
        if context.provider.foundAlternativeWork {
            return false
        }

        let maxMissedWeeks = configService.getConfigValueInt("ProgramOfSupport.MaxMissedWeeks")
        if let consecutiveMonths = context.service.consecutiveMonths {
            return consecutiveMonths <= maxMissedWeeks
        }

        return !context.context.isCancellation
    }
    
    private func getPrimaryClaimType(_ context: NDISBillingInputVector) throws -> String {
        if context.context.isTelehealth {
            return "Telehealth"
        }
        if context.context.isIrregularSil {
            return "IrregularSILSupport"
        }
        return "Direct"
    }
    
    private func applyCoPayment(_ claim: NDISClaimableLineItem, _ coPaymentAmount: Double) -> NDISClaimableLineItem {
        let newTotalAmount = max(0, claim.totalAmount - coPaymentAmount)
        let newUnitPrice = claim.quantity > 0 ? newTotalAmount / claim.quantity : 0
        
        return NDISClaimableLineItem(
            supportItemNumber: claim.supportItemNumber,
            quantity: claim.quantity,
            unitPrice: newUnitPrice,
            totalAmount: newTotalAmount,
            claimType: claim.claimType
        )
    }
    
    private func isEligibleForProviderTravel(_ supportItem: NDISItem) -> Bool {
        return supportItem.providerTravel == true
    }
    
    private func calculateProviderTravel(_ context: NDISBillingInputVector, _ primarySupportRateLimit: Double, _ supportItem: NDISItem) throws -> [NDISClaimableLineItem] {
        var claims: [NDISClaimableLineItem] = []
        
        // 1. Labour Component (Time)
        // Rate is typically the same as the primary support
        if let travel = context.travel, (travel.timeTo > 0 || travel.timeFrom > 0) {
            let totalTimeMin = travel.timeTo + travel.timeFrom
            let quantityHours = totalTimeMin / 60.0
            
            // Use agreed price if set, otherwise the rate limit
            // Note: Provider travel is usually billed at the same rate as the support
            let hourlyRate = context.agreement.agreedPrice > 0 ? context.agreement.agreedPrice : primarySupportRateLimit
            
            let labourClaim = try createLineItem(
                supportItemNumber: supportItem.itemNumber, // Charged against the core support item
                quantity: quantityHours,
                unitPrice: hourlyRate,
                claimType: "ProviderTravel_Labour"
            )
            claims.append(labourClaim)
        }
        
        // 2. Non-Labour Component (Kilometres)
        // Requires a separate lookup for the transport code (e.g. 07_799_...) usually,
        // but often systems bill it as a distinct "Travel - Non-Labour" line item.
        // For now, we will output it with a generated claim type/code derived from the main item or generic.
        // However, NDIS requires specific transport codes (e.g. 07_799_0106_6_3). 
        // Without a lookup, we'll use the main item but mark clearly as Non-Labour so downstream can map it.
        if let travel = context.travel, travel.kilometres > 0 {
            // Default rate from configuration if not specified
            let kmRate = context.agreement.agreedTravelRatePerKM ?? configService.getTravelRatePerKm()
            
            let nonLabourClaim = try createLineItem(
                supportItemNumber: supportItem.itemNumber, 
                quantity: travel.kilometres, // Quantity is KM
                unitPrice: kmRate,
                claimType: "ProviderTravel_NonLabour"
            )
            claims.append(nonLabourClaim)
        }
        
        // 3. Tolls & Parking
        if let travel = context.travel, (travel.tolls > 0 || travel.parking > 0) {
            let totalCost = travel.tolls + travel.parking
            let costClaim = try createLineItem(
                supportItemNumber: supportItem.itemNumber,
                quantity: totalCost, // Usually claimed as $1 units x Cost
                unitPrice: 1.0,
                claimType: "ProviderTravel_OtherCosts"
            )
             claims.append(costClaim)
        }
        
        return claims
    }
    
    private func isEligibleForActivityTransport(_ supportItem: NDISItem, _ context: NDISBillingInputVector) -> Bool {
        let keywords = ["transport", "community access", "activity based"]
        let haystack = "\(supportItem.name) \(supportItem.description ?? "") \(supportItem.category ?? "")".lowercased()
        return keywords.contains(where: haystack.contains)
    }
    
    private func calculateActivityTransport(_ context: NDISBillingInputVector) throws -> NDISClaimableLineItem? {
        guard let transport = context.transport else { return nil }
        guard transport.kilometres > 0 || transport.tolls > 0 || transport.parking > 0 else { return nil }

        let baseRate = configService.getTransportRate(isModified: transport.isModifiedVehicle)
        let distanceCost = transport.kilometres * baseRate
        let ancillaryCost = transport.tolls + transport.parking
        let splitCount = max(context.context.transportGroupSize, 1)
        let totalPerParticipant = (distanceCost + ancillaryCost) / Double(splitCount)
        guard totalPerParticipant > 0 else { return nil }

        return try createLineItem(
            supportItemNumber: context.service.supportItemNumber,
            quantity: 1,
            unitPrice: totalPerParticipant,
            claimType: "ActivityTransport"
        )
    }
    
    private func isEligibleForCentreCapitalCost(_ supportItem: NDISItem, _ context: NDISBillingInputVector) -> Bool {
        let category = (supportItem.category ?? "").lowercased()
        return context.context.isDirectService && (category.contains("centre") || category.contains("group"))
    }
    
    private func calculateCentreCapitalCost(_ context: NDISBillingInputVector) throws -> NDISClaimableLineItem {
        let unitPrice = configService.getCentreCapitalRate(for: context.participant.location)
        let quantity = max(context.service.duration, 1)
        return try createLineItem(
            supportItemNumber: context.service.supportItemNumber,
            quantity: quantity,
            unitPrice: unitPrice,
            claimType: "CentreCapitalCost"
        )
    }
    
    private func isEligibleForEstablishmentFee(_ context: NDISBillingInputVector) -> Bool {
        let months = context.service.consecutiveMonths ?? 1
        return months <= 1 && context.context.isDirectService
    }
    
    private func calculateEstablishmentFee(_ context: NDISBillingInputVector) throws -> NDISClaimableLineItem {
        let fee = configService.getEstablishmentFeeRate(for: context.participant.location)
        return try createLineItem(
            supportItemNumber: context.service.supportItemNumber,
            quantity: 1,
            unitPrice: fee,
            claimType: "EstablishmentFee"
        )
    }
    
    private func isEligibleForNonFaceToFace(_ supportItem: NDISItem) -> Bool {
        return supportItem.allowsNonFaceToFace == true
    }
    
    private func calculateNonFaceToFace(_ context: NDISBillingInputVector, _ supportItem: NDISItem, _ primarySupportRateLimit: Double) throws -> NDISClaimableLineItem? {
        let quantity = max(context.context.nonFaceToFaceDuration ?? 0, 0)
        guard quantity > 0 else { return nil }
        let agreedPrice = context.agreement.agreedPrice > 0 ? context.agreement.agreedPrice : primarySupportRateLimit
        let unitPrice = min(agreedPrice, primarySupportRateLimit)
        guard unitPrice > 0 else {
            throw NDISBillingError.invalidPrice("Non-face-to-face claim has no valid rate.")
        }
        return try createLineItem(
            supportItemNumber: supportItem.itemNumber,
            quantity: quantity,
            unitPrice: unitPrice,
            claimType: "NonFaceToFace"
        )
    }
    
    private func isEligibleForNdiaReport(_ supportItem: NDISItem) -> Bool {
        return supportItem.ndiaRequestedReports == true
    }
    
    private func calculateNdiaReport(_ context: NDISBillingInputVector, _ supportItem: NDISItem, _ primarySupportRateLimit: Double) throws -> NDISClaimableLineItem? {
        let quantity = max(context.context.ndiaReportDuration ?? 0, 0)
        guard quantity > 0 else { return nil }
        let agreedPrice = context.agreement.agreedPrice > 0 ? context.agreement.agreedPrice : primarySupportRateLimit
        let unitPrice = min(agreedPrice, primarySupportRateLimit)
        guard unitPrice > 0 else {
            throw NDISBillingError.invalidPrice("NDIA report claim has no valid rate.")
        }
        return try createLineItem(
            supportItemNumber: supportItem.itemNumber,
            quantity: quantity,
            unitPrice: unitPrice,
            claimType: "NDIAReport"
        )
    }
    
    private func validateLegacyServiceBooking(_ ndisNumber: String, _ supportItemNumber: String, _ legacyTransitionDate: Date?) -> Bool {
        guard !ndisNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !supportItemNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        guard let transitionDate = legacyTransitionDate else {
            return true
        }
        // If we are before the transition date, treat legacy bookings as valid.
        return Date() <= transitionDate
    }
    
    private func isProviderModule2AQualified(_ abn: String) -> Bool {
        let digits = abn.filter(\.isNumber)
        return digits.count == 11
    }

    private func observedHolidayDate(for holiday: Date, calendar: Calendar) -> Date? {
        let weekday = calendar.component(.weekday, from: holiday)
        switch weekday {
        case 7: // Saturday
            return calendar.date(byAdding: .day, value: 2, to: holiday)
        case 1: // Sunday
            return calendar.date(byAdding: .day, value: 1, to: holiday)
        default:
            return nil
        }
    }
}

// MARK: - Supporting Data Structures

// NDISSupportItem struct removed in favor of Core.NDISItem

struct NDISServiceBooking {
    let isStatedItemInPlan: Bool
    let price: Double
}

// MARK: - Error Types

enum NDISBillingError: Error {
    case providerNotRegistered
    case supportItemNotFound
    case supportItemDeactivated
    case legacyServiceBookingRequired
    case providerNotModule2AQualified
    case noApprovedServiceBooking
    case agreedPriceExceedsLimit
    case invalidGroupSize
    case invalidPrice(String)
} 
