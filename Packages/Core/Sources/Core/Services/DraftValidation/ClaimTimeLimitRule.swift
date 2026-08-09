import Foundation

/// NDIS claim time limit: support start must be within 2 years of claim.
/// After 2 Oct 2025 grace cutoff, claims older than 2 years are rejected; near boundary emits warning.
public struct ClaimTimeLimitRule: Sendable {
    /// End of grace period; after this date the 2-year rule is strictly enforced.
    public static let graceCutoffDate: Date = {
        var components = DateComponents()
        components.year = 2025
        components.month = 10
        components.day = 2
        components.hour = 23
        components.minute = 59
        components.second = 59
        return Calendar.current.date(from: components) ?? Date.distantFuture
    }()

    private let referenceDate: Date

    public init(referenceDate: Date = Date()) {
        self.referenceDate = referenceDate
    }

    /// Evaluates the support start date and returns a blocking or warning issue if applicable.
    public func evaluate(supportStartDate: Date, draftId: UUID) -> DraftIssueSnapshot? {
        let twoYearsAgo = Calendar.current.date(byAdding: .year, value: -2, to: referenceDate) ?? referenceDate
        if supportStartDate < twoYearsAgo {
            let afterCutoff = referenceDate > Self.graceCutoffDate
            return DraftIssueSnapshot(
                id: UUID(),
                draftId: draftId,
                severity: afterCutoff ? .blocking : .warning,
                code: afterCutoff ? "CLAIM_TIME_LIMIT_EXCEEDED" : "CLAIM_TIME_LIMIT_NEAR_BOUNDARY",
                message: afterCutoff
                    ? "Support start date is more than 2 years ago; claim will be rejected by NDIA."
                    : "Support start date is more than 2 years ago; claim may be rejected after grace period.",
                resolutionKind: .userInput,
                resolutionData: nil,
                createdAt: referenceDate
            )
        }
        let nearBoundaryDays: Int = 60
        guard let boundaryStart = Calendar.current.date(byAdding: .day, value: -nearBoundaryDays, to: twoYearsAgo) else {
            return nil
        }
        if supportStartDate < boundaryStart {
            return nil
        }
        return DraftIssueSnapshot(
            id: UUID(),
            draftId: draftId,
            severity: .warning,
            code: "CLAIM_TIME_LIMIT_NEAR_BOUNDARY",
            message: "Support start date is within 60 days of the 2-year claim limit.",
            resolutionKind: .userInput,
            resolutionData: nil,
            createdAt: referenceDate
        )
    }
}
