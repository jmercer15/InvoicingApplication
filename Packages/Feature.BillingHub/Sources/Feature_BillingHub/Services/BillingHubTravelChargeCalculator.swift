import Core
import Foundation

/// Shared Hub travel math — same `NDISTravelChargeCalculator` + `TravelChargePricingMath` path
/// used for preview and persist.
enum BillingHubTravelChargeCalculator {
    static func effectiveParticipantCount(participantCount: Int, splitCosts: Bool) -> Int {
        splitCosts ? max(participantCount, 1) : 1
    }

    static func isModifiedVehicle(_ vehicleType: String) -> Bool {
        if let typed = VehicleType(rawValue: vehicleType) {
            return typed == .modifiedBus
        }
        return vehicleType.localizedCaseInsensitiveContains("modified")
    }

    static func vehicleRatePerKilometre(for vehicleType: String) -> Double {
        NDISTravelChargeCalculator.vehicleRatePerKilometre(
            isModified: isModifiedVehicle(vehicleType)
        )
    }

    static func breakdown(
        providerType: TravelChargeProviderType,
        hourlyRate: Double,
        mmmZoneDescriptor: String?,
        distance: Double,
        time: Double,
        tolls: Double,
        parking: Double,
        participantCount: Int,
        splitCosts: Bool,
        chargeType: String = "standard",
        vehicleType: String = VehicleType.standardCar.rawValue
    ) -> TravelCalculationBreakdown {
        let ndis = NDISTravelChargeCalculator.calculate(
            providerType: providerType,
            hourlyRate: hourlyRate,
            mmmZoneDescriptor: mmmZoneDescriptor,
            minutesTravelled: time,
            kilometresTravelled: distance,
            ancillaryCosts: tolls + parking,
            participantCount: effectiveParticipantCount(participantCount: participantCount, splitCosts: splitCosts),
            vehicleRatePerKilometre: vehicleRatePerKilometre(for: vehicleType)
        )
        let chargeAmount = TravelChargePricingMath.calculatedAmount(for: chargeType, breakdown: ndis)
        return TravelCalculationBreakdown(
            labourTotal: ndis.labourTotal,
            nonLabourTotal: ndis.nonLabourTotal,
            grossTotal: ndis.grossTotal,
            billableMinutes: ndis.billableMinutes,
            requestedMinutes: ndis.requestedMinutes,
            totalPerParticipant: ndis.totalPerParticipant,
            labourPerParticipant: ndis.labourPerParticipant,
            nonLabourPerParticipant: ndis.nonLabourPerParticipant,
            chargeAmount: chargeAmount
        )
    }

    static func inferredProviderType(
        itemName: String?,
        itemDescription: String?,
        ndisCode: String?
    ) -> TravelChargeProviderType {
        NDISTravelChargeCalculator.inferredProviderType(
            itemName: itemName,
            itemDescription: itemDescription,
            ndisCode: ndisCode
        )
    }
}
