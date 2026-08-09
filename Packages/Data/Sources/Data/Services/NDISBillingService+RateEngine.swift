import Foundation
import Core

extension NDISBillingService {

    // MARK: - Intensity Selector

    func applyIntensitySelector(_ supportItem: NDISItemSnapshot, _ context: NDISBillingInputVector) async throws -> NDISItemSnapshot {
        if context.context.isComplexBehaviour {
            let complexNumber = try mapToComplexBehaviourItem(supportItem.itemNumber)
            return try await lookupSupportItem(complexNumber) ?? supportItem
        } else if context.context.isHighIntensity {
            let highNumber = try mapToHighIntensityItem(supportItem.itemNumber)
            return try await lookupSupportItem(highNumber) ?? supportItem
        }
        return supportItem
    }

    // MARK: - Rate Modifiers

    func getBaseRate(_ supportItem: NDISItemSnapshot) throws -> Double {
        let price = getNotionalPrice(supportItem)
        guard price > 0 else {
            throw NDISBillingError.invalidPrice("No valid price available for support item \(supportItem.itemNumber)")
        }
        return price
    }

    func applyGeoModifier(_ baseRate: Double, _ context: NDISBillingInputVector) throws -> Double {
        let location = isDirectService(context.context) ? context.participant.location : context.provider.location
        // Missing / unresolved MMM → 1.0x after upstream geo gate (IntegrationService) has run.
        let multiplier = configService.getGeoMultiplier(for: location)
        return baseRate * multiplier
    }

    func applyTimeModifier(_ rate: Double, _ context: NDISBillingInputVector) throws -> Double {
        let serviceStart = context.service.startTime
        let serviceEnd   = context.service.endTime
        let workerType   = context.context.providerType
        if isCrossShift(serviceStart, serviceEnd, workerType) {
            let rate1 = try getRateForTime(rate, serviceStart, workerType)
            let rate2 = try getRateForTime(rate, serviceEnd,   workerType)
            return max(rate1, rate2)
        } else {
            return try getRateForTime(rate, serviceStart, workerType)
        }
    }

    func getRateForTime(_ baseRate: Double, _ effectiveTime: Date, _ workerType: String) throws -> Double {
        baseRate * configService.getTimeModifier(for: effectiveTime, providerType: workerType)
    }

    func applyGroupModifier(_ rate: Double, _ context: NDISBillingInputVector) throws -> Double {
        if context.context.isGroupSupport {
            guard context.context.groupSize > 1 else { throw NDISBillingError.invalidGroupSize }
            return rate / Double(context.context.groupSize)
        }
        return rate
    }

    // MARK: - Cross-Shift & Rate Period

    func isCrossShift(_ serviceStart: Date, _ serviceEnd: Date, _ workerType: String) -> Bool {
        let startPeriod = try? getRatePeriod(serviceStart, workerType)
        let endPeriod   = try? getRatePeriod(serviceEnd,   workerType)
        return startPeriod != endPeriod
    }

    func getRatePeriod(_ time: Date, _ workerType: String) throws -> String {
        if isPublicHoliday(time) { return "PublicHoliday" }
        let day = try getDayOfWeek(time)
        if day == "Sunday"   { return "Sunday" }
        if day == "Saturday" { return "Saturday" }
        let normalized = workerType.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.caseInsensitiveCompare(TravelChargeProviderType.dsw.rawValue) == .orderedSame {
            let hour = Calendar.current.component(.hour, from: time)
            if hour >= 20 { return "DSWEvening" }
            if hour <  6  { return "DSWNight" }
            return "DSWDay"
        }
        return "Standard"
    }

    // MARK: - Item Number Mapping

    func mapToComplexBehaviourItem(_ itemNumber: String) throws -> String {
        if itemNumber.contains("_0106_") { return itemNumber }
        let mapped = itemNumber.replacingOccurrences(of: "_0104_", with: "_0106_")
        return mapped == itemNumber ? itemNumber : mapped
    }

    func mapToHighIntensityItem(_ itemNumber: String) throws -> String {
        if itemNumber.contains("_0110_") { return itemNumber }
        let mapped = itemNumber.replacingOccurrences(of: "_0104_", with: "_0110_")
        return mapped == itemNumber ? itemNumber : mapped
    }

    // MARK: - Context Checks

    func isDirectService(_ context: NDISContextInfo) -> Bool {
        !context.isTelehealth && !context.isNonFaceToFace && !context.isNDIAReport
    }

    func handlePrepayment(_ context: NDISBillingInputVector) -> Bool {
        guard let prepayment = context.prepayment else { return false }
        guard prepayment.totalCost > 0,
              prepayment.currentClaimAmount > 0,
              prepayment.currentClaimAmount <= prepayment.totalCost else { return false }
        if prepayment.isFinalClaim {
            return prepayment.currentClaimAmount <= prepayment.totalCost
        }
        return prepayment.currentClaimAmount < prepayment.totalCost
    }

    func handleProgramOfSupport(_ context: NDISBillingInputVector) -> Bool {
        if context.context.participantAttended { return true }
        if context.provider.foundAlternativeWork { return false }
        let maxMissedWeeks = configService.getConfigValueInt("ProgramOfSupport.MaxMissedWeeks")
        if let consecutiveMonths = context.service.consecutiveMonths {
            return consecutiveMonths <= maxMissedWeeks
        }
        return !context.context.isCancellation
    }

    func getPrimaryClaimType(_ context: NDISBillingInputVector) throws -> String {
        if context.context.isTelehealth    { return "Telehealth" }
        if context.context.isIrregularSil  { return "IrregularSILSupport" }
        return "Direct"
    }

    func applyCoPayment(_ claim: NDISClaimableLineItem, _ coPaymentAmount: Decimal) -> NDISClaimableLineItem {
        let newTotal    = max(0, claim.totalAmount - coPaymentAmount)
        let newUnitPrice = claim.quantity > 0 ? newTotal / claim.quantity : 0
        return NDISClaimableLineItem(
            supportItemNumber: claim.supportItemNumber,
            quantity: claim.quantity,
            unitPrice: newUnitPrice,
            totalAmount: newTotal,
            claimType: claim.claimType
        )
    }
}
