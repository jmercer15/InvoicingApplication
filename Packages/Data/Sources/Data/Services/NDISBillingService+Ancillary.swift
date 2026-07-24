import Foundation
import Core

extension NDISBillingService {

    // MARK: - Night-Time Sleepover

    func isNightTimeSleepover(_ supportItem: NDISItemSnapshot) -> Bool {
        supportItem.name.lowercased().contains("sleepover")
    }

    func calculateNightTimeSleepover(_ context: NDISBillingInputVector, _ supportItem: NDISItemSnapshot) throws -> [NDISClaimableLineItem] {
        let includedHours = min(max(context.service.duration, 0), configService.getSleepoverIncludedHours())
        guard includedHours > 0 else { return [] }
        let baseRate = context.agreement.agreedPrice > 0 ? context.agreement.agreedPrice : getNotionalPrice(supportItem)
        guard baseRate > 0 else {
            throw NDISBillingError.invalidPrice("Sleepover claim requires a positive rate.")
        }
        return [try createLineItem(
            supportItemNumber: supportItem.itemNumber,
            quantity: includedHours,
            unitPrice: baseRate,
            claimType: "NightTimeSleepover"
        )]
    }

    // MARK: - Shadow Shift

    func calculateShadowShift(_ context: NDISBillingInputVector, _ supportItem: NDISItemSnapshot) throws -> [NDISClaimableLineItem] {
        let quantity = max(context.service.duration, 0)
        guard quantity > 0 else { return [] }
        let baseRate = context.agreement.agreedPrice > 0 ? context.agreement.agreedPrice : getNotionalPrice(supportItem)
        guard baseRate > 0 else {
            throw NDISBillingError.invalidPrice("Shadow shift claim requires a positive rate.")
        }
        return [try createLineItem(
            supportItemNumber: supportItem.itemNumber,
            quantity: quantity,
            unitPrice: baseRate,
            claimType: "ShadowShift"
        )]
    }

    // MARK: - Therapy Supervision

    func isTherapySupervision(_ context: NDISBillingInputVector) -> Bool {
        let category    = context.service.category?.lowercased() ?? ""
        let description = context.context.nonFaceToFaceActivityDescription?.lowercased() ?? ""
        return category.contains("therapy supervision")
            || description.contains("therapy supervision")
            || description.contains("clinical supervision")
    }

    func calculateTherapySupervision(_ context: NDISBillingInputVector) throws -> [NDISClaimableLineItem] {
        let quantity = max(context.context.nonFaceToFaceDuration ?? context.service.duration, 0)
        guard quantity > 0 else { return [] }
        let unitPrice = context.agreement.agreedPrice
        guard unitPrice > 0 else {
            throw NDISBillingError.invalidPrice("Therapy supervision requires a positive agreed price.")
        }
        return [try createLineItem(
            supportItemNumber: context.service.supportItemNumber,
            quantity: quantity,
            unitPrice: unitPrice,
            claimType: "TherapySupervision"
        )]
    }

    // MARK: - SIL Unplanned Exit

    func calculateSilUnplannedExit(_ context: NDISBillingInputVector, _ supportItem: NDISItemSnapshot) throws -> NDISClaimableLineItem {
        let maxWeeks  = configService.getSilMaxWeeks()
        let maxHours  = maxWeeks * 7 * 24
        let quantity  = min(max(context.service.duration, 0), maxHours)
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

    // MARK: - Centre Capital Cost

    func isEligibleForCentreCapitalCost(_ supportItem: NDISItemSnapshot, _ context: NDISBillingInputVector) -> Bool {
        let category = (supportItem.category ?? "").lowercased()
        return context.context.isDirectService && (category.contains("centre") || category.contains("group"))
    }

    func calculateCentreCapitalCost(_ context: NDISBillingInputVector) throws -> NDISClaimableLineItem {
        guard let unitPrice = configService.getCentreCapitalRate(for: context.participant.location) else {
            throw NDISBillingError.invalidPrice("Centre capital cost requires coordinates that resolve to an MMM zone.")
        }
        let quantity = max(context.service.duration, 1)
        return try createLineItem(
            supportItemNumber: context.service.supportItemNumber,
            quantity: quantity,
            unitPrice: unitPrice,
            claimType: "CentreCapitalCost"
        )
    }

    // MARK: - Establishment Fee

    func isEligibleForEstablishmentFee(_ context: NDISBillingInputVector) -> Bool {
        let months = context.service.consecutiveMonths ?? 1
        return months <= 1 && context.context.isDirectService
    }

    func calculateEstablishmentFee(_ context: NDISBillingInputVector) throws -> NDISClaimableLineItem {
        guard let fee = configService.getEstablishmentFeeRate(for: context.participant.location) else {
            throw NDISBillingError.invalidPrice("Establishment fee requires coordinates that resolve to an MMM zone.")
        }
        return try createLineItem(
            supportItemNumber: context.service.supportItemNumber,
            quantity: 1,
            unitPrice: fee,
            claimType: "EstablishmentFee"
        )
    }

    // MARK: - Non-Face-to-Face

    func isEligibleForNonFaceToFace(_ supportItem: NDISItemSnapshot) -> Bool {
        supportItem.nonFaceToFaceProvision == true
    }

    func calculateNonFaceToFace(
        _ context: NDISBillingInputVector,
        _ supportItem: NDISItemSnapshot,
        _ primarySupportRateLimit: Double
    ) throws -> NDISClaimableLineItem? {
        let quantity = max(context.context.nonFaceToFaceDuration ?? 0, 0)
        guard quantity > 0 else { return nil }
        let agreedPrice = context.agreement.agreedPrice > 0 ? context.agreement.agreedPrice : primarySupportRateLimit
        let unitPrice   = min(agreedPrice, primarySupportRateLimit)
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

    // MARK: - NDIA Report

    func isEligibleForNdiaReport(_ supportItem: NDISItemSnapshot) -> Bool {
        supportItem.ndiaRequestedReports == true
    }

    func calculateNdiaReport(
        _ context: NDISBillingInputVector,
        _ supportItem: NDISItemSnapshot,
        _ primarySupportRateLimit: Double
    ) throws -> NDISClaimableLineItem? {
        let quantity = max(context.context.ndiaReportDuration ?? 0, 0)
        guard quantity > 0 else { return nil }
        let agreedPrice = context.agreement.agreedPrice > 0 ? context.agreement.agreedPrice : primarySupportRateLimit
        let unitPrice   = min(agreedPrice, primarySupportRateLimit)
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
}
