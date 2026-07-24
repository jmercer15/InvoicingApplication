import Foundation

/// Pure eligibility checks for travel charge automation (value inputs only).
public enum TravelChargeEligibilityEvaluator: Sendable {
    public static func isPrimarySupportEligibleForTravel(ndisItemProviderTravel: Bool?) -> Bool {
        ndisItemProviderTravel == true
    }

    public static func isEligibleForTravelChargeAutomation(
        isTravel: Bool,
        hasClient: Bool,
        hasService: Bool,
        hasStartTime: Bool,
        statusRawValue: String,
        nonBillableStatuses: Set<String>,
        ndisItemProviderTravel: Bool?
    ) -> Bool {
        if isTravel { return false }
        if !hasClient || !hasService { return false }
        if !hasStartTime { return false }
        let status = statusRawValue.lowercased()
        if nonBillableStatuses.contains(status) {
            return false
        }
        return isPrimarySupportEligibleForTravel(ndisItemProviderTravel: ndisItemProviderTravel)
    }
}
