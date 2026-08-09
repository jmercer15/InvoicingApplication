import Core
import Foundation

extension TravelChargeAutomationService {
    /// Checks if a session is eligible for travel charge automation
    func isEligibleForTravelCharge(_ session: SessionAutomationContext) -> Bool {
        TravelChargeEligibilityEvaluator.isEligibleForTravelChargeAutomation(
            isTravel: session.isTravel,
            hasClient: session.client != nil,
            hasService: session.service != nil,
            hasStartTime: session.startTime != nil,
            statusRawValue: session.status.rawValue,
            nonBillableStatuses: businessRules.nonBillableStatuses,
            ndisItemProviderTravel: session.ndisItem?.providerTravel
        )
    }

    /// Checks if the primary support is eligible for travel claims according to NDIS rules.
    func isPrimarySupportEligibleForTravel(_ session: SessionAutomationContext) -> Bool {
        TravelChargeEligibilityEvaluator.isPrimarySupportEligibleForTravel(
            ndisItemProviderTravel: session.ndisItem?.providerTravel
        )
    }
}

