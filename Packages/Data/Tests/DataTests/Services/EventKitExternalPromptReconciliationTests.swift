@testable import Data
import Core
import XCTest

final class EventKitExternalPromptReconciliationTests: XCTestCase {
    func testPromptPolicyReturnsPromptWhenBothSidesChanged() {
        let decision = EventKitSyncPolicy.reconcileDecision(
            syncDirection: .bidirectional,
            conflictResolutionPolicy: .prompt,
            localChanged: true,
            remoteFreshness: .changed
        )

        XCTAssertEqual(decision, .prompt)
    }

    func testPromptPolicyReturnsPromptWhenRemoteFreshnessUnknown() {
        let decision = EventKitSyncPolicy.reconcileDecision(
            syncDirection: .bidirectional,
            conflictResolutionPolicy: .prompt,
            localChanged: false,
            remoteFreshness: .unknown
        )

        XCTAssertEqual(decision, .prompt)
    }

    func testPromptPolicyPullsWhenOnlyRemoteChanged() {
        let decision = EventKitSyncPolicy.reconcileDecision(
            syncDirection: .bidirectional,
            conflictResolutionPolicy: .prompt,
            localChanged: false,
            remoteFreshness: .changed
        )

        XCTAssertEqual(decision, .pull)
    }

    func testUnknownFreshnessRespectsPreferCalendar() {
        let decision = EventKitSyncPolicy.reconcileDecision(
            syncDirection: .bidirectional,
            conflictResolutionPolicy: .preferCalendar,
            localChanged: false,
            remoteFreshness: .unknown
        )

        XCTAssertEqual(decision, .pull)
    }
}
