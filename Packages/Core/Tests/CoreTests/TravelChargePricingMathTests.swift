import Testing
import Core

@Suite struct TravelChargePricingMathTests {
    @Test func CalculatedAmountMappingByChargeType() {
        let breakdown = NDISTravelChargeBreakdown(
            providerType: .dsw,
            requestedMinutes: 30,
            billableMinutes: 30,
            maxBillableMinutes: 30,
            hourlyRate: 60,
            labourTotal: 22,
            nonLabourTotal: 9.5,
            grossTotal: 31.5,
            labourPerParticipant: 22,
            nonLabourPerParticipant: 9.5,
            totalPerParticipant: 31.5,
            participantCount: 1
        )

        #expect(TravelChargePricingMath.calculatedAmount(for: "labour", breakdown: breakdown) == 22)
        #expect(TravelChargePricingMath.calculatedAmount(for: "non-labour", breakdown: breakdown) == 9.5)
        #expect(TravelChargePricingMath.calculatedAmount(for: "activity-based", breakdown: breakdown) == 31.5)
        #expect(TravelChargePricingMath.calculatedAmount(for: "unexpected", breakdown: breakdown) == 31.5)
    }
}
