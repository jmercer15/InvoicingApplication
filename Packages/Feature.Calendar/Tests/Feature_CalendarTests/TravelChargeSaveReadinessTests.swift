import Testing
@testable import Feature_Calendar

@Suite(.tags(.integration))
struct TravelChargeSaveReadinessTests {
    @Test
    func standardTravelRequiresAtLeastOneCostType() {
        let message = readiness(
            includeLabour: false,
            includeNonLabour: false
        )

        #expect(message == "Select provider travel time, kilometre allowance, or both.")
    }

    @Test
    func selectedStandardCostsRequireMatchingServices() {
        let labourMessage = readiness(
            includeLabour: true, includeNonLabour: false,
            hasLabourService: false)
        let nonLabourMessage = readiness(
            includeLabour: false,
            includeNonLabour: true,
            hasNonLabourService: false
        )

        #expect(labourMessage?.contains("provider travel service") == true)
        #expect(nonLabourMessage?.contains("non-labour travel service") == true)
    }

    @Test
    func activityTransportRequiresMatchingService() {
        let message = readiness(
            chargeType: .activityBased, hasLabourService: false)

        #expect(message?.contains("activity transport service") == true)
    }

    @Test
    func selectedExistingDirectionIsBlocked() {
        let message = readiness(
            direction: .after, hasExistingTravelAfter: true)

        #expect(message?.contains("after-session travel charge already exists") == true)
    }

    @Test
    func completeNewTravelChargeIsReady() {
        let message = readiness()

        #expect(message == nil)
    }

    @Test
    func selectedZeroValueComponentsAreBlockedBeforeCreatingRows() {
        let labour = readiness(
            includeNonLabour: false, hasChargeableLabour: false)
        let kilometres = readiness(
            includeLabour: false,
            hasChargeableNonLabour: false
        )
        let activity = readiness(
            chargeType: .activityBased,
            hasChargeableActivityTransport: false
        )

        #expect(labour?.contains("provider travel time") == true)
        #expect(kilometres?.contains("kilometres, parking, or tolls") == true)
        #expect(activity?.contains("travel time, distance, parking, or tolls") == true)
    }

    private func readiness(
        chargeType: TravelChargeSheetChargeType = .standard, includeLabour: Bool = true,
        includeNonLabour: Bool = true,
        hasLabourService: Bool = true,
        hasNonLabourService: Bool = true,
        hasChargeableLabour: Bool = true,
        hasChargeableNonLabour: Bool = true,
        hasChargeableActivityTransport: Bool = true,
        direction: TravelChargeSheetDirection = .before,
        hasExistingTravelBefore: Bool = false,
        hasExistingTravelAfter: Bool = false
    ) -> String? {
        TravelChargeSaveReadiness.message(
            chargeType: chargeType,
            includeLabour: includeLabour,
            includeNonLabour: includeNonLabour,
            hasLabourService: hasLabourService,
            hasNonLabourService: hasNonLabourService,
            hasChargeableLabour: hasChargeableLabour,
            hasChargeableNonLabour: hasChargeableNonLabour,
            hasChargeableActivityTransport: hasChargeableActivityTransport,
            direction: direction,
            hasExistingTravelBefore: hasExistingTravelBefore,
            hasExistingTravelAfter: hasExistingTravelAfter
        )
    }
}
