import Foundation
import Core
import PersistenceModels
@testable import Feature_Calendar
import Testing
import CoreTesting

@Suite(.tags(.integration))
struct CalendarSessionCompletionFeedbackTests {
    @Test func nudgesOnlyOnTrueTransitionIntoCompleted() {
        #expect(CalendarSessionCompletionFeedback.shouldNudgeForBillingHub(
            newStatus: .completed, priorStatus: .scheduled))
        #expect(CalendarSessionCompletionFeedback.shouldNudgeForBillingHub(
            newStatus: .completed, priorStatus: .cancelled))
        #expect(CalendarSessionCompletionFeedback.shouldNudgeForBillingHub(
            newStatus: .completed, priorStatus: nil))

        #expect(!(CalendarSessionCompletionFeedback.shouldNudgeForBillingHub(
            newStatus: .completed, priorStatus: .completed)))
        #expect(!(CalendarSessionCompletionFeedback.shouldNudgeForBillingHub(
            newStatus: .scheduled, priorStatus: .scheduled)))
        #expect(!(CalendarSessionCompletionFeedback.shouldNudgeForBillingHub(
            newStatus: .cancelled, priorStatus: .scheduled)))
        #expect(!(CalendarSessionCompletionFeedback.shouldNudgeForBillingHub(
            newStatus: .noShow, priorStatus: .scheduled)))
        #expect(!(CalendarSessionCompletionFeedback.shouldNudgeForBillingHub(
            newStatus: .rescheduled, priorStatus: .scheduled)))
    }

    @Test func nudgeMessageCopy() {
        #expect(CalendarSessionCompletionFeedback.billingHubNudgeMessage == "Session ready for Billing Hub.")
        #expect(CalendarSessionCompletionFeedback.billingHubNudgeMessage(completedCount: 1) == "Session ready for Billing Hub.")
        #expect(CalendarSessionCompletionFeedback.billingHubNudgeMessage(completedCount: 3) == "3 sessions ready for Billing Hub.")
        #expect(CalendarSessionCompletionFeedback.nextStepSubtitle(completedCount: 1) == "Next: prepare this session for invoicing.")
        #expect(CalendarSessionCompletionFeedback.nextStepSubtitle(completedCount: 3) == "Next: prepare these sessions for invoicing.")
    }

    @Test func focusSessionIDsPreferPersistedCreateResult() {
        let created = UUID()
        let editing = UUID()

        #expect(CalendarSessionCompletionFeedback.focusSessionIDs(persistedID: created, editingID: nil) == [created])
        #expect(CalendarSessionCompletionFeedback.focusSessionIDs(persistedID: created, editingID: editing) == [created])
        #expect(CalendarSessionCompletionFeedback.focusSessionIDs(persistedID: nil, editingID: editing) == [editing])
        #expect(CalendarSessionCompletionFeedback.focusSessionIDs(persistedID: nil, editingID: nil) == [])
    }

    @Test func pendingFocusIDsAccumulateWithoutDuplicates() {
        let first = UUID()
        let second = UUID()

        #expect(CalendarSessionCompletionFeedback.mergedFocusSessionIDs(
            existing: [first], new: [first, second]
        ) == [first, second])
    }

    @Test func persistentHandoffCopyNamesPendingCount() {
        #expect(CalendarSessionCompletionFeedback.pendingHandoffLabel(count: 1) == "Billing Hub · 1 Ready")
        #expect(CalendarSessionCompletionFeedback.pendingHandoffLabel(count: 3) == "Billing Hub · 3 Ready")
        #expect(CalendarSessionCompletionFeedback.pendingHandoffHelp(count: 1) == "Open Billing Hub and focus completed session.")
        #expect(CalendarSessionCompletionFeedback.pendingHandoffHelp(count: 3) == "Open Billing Hub and focus 3 completed sessions.")
    }
}
