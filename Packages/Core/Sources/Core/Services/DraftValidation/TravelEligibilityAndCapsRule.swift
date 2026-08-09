import CoreLocation
import Foundation
import MapKit

/// Validates travel eligibility and labour travel caps using MMM zones (30/60/∞ minutes).
public struct TravelEligibilityAndCapsRule: Sendable {
    private let mmmLookup: MMMZoneLookup

    public init(mmmLookup: MMMZoneLookup) {
        self.mmmLookup = mmmLookup
    }

    /// Returns max labour travel minutes for MMM code 1–7 (30, 60, or ∞).
    public static func maxTravelMinutes(mmmCode: Int) -> Double {
        switch mmmCode {
        case 1...3: return 30
        case 4...5: return 60
        case 6...7: return .infinity
        default: return 30
        }
    }

    public func evaluate(context: DraftValidationContext) -> [DraftIssueSnapshot] {
        var issues: [DraftIssueSnapshot] = []
        let hasTravel = context.billingContext.isProviderTravel
            || context.billingContext.travelTime > 0
            || context.billingContext.travelDistance > 0

        if hasTravel {
            let coord = context.sessionCoordinate ?? context.clientCoordinate
            if coord == nil {
                issues.append(DraftIssueSnapshot(
                    id: UUID(),
                    draftId: context.draftId,
                    severity: .blocking,
                    code: "TRAVEL_MISSING_LOCATION",
                    message: "Travel is present but no resolved coordinates are available for MMM lookup.",
                    resolutionKind: .userInput,
                    resolutionData: nil,
                    createdAt: context.referenceDate
                ))
                return issues
            }

            if let code = coord.flatMap({ mmmLookup.mmm(for: $0) }) {
                let maxMinutes = Self.maxTravelMinutes(mmmCode: code)
                if maxMinutes != .infinity, context.billingContext.travelTime > maxMinutes {
                    issues.append(DraftIssueSnapshot(
                        id: UUID(),
                        draftId: context.draftId,
                        severity: .warning,
                        code: "TRAVEL_TIME_OVER_CAP",
                        message: "Labour travel time (\(Int(context.billingContext.travelTime)) min) exceeds MMM zone cap (\(Int(maxMinutes)) min). Cap will be applied on export.",
                        resolutionKind: .autoFix,
                        resolutionData: nil,
                        createdAt: context.referenceDate
                    ))
                }
            }
        }
        return issues
    }
}
