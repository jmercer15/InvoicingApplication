@testable import Data
import Core
import Testing
import PersistenceModels
@Suite struct EventKitExternalPromptReconciliationTests {
    @Test func PromptPolicyReturnsPromptWhenBothSidesChanged() {
        let decision = EventKitSyncPolicy.reconcileDecision(
            syncDirection: .bidirectional,
            conflictResolutionPolicy: .prompt,
            localChanged: true,
            remoteFreshness: .changed
        )

        #expect(decision == .prompt)
    }

    @Test func PromptPolicyReturnsPromptWhenRemoteFreshnessUnknown() {
        let decision = EventKitSyncPolicy.reconcileDecision(
            syncDirection: .bidirectional,
            conflictResolutionPolicy: .prompt,
            localChanged: false,
            remoteFreshness: .unknown
        )

        #expect(decision == .prompt)
    }

    @Test func PromptPolicyPullsWhenOnlyRemoteChanged() {
        let decision = EventKitSyncPolicy.reconcileDecision(
            syncDirection: .bidirectional,
            conflictResolutionPolicy: .prompt,
            localChanged: false,
            remoteFreshness: .changed
        )

        #expect(decision == .pull)
    }

    @Test func UnknownFreshnessRespectsPreferCalendar() {
        let decision = EventKitSyncPolicy.reconcileDecision(
            syncDirection: .bidirectional,
            conflictResolutionPolicy: .preferCalendar,
            localChanged: false,
            remoteFreshness: .unknown
        )

        #expect(decision == .pull)
    }
}
