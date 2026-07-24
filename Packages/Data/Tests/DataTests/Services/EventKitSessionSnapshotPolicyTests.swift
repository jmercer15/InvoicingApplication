@testable import Data
import Core
import XCTest

final class EventKitSessionSnapshotPolicyTests: XCTestCase {
    func testTwoPassStalePolicy() {
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

    func testReattachResetsConsecutiveMisses() {
        let reset = EventKitSyncPolicy.staleMissOutcome(
            currentMisses: 2,
            hasWindowMatch: false,
            hasResolvedMatch: true
        )

        XCTAssertEqual(reset.nextMisses, 0)
        XCTAssertFalse(reset.shouldMarkStale)
    }

    func testNilRemoteModifiedWithStableFingerprintIsUnknownNotChanged() {
        let state = EventKitSyncWatermark.classifyRemoteFreshness(
            remoteLastModified: nil,
            watermark: Date(timeIntervalSinceReferenceDate: 5_000),
            previousObservedRemoteModified: Date(timeIntervalSinceReferenceDate: 5_100),
            previousFingerprint: "stable",
            currentFingerprint: "stable"
        )

        XCTAssertEqual(state, .unknown)
    }
}
