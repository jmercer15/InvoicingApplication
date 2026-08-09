import Core
#if DEBUG
import Foundation

public extension TravelChargeAutomationService {
    func testCalculatedAmount(for chargeType: String, breakdown: NDISTravelChargeBreakdown) -> Double {
        calculatedAmount(for: chargeType, breakdown: breakdown)
    }

    func testGenerateTravelChargeNotes(
        session: SessionAutomationContext,
        direction: TravelDirection,
        distance: Double?,
        originalDistance: Double?,
        distanceWarnings: [ComplianceViolation],
        travelTime: Double,
        originalTravelTime: Double?,
        travelTimeWarnings: [ComplianceViolation],
        mmmZone: MMMZone,
        vehicleType: String?,
        parking: Double?,
        tolls: Double?,
        participantCount: Int,
        chargeType: String,
        splitCosts: Bool,
        pricingBreakdown: NDISTravelChargeBreakdown
    ) -> String {
        generateTravelChargeNotes(
            session: session,
            direction: direction,
            distance: distance,
            originalDistance: originalDistance,
            distanceWarnings: distanceWarnings,
            travelTime: travelTime,
            originalTravelTime: originalTravelTime,
            travelTimeWarnings: travelTimeWarnings,
            mmmZone: mmmZone,
            vehicleType: vehicleType,
            parking: parking,
            tolls: tolls,
            participantCount: participantCount,
            chargeType: chargeType,
            splitCosts: splitCosts,
            pricingBreakdown: pricingBreakdown
        )
    }

    func testOverrideNotesSuffix(overrideType: String?, overrideReason: String?) -> String {
        overrideNotesSuffix(overrideType: overrideType, overrideReason: overrideReason)
    }

    func testLookupMMMZone(for session: SessionAutomationContext) -> MMMZone? {
        lookupMMMZone(for: session)
    }
}
#endif
