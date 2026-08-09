import Foundation
import Core
import PersistenceModels

extension NDISBillingService {

    // MARK: - Provider Travel

    func isEligibleForProviderTravel(_ supportItem: NDISItemSnapshot) -> Bool {
        supportItem.providerTravel == true
    }

    func calculateProviderTravel(
        _ context: NDISBillingInputVector,
        _ primarySupportRateLimit: Double,
        _ supportItem: NDISItemSnapshot
    ) throws -> [NDISClaimableLineItem] {
        var claims: [NDISClaimableLineItem] = []
        guard let travel = context.travel else { return claims }

        // 1. Labour Component (Time) — prefer stored chargeAmount; else minutes × hourly rate.
        if let preferredLabour = travel.preferredLabourChargeAmount, preferredLabour > 0 {
            claims.append(try createLineItem(
                supportItemNumber: supportItem.itemNumber,
                quantity: 1,
                unitPrice: preferredLabour,
                claimType: "ProviderTravel_Labour"
            ))
        } else if travel.timeTo > 0 || travel.timeFrom > 0 {
            let totalTimeMin  = travel.timeTo + travel.timeFrom
            let quantityHours = totalTimeMin / 60.0
            let hourlyRate    = context.agreement.agreedPrice > 0 ? context.agreement.agreedPrice : primarySupportRateLimit
            claims.append(try createLineItem(
                supportItemNumber: supportItem.itemNumber,
                quantity: quantityHours,
                unitPrice: hourlyRate,
                claimType: "ProviderTravel_Labour"
            ))
        }

        // 2. Non-Labour Component (Kilometres) — prefer stored chargeAmount; else km × calculator rate.
        if let preferredNonLabour = travel.preferredNonLabourChargeAmount, preferredNonLabour > 0 {
            claims.append(try createLineItem(
                supportItemNumber: supportItem.itemNumber,
                quantity: 1,
                unitPrice: preferredNonLabour,
                claimType: "ProviderTravel_NonLabour"
            ))
        } else if travel.kilometres > 0 {
            let kmRate = context.agreement.agreedTravelRatePerKM
                ?? NDISTravelChargeCalculator.vehicleRatePerKilometre
            claims.append(try createLineItem(
                supportItemNumber: supportItem.itemNumber,
                quantity: travel.kilometres,
                unitPrice: kmRate,
                claimType: "ProviderTravel_NonLabour"
            ))
        }

        // 3. Tolls & Parking — skip when non-labour chargeAmount already includes ancillary.
        if travel.preferredNonLabourChargeAmount == nil,
           travel.tolls > 0 || travel.parking > 0 {
            let totalCost = travel.tolls + travel.parking
            claims.append(try createLineItem(
                supportItemNumber: supportItem.itemNumber,
                quantity: totalCost,
                unitPrice: 1.0,
                claimType: "ProviderTravel_OtherCosts"
            ))
        }

        return claims
    }

    // MARK: - Activity Transport

    func isEligibleForActivityTransport(_ supportItem: NDISItemSnapshot) -> Bool {
        let keywords = ["transport", "community access", "activity based"]
        let haystack = "\(supportItem.name) \(supportItem.itemDescription ?? "") \(supportItem.category ?? "")".lowercased()
        return keywords.contains(where: haystack.contains)
    }

    func calculateActivityTransport(_ context: NDISBillingInputVector) throws -> NDISClaimableLineItem? {
        guard let transport = context.transport else { return nil }

        let splitCount = max(context.context.transportGroupSize, 1)
        let totalPerParticipant: Double
        if let preferred = transport.preferredChargeAmount, preferred > 0 {
            // Prefer stored TravelCharge.chargeAmount; already participant-scoped when persisted.
            totalPerParticipant = preferred
        } else {
            guard transport.kilometres > 0 || transport.tolls > 0 || transport.parking > 0 else { return nil }
            let baseRate = NDISTravelChargeCalculator.vehicleRatePerKilometre(
                isModified: transport.isModifiedVehicle
            )
            let distanceCost = transport.kilometres * baseRate
            let ancillaryCost = transport.tolls + transport.parking
            totalPerParticipant = (distanceCost + ancillaryCost) / Double(splitCount)
        }
        guard totalPerParticipant > 0 else { return nil }

        return try createLineItem(
            supportItemNumber: context.service.supportItemNumber,
            quantity: 1,
            unitPrice: totalPerParticipant,
            claimType: "ActivityTransport"
        )
    }

    /// True when travel flags / inputs / stored amounts imply billable travel money.
    func hasTravelMoney(_ context: NDISBillingInputVector) -> Bool {
        if let preferred = context.transport?.preferredChargeAmount, preferred > 0 { return true }
        if let labour = context.travel?.preferredLabourChargeAmount, labour > 0 { return true }
        if let nonLabour = context.travel?.preferredNonLabourChargeAmount, nonLabour > 0 { return true }
        if let travel = context.travel,
           travel.timeTo > 0 || travel.timeFrom > 0 || travel.kilometres > 0
            || travel.tolls > 0 || travel.parking > 0 {
            return true
        }
        if let transport = context.transport,
           transport.kilometres > 0 || transport.tolls > 0 || transport.parking > 0 {
            return true
        }
        return context.context.isProviderTravel || context.context.isActivityTransport
    }
}
