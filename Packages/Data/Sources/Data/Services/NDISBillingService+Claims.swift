import Foundation
import SwiftData
import Core
import PersistenceModels

extension NDISBillingService {

    // MARK: - Early-Exit Claim Constructors

    func createSelfManagedClaim(_ context: NDISBillingInputVector) throws -> NDISClaimableLineItem {
        try createLineItem(
            supportItemNumber: context.service.supportItemNumber,
            quantity: context.service.quantity,
            unitPrice: context.agreement.agreedPrice,
            claimType: "Direct"
        )
    }

    /// Self-managed plans still show travel on the invoice PDF; claimType kept for line identity.
    func selfManagedTravelLines(_ context: NDISBillingInputVector) async throws -> [NDISClaimableLineItem] {
        guard context.context.isActivityTransport || context.context.isProviderTravel else { return [] }

        if context.context.isActivityTransport {
            if let supportItem = try await lookupSupportItem(context.service.supportItemNumber),
               !isEligibleForActivityTransport(supportItem),
               hasTravelMoney(context) {
                throw NDISBillingError.travelNotEligible(NDISBillingService.activityTravelNotEligibleReason)
            }
            if let transportClaim = try calculateActivityTransport(context) {
                return [transportClaim]
            }
            return []
        }

        guard let supportItem = try await lookupSupportItem(context.service.supportItemNumber) else {
            if hasTravelMoney(context) {
                throw NDISBillingError.travelNotEligible(NDISBillingService.providerTravelNotEligibleReason)
            }
            return []
        }
        guard isEligibleForProviderTravel(supportItem) else {
            if hasTravelMoney(context) {
                throw NDISBillingError.travelNotEligible(NDISBillingService.providerTravelNotEligibleReason)
            }
            return []
        }
        let primaryRate = context.agreement.agreedPrice > 0
            ? context.agreement.agreedPrice
            : (try? getBaseRate(supportItem)) ?? 0
        return try calculateProviderTravel(context, primaryRate, supportItem)
    }

    func createQuotableClaim(_ context: NDISBillingInputVector) throws -> NDISClaimableLineItem {
        guard let serviceBooking = try lookupNdiaServiceBooking(context.participant.ndisNumber, context.service.supportItemNumber),
              serviceBooking.isStatedItemInPlan else {
            throw NDISBillingError.noApprovedServiceBooking
        }
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

    func createNoLimitClaim(_ context: NDISBillingInputVector) async throws -> NDISClaimableLineItem {
        guard let supportItem = try await lookupSupportItem(context.service.supportItemNumber) else {
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

    func createPrepaymentClaim(_ context: NDISBillingInputVector) throws -> NDISClaimableLineItem {
        try createLineItem(
            supportItemNumber: context.prepayment!.supportItemNumber,
            quantity: context.prepayment!.currentClaimAmount,
            unitPrice: 1.00,
            claimType: "Prepayment"
        )
    }

    func calculateSubscriptionClaim(_ context: NDISBillingInputVector) throws -> [NDISClaimableLineItem] {
        let monthlyHours = context.service.hoursPerMonth ?? context.service.quantity
        let months = max(context.service.consecutiveMonths ?? 1, 1)
        let quantity = max(monthlyHours * Double(months), 0)
        guard quantity > 0 else { return [] }
        let unitPrice = context.agreement.agreedPrice
        guard unitPrice > 0 else {
            throw NDISBillingError.invalidPrice("Subscription claim requires a positive agreed price.")
        }
        return [try createLineItem(
            supportItemNumber: context.service.supportItemNumber,
            quantity: quantity,
            unitPrice: unitPrice,
            claimType: "Subscription"
        )]
    }

    func calculateBereavementClaim(_ context: NDISBillingInputVector) throws -> NDISClaimableLineItem {
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

    func calculateCancellation(_ context: NDISBillingInputVector) throws -> [NDISClaimableLineItem] {
        guard let cancellation = context.cancellation else { return [] }
        let isShortNotice = !configService.checkNoticePeriod(
            noticeTime: cancellation.noticeTime,
            serviceTime: context.service.startTime,
            amount: 2,
            unit: "clear_business_days"
        )
        guard isShortNotice else { return [] }
        guard !context.provider.foundAlternativeWork else { return [] }
        let quantity = max(context.service.quantity, 0)
        guard quantity > 0 else { return [] }
        let unitPrice = context.agreement.agreedPrice
        guard unitPrice > 0 else {
            throw NDISBillingError.invalidPrice("Cancellation claim requires a positive agreed price.")
        }
        return [try createLineItem(
            supportItemNumber: context.service.supportItemNumber,
            quantity: quantity,
            unitPrice: unitPrice,
            claimType: "Cancellation"
        )]
    }

    // MARK: - Service Booking Lookup

    func lookupNdiaServiceBooking(_ ndisNumber: String, _ supportItemNumber: String) throws -> NDISServiceBooking? {
        guard !ndisNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !supportItemNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let predicate = #Predicate<NDISItem> { $0.itemNumber == supportItemNumber }
        let descriptor = FetchDescriptor<NDISItem>(predicate: predicate)
        guard let entity = try modelContext.fetch(descriptor).first else { return nil }
        let fallbackRegionalPrice = (entity.regionalPrices ?? [])
            .map { $0.amount }
            .filter { $0 > 0 }
            .max()
        let price = fallbackRegionalPrice ?? 0
        return NDISServiceBooking(
            isStatedItemInPlan: entity.quoteRequired == true || entity.status?.lowercased() != "deactivated",
            price: NSDecimalNumber(decimal: price).doubleValue
        )
    }
}
