import Testing
@testable import Core

@Suite struct TravelChargeEligibilityEvaluatorTests {
    @Test func PrimarySupportEligible() {
        #expect(TravelChargeEligibilityEvaluator.isPrimarySupportEligibleForTravel(ndisItemProviderTravel: true))
        #expect(!(TravelChargeEligibilityEvaluator.isPrimarySupportEligibleForTravel(ndisItemProviderTravel: false)))
        #expect(!(TravelChargeEligibilityEvaluator.isPrimarySupportEligibleForTravel(ndisItemProviderTravel: nil)))
    }

    @Test func AutomationEligibility() {
        let nonBillable: Set<String> = ["cancelled", "non-billable"]
        #expect(TravelChargeEligibilityEvaluator.isEligibleForTravelChargeAutomation(
                isTravel: false,
                hasClient: true,
                hasService: true,
                hasStartTime: true,
                statusRawValue: "Active",
                nonBillableStatuses: nonBillable,
                ndisItemProviderTravel: true
            ))
        #expect(!(TravelChargeEligibilityEvaluator.isEligibleForTravelChargeAutomation(
                isTravel: true,
                hasClient: true,
                hasService: true,
                hasStartTime: true,
                statusRawValue: "Active",
                nonBillableStatuses: nonBillable,
                ndisItemProviderTravel: true
            )))
        #expect(!(TravelChargeEligibilityEvaluator.isEligibleForTravelChargeAutomation(
                isTravel: false,
                hasClient: true,
                hasService: true,
                hasStartTime: true,
                statusRawValue: "Cancelled",
                nonBillableStatuses: nonBillable,
                ndisItemProviderTravel: true
            )))
        #expect(!(TravelChargeEligibilityEvaluator.isEligibleForTravelChargeAutomation(
                isTravel: false,
                hasClient: true,
                hasService: true,
                hasStartTime: true,
                statusRawValue: "Active",
                nonBillableStatuses: nonBillable,
                ndisItemProviderTravel: false
            )))
    }
}
