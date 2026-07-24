import Foundation

/// Warns when non-labour travel (e.g. per km) may exceed NDIS guidance of $0.99/km.
public struct NonLabourTravelCapRule: Sendable {
    public static let guidancePerKm: Decimal = 0.99

    public init() {}

    public func evaluate(context: DraftValidationContext) -> [DraftIssue] {
        var issues: [DraftIssue] = []
        let km = context.billingContext.travelDistance
        guard km > 0 else { return issues }

        let isNonLabour = context.billingContext.isActivityTransport
            || (context.billingContext.isProviderTravel == false && km > 0)
        if isNonLabour {
            issues.append(DraftIssue(
                id: UUID(),
                draftId: context.draftId,
                severity: .warning,
                code: "TRAVEL_NON_LABOUR_OVER_KM_CAP",
                message: "Non-labour travel: ensure rate does not exceed $\(Self.guidancePerKm)/km (NDIS guidance).",
                resolutionKind: .userInput,
                resolutionData: nil,
                createdAt: context.referenceDate
            ))
        }
        return issues
    }
}
