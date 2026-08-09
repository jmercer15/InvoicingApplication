import Core
import Foundation

/// Copy + trigger rule for the non-blocking "ready for Billing Hub" nudge shown after a session is
/// marked Completed. Kept as a pure, testable unit separate from `CalendarViewModel` so the
/// message text and trigger condition can be asserted without constructing the full view model.
enum CalendarSessionCompletionFeedback {
    static let billingHubNudgeMessage = "Session ready for Billing Hub."

    /// Plural-aware copy for bulk Mark as Completed.
    static func billingHubNudgeMessage(completedCount: Int) -> String {
        if completedCount <= 1 {
            return billingHubNudgeMessage
        }
        return "\(completedCount) sessions ready for Billing Hub."
    }

    static func nextStepSubtitle(completedCount: Int) -> String {
        completedCount <= 1
            ? "Next: prepare this session for invoicing."
            : "Next: prepare these sessions for invoicing."
    }

    /// Only a genuine transition into Completed should nudge — not cancellations, reschedules,
    /// or re-applying Completed when the session was already completed.
    static func shouldNudgeForBillingHub(
        newStatus: Core.SessionStatus,
        priorStatus: Core.SessionStatus?
    ) -> Bool {
        newStatus == .completed && priorStatus != .completed
    }

    /// Prefer the create/modify result id (create-as-Completed and detached occurrences) over
    /// `sessionToEdit`, which is nil on create.
    static func focusSessionIDs(persistedID: UUID?, editingID: UUID?) -> [UUID] {
        if let persistedID { return [persistedID] }
        if let editingID { return [editingID] }
        return []
    }

    static func mergedFocusSessionIDs(
        existing: [UUID],
        new: [UUID]
    ) -> [UUID] {
        (existing + new).reduce(into: [UUID]()) { result, id in
            if !result.contains(id) {
                result.append(id)
            }
        }
    }

    static func pendingHandoffLabel(count: Int) -> String {
        "Billing Hub · \(count) Ready"
    }

    static func pendingHandoffHelp(count: Int) -> String {
        let sessions = count == 1 ? "completed session" : "\(count) completed sessions"
        return "Open Billing Hub and focus \(sessions)."
    }
}
