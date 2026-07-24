import XCTest
@testable import Core

final class TravelChargeEligibilityEvaluatorTests: XCTestCase {
    func testPrimarySupportEligible() {
        XCTAssertTrue(TravelChargeEligibilityEvaluator.isPrimarySupportEligibleForTravel(ndisItemProviderTravel: true))
        XCTAssertFalse(TravelChargeEligibilityEvaluator.isPrimarySupportEligibleForTravel(ndisItemProviderTravel: false))
        XCTAssertFalse(TravelChargeEligibilityEvaluator.isPrimarySupportEligibleForTravel(ndisItemProviderTravel: nil))
    }

    func testAutomationEligibility() {
        let nonBillable: Set<String> = ["cancelled", "non-billable"]
        XCTAssertTrue(
            TravelChargeEligibilityEvaluator.isEligibleForTravelChargeAutomation(
                isTravel: false,
                hasClient: true,
                hasService: true,
                hasStartTime: true,
                statusRawValue: "Active",
                nonBillableStatuses: nonBillable,
                ndisItemProviderTravel: true
            )
        )
        XCTAssertFalse(
            TravelChargeEligibilityEvaluator.isEligibleForTravelChargeAutomation(
                isTravel: true,
                hasClient: true,
                hasService: true,
                hasStartTime: true,
                statusRawValue: "Active",
                nonBillableStatuses: nonBillable,
                ndisItemProviderTravel: true
            )
        )
        XCTAssertFalse(
            TravelChargeEligibilityEvaluator.isEligibleForTravelChargeAutomation(
                isTravel: false,
                hasClient: true,
                hasService: true,
                hasStartTime: true,
                statusRawValue: "Cancelled",
                nonBillableStatuses: nonBillable,
                ndisItemProviderTravel: true
            )
        )
        XCTAssertFalse(
            TravelChargeEligibilityEvaluator.isEligibleForTravelChargeAutomation(
                isTravel: false,
                hasClient: true,
                hasService: true,
                hasStartTime: true,
                statusRawValue: "Active",
                nonBillableStatuses: nonBillable,
                ndisItemProviderTravel: false
            )
        )
    }
}
