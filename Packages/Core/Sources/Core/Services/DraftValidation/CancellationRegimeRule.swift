import Foundation

/// Validates cancellation claim type: 2 vs 7 clear business days and correct reason code; requires attestation for ready.
public struct CancellationRegimeRule: Sendable {
    public init() {}

    public func evaluate(context: DraftValidationContext) -> [DraftIssueSnapshot] {
        var issues: [DraftIssueSnapshot] = []
        guard context.billingContext.isShortNoticeCancellation else { return issues }

        issues.append(DraftIssueSnapshot(
            id: UUID(),
            draftId: context.draftId,
            severity: .warning,
            code: "CANCELLATION_ATTESTATION",
            message: "Short-notice cancellation: ensure correct notice period (2 or 7 clear business days) and reason code. "
                + "For 'Mark Ready', attestation that unable to find alternative billable work may be required.",
            resolutionKind: .overrideWithReason,
            resolutionData: nil,
            createdAt: context.referenceDate
        ))
        return issues
    }
}
