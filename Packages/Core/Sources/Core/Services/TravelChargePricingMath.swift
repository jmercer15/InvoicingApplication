import Foundation

/// Pure NDIS travel pricing helpers used by `TravelChargeAutomationService`.
public enum TravelChargePricingMath {
    /// Maps NDIS charge type strings to the appropriate per-participant total from a breakdown.
    public static func calculatedAmount(for chargeType: String, breakdown: NDISTravelChargeBreakdown) -> Double {
        switch chargeType.lowercased() {
        case "labour":
            breakdown.labourPerParticipant
        case "non-labour":
            breakdown.nonLabourPerParticipant
        case "activity-based":
            breakdown.totalPerParticipant
        default:
            breakdown.totalPerParticipant
        }
    }
}
