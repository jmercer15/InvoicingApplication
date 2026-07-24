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

// MARK: - NDIS Billing Service

@MainActor
public class NDISBillingService {
    let modelContext: ModelContext
    let configService: NDISBillingConfigService
    let logger = Logger(subsystem: "com.invoicing.ndis", category: "BillingService")
    
    
    public init(modelContext: ModelContext, configService: NDISBillingConfigService) {
        self.modelContext = modelContext
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
            if !isProviderRegistered() {
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
        guard let supportItem = try await lookupSupportItem(context.service.supportItemNumber) else {
            throw NDISBillingError.supportItemNotFound
        }
        
        if supportItem.status == "Deactivated" {
            throw NDISBillingError.supportItemDeactivated
        }
        
        if supportItem.status == "Legacy" {
            if !validateLegacyServiceBooking(context.participant.ndisNumber, supportItem.itemNumber, supportItem.effectiveEndDate) {
                throw NDISBillingError.legacyServiceBookingRequired
            }
        }
        
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
                let baseRate = try getBaseRate(effectiveSupportItem)
                let geoModifiedRate = try applyGeoModifier(baseRate, context)
                let timeModifiedRate = try applyTimeModifier(geoModifiedRate, context)
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
            
            if isEligibleForActivityTransport(supportItem) && context.context.isActivityTransport {
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

    // MARK: - Shared Utilities (used across extensions)

    func createLineItem(supportItemNumber: String, quantity: Double, unitPrice: Double, claimType: String) throws -> NDISClaimableLineItem {
        NDISClaimableLineItem(
            supportItemNumber: supportItemNumber,
            quantity: quantity,
            unitPrice: unitPrice,
            totalAmount: quantity * unitPrice,
            claimType: claimType
        )
    }

    func isPublicHoliday(_ date: Date) -> Bool {
        let calendar = Calendar(identifier: .gregorian)
        let year     = calendar.component(.year, from: date)
        let dayStart = calendar.startOfDay(for: date)
        let fixedDates = [
            DateComponents(year: year, month: 1,  day: 1),
            DateComponents(year: year, month: 1,  day: 26),
            DateComponents(year: year, month: 4,  day: 25),
            DateComponents(year: year, month: 12, day: 25),
            DateComponents(year: year, month: 12, day: 26),
        ]
        for components in fixedDates {
            guard let holiday = calendar.date(from: components) else { continue }
            let holidayStart = calendar.startOfDay(for: holiday)
            if dayStart == holidayStart { return true }
            if let observed = observedHolidayDate(for: holiday, calendar: calendar),
               dayStart == calendar.startOfDay(for: observed) { return true }
        }
        return false
    }

    func observedHolidayDate(for holiday: Date, calendar: Calendar) -> Date? {
        let weekday = calendar.component(.weekday, from: holiday)
        switch weekday {
        case 7: return calendar.date(byAdding: .day, value: 2, to: holiday)
        case 1: return calendar.date(byAdding: .day, value: 1, to: holiday)
        default: return nil
        }
    }

    func getDayOfWeek(_ date: Date) throws -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
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

    func getNotionalPrice(_ supportItem: NDISItemSnapshot) -> Double {
        if let price = supportItem.price, price > 0 { return price }
        let regionalPrices = supportItem.regionalPrices.map { $0.amount }.filter { $0 > 0 }
        return regionalPrices.max() ?? 0
    }

    func isProviderRegistered() -> Bool {
        UserDefaults.standard.bool(forKey: "isRegisteredNDISProvider")
    }

    func lookupSupportItem(_ itemNumber: String) async throws -> NDISItemSnapshot? {
        let predicate  = #Predicate<NDISItem> { $0.itemNumber == itemNumber }
        let descriptor = FetchDescriptor<NDISItem>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.effectiveStartDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first?.snapshot()
    }

    func validateLegacyServiceBooking(_ ndisNumber: String, _ supportItemNumber: String, _ legacyTransitionDate: Date?) -> Bool {
        guard !ndisNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !supportItemNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard let transitionDate = legacyTransitionDate else { return true }
        return Date() <= transitionDate
    }
}

// NDISSupportItem struct removed in favor of Core.NDISItem.
