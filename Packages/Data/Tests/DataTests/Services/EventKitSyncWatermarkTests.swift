@testable import Data
import Core
import Foundation
import XCTest

final class EventKitSyncWatermarkTests: XCTestCase {
    func testTimestampToleranceTwoSeconds() {
        let baseline = Date(timeIntervalSinceReferenceDate: 100_000)
        let withinTolerance = baseline.addingTimeInterval(1.5)
        let beyondTolerance = baseline.addingTimeInterval(2.1)

        XCTAssertFalse(EventKitSyncWatermark.isTimestampNewer(withinTolerance, than: baseline))
        XCTAssertTrue(EventKitSyncWatermark.isTimestampNewer(beyondTolerance, than: baseline))
    }

    func testNilRemoteModifiedWithUnchangedFingerprint() {
        let changed = EventKitSyncWatermark.didRemoteChange(
            remoteLastModified: nil,
            watermark: Date(timeIntervalSinceReferenceDate: 100),
            previousFingerprint: "fp-1",
            currentFingerprint: "fp-1"
        )

        XCTAssertFalse(changed)
    }

    func testNilRemoteModifiedWithChangedFingerprint() {
        let changed = EventKitSyncWatermark.didRemoteChange(
            remoteLastModified: nil,
            watermark: Date(timeIntervalSinceReferenceDate: 100),
            previousFingerprint: "fp-1",
            currentFingerprint: "fp-2"
        )

        XCTAssertTrue(changed)
    }

    func testRemoteFreshnessUnknownWhenModifiedIsNilAndFingerprintUnchanged() {
        let state = EventKitSyncWatermark.classifyRemoteFreshness(
            remoteLastModified: nil,
            watermark: Date(timeIntervalSinceReferenceDate: 1_000),
            previousObservedRemoteModified: Date(timeIntervalSinceReferenceDate: 1_200),
            previousFingerprint: "fp-1",
            currentFingerprint: "fp-1"
        )

        XCTAssertEqual(state, .unknown)
    }
}
