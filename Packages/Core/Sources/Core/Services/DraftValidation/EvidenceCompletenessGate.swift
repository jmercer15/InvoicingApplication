import Foundation

/// For NDIA-managed plans, draft should have service agreement and support log evidence before marking ready.
public struct EvidenceCompletenessGate: Sendable {
    public init() {}

    public func evaluate(context: DraftValidationContext) -> [DraftIssueSnapshot] {
        var issues: [DraftIssueSnapshot] = []
        let isNdiaManaged = (context.client.planManagementType?.lowercased().contains("ndia") ?? false)
            || (context.client.billingAuthority?.rawValue.lowercased() == "ndia")
        guard isNdiaManaged else { return issues }

        issues.append(DraftIssueSnapshot(
            id: UUID(),
            draftId: context.draftId,
            severity: .info,
            code: "EVIDENCE_COMPLETENESS",
            message: "NDIA-managed: ensure service agreement and support log (and signature if applicable) are complete before marking ready.",
            resolutionKind: .userInput,
            resolutionData: nil,
            createdAt: context.referenceDate
        ))
        return issues
    }
}
