import Foundation
import os

extension TravelChargeAutomationService {
    /// Adds a session to the user review queue for manual intervention.
    func queueForUserReview(session: SessionAutomationContext, reason: String) async {
        await queueForUserReview(session: session, reason: reason, violations: [], suggestedActions: [], overrideOptions: [])
    }

    /// Adds a session to the user review queue with detailed violation information.
    func queueForUserReview(
        session: SessionAutomationContext,
        reason: String,
        violations: [ComplianceViolation] = [],
        suggestedActions: [String] = [],
        overrideOptions: [String] = []
    ) async {
        if testingMode {
            let summary = "Session: \(session.title), Reason: \(reason)"
            appendTestReviewSummary(summary)

            let detailedItem = DetailedReviewItem(
                id: UUID(),
                sessionID: session.id, // Using session.id (UUID) as PersistentIdentifier stand-in for testing
                sessionTitle: session.title,
                clientName: session.client?.fullName,
                reason: reason,
                violations: violations,
                suggestedActions: suggestedActions,
                overrideOptions: overrideOptions,
                timestamp: Date()
            )
            appendTestDetailedReviewItem(detailedItem)

            Logger.automation.info("Flagged for review: \(session.title) - Reason: \(reason)")
            if !violations.isEmpty {
                Logger.automation.info("Violations: \(violations.map(\.rule).joined(separator: ", "))")
            }
            return
        }

        let reviewItem = TravelChargeReviewSnapshot(
            id: UUID(),
            reason: reason,
            timestamp: Date(),
            status: "pending",
            sessionID: session.id,
            sessionTitle: session.title,
            clientName: session.client?.fullName,
            violationDetails: violations.isEmpty ? nil : violations.map { "\($0.rule): \($0.currentValue) (limit: \($0.limit)) - \($0.description)" },
            suggestedActions: suggestedActions.isEmpty ? nil : suggestedActions,
            overrideOptions: overrideOptions.isEmpty ? nil : overrideOptions,
            sessionId: session.id
        )

        try? persistence.persistTravelChargeReview(reviewItem)
        await logReviewItem(reviewItem)
        Logger.automation.info("Flagged for review: \(session.title) - Reason: \(reason)")
        if !violations.isEmpty {
            Logger.automation.info("Violations: \(violations.map(\.rule).joined(separator: ", "))")
        }
    }
}

