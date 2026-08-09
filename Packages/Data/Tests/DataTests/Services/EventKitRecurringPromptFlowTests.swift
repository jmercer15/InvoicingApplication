@testable import Data
import Core
import Foundation
import Testing
import PersistenceModels
@Suite struct EventKitRecurringPromptFlowTests {
    @Test func RecurringConflictDatesAreProcessedInDeterministicOrder() {
        let third = Date(timeIntervalSinceReferenceDate: 30)
        let first = Date(timeIntervalSinceReferenceDate: 10)
        let second = Date(timeIntervalSinceReferenceDate: 20)

        let ordered = EventKitSyncPolicy.orderedOccurrenceDates([third, first, second, first])

        #expect(ordered == [first, first, second, third])
    }

    @Test func PromptPolicyKeepsRecurringConflictUserMediated() {
        let decision = EventKitSyncPolicy.reconcileDecision(
            syncDirection: .bidirectional,
            conflictResolutionPolicy: .prompt,
            localChanged: true,
            remoteFreshness: .unknown
        )

        #expect(decision == .prompt)
    }
}
