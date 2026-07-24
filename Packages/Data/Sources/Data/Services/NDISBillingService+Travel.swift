import Foundation
import Core

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

        // 1. Labour Component (Time)
        if let travel = context.travel, (travel.timeTo > 0 || travel.timeFrom > 0) {
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

        // 2. Non-Labour Component (Kilometres)
        if let travel = context.travel, travel.kilometres > 0 {
            let kmRate = context.agreement.agreedTravelRatePerKM ?? configService.getTravelRatePerKm()
            claims.append(try createLineItem(
                supportItemNumber: supportItem.itemNumber,
                quantity: travel.kilometres,
                unitPrice: kmRate,
                claimType: "ProviderTravel_NonLabour"
            ))
        }

        // 3. Tolls & Parking
        if let travel = context.travel, (travel.tolls > 0 || travel.parking > 0) {
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
        guard transport.kilometres > 0 || transport.tolls > 0 || transport.parking > 0 else { return nil }

        let baseRate        = configService.getTransportRate(isModified: transport.isModifiedVehicle)
        let distanceCost    = transport.kilometres * baseRate
        let ancillaryCost   = transport.tolls + transport.parking
        let splitCount      = max(context.context.transportGroupSize, 1)
        let totalPerParticipant = (distanceCost + ancillaryCost) / Double(splitCount)
        guard totalPerParticipant > 0 else { return nil }

        return try createLineItem(
            supportItemNumber: context.service.supportItemNumber,
            quantity: 1,
            unitPrice: totalPerParticipant,
            claimType: "ActivityTransport"
        )
    }
}
