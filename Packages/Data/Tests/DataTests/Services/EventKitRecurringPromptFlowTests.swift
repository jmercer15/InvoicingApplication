@testable import Data
import Core
import Foundation
import XCTest

final class EventKitRecurringPromptFlowTests: XCTestCase {
    func testRecurringConflictDatesAreProcessedInDeterministicOrder() {
        let third = Date(timeIntervalSinceReferenceDate: 30)
        let first = Date(timeIntervalSinceReferenceDate: 10)
        let second = Date(timeIntervalSinceReferenceDate: 20)

        let ordered = EventKitSyncPolicy.orderedOccurrenceDates([third, first, second, first])

        XCTAssertEqual(ordered, [first, first, second, third])
    }

    func testPromptPolicyKeepsRecurringConflictUserMediated() {
        let decision = EventKitSyncPolicy.reconcileDecision(
            syncDirection: .bidirectional,
            conflictResolutionPolicy: .prompt,
            localChanged: true,
            remoteFreshness: .unknown
        )

        XCTAssertEqual(decision, .prompt)
    }
}
