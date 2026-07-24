@testable import Data
import Core
import XCTest

final class EventKitSyncReattachTests: XCTestCase {
    func testMovedOutOfWindowReattach() {
        XCTAssertTrue(
            EventKitSyncPolicy.didReattach(
                hasWindowMatch: false,
                hasResolvedMatch: true
            )
        )
        let outcome = EventKitSyncPolicy.staleMissOutcome(
            currentMisses: 1,
            hasWindowMatch: false,
            hasResolvedMatch: true
        )
        XCTAssertEqual(outcome.nextMisses, 0)
        XCTAssertFalse(outcome.shouldMarkStale)
    }

    func testUnresolvedRequiresTwoMissesBeforeStale() {
        let firstMiss = EventKitSyncPolicy.staleMissOutcome(
            currentMisses: 0,
            hasWindowMatch: false,
            hasResolvedMatch: false
        )
        XCTAssertEqual(firstMiss.nextMisses, 1)
        XCTAssertFalse(firstMiss.shouldMarkStale)

        let secondMiss = EventKitSyncPolicy.staleMissOutcome(
            currentMisses: firstMiss.nextMisses,
            hasWindowMatch: false,
            hasResolvedMatch: false
        )
        XCTAssertEqual(secondMiss.nextMisses, 2)
        XCTAssertTrue(secondMiss.shouldMarkStale)
    }
}
