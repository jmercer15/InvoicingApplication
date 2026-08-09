@testable import Data
import Core
import Foundation
import Testing
import PersistenceModels
@Suite struct EventKitSyncWatermarkTests {
    @Test func TimestampToleranceTwoSeconds() {
        let baseline = Date(timeIntervalSinceReferenceDate: 100_000)
        let withinTolerance = baseline.addingTimeInterval(1.5)
        let beyondTolerance = baseline.addingTimeInterval(2.1)

        #expect(!(EventKitSyncWatermark.isTimestampNewer(withinTolerance, than: baseline)))
        #expect(EventKitSyncWatermark.isTimestampNewer(beyondTolerance, than: baseline))
    }

    @Test func NilRemoteModifiedWithUnchangedFingerprint() {
        let changed = EventKitSyncWatermark.didRemoteChange(
            remoteLastModified: nil,
            watermark: Date(timeIntervalSinceReferenceDate: 100),
            previousFingerprint: "fp-1",
            currentFingerprint: "fp-1"
        )

        #expect(!(changed))
    }

    @Test func NilRemoteModifiedWithChangedFingerprint() {
        let changed = EventKitSyncWatermark.didRemoteChange(
            remoteLastModified: nil,
            watermark: Date(timeIntervalSinceReferenceDate: 100),
            previousFingerprint: "fp-1",
            currentFingerprint: "fp-2"
        )

        #expect(changed)
    }

    @Test func RemoteFreshnessUnknownWhenModifiedIsNilAndFingerprintUnchanged() {
        let state = EventKitSyncWatermark.classifyRemoteFreshness(
            remoteLastModified: nil,
            watermark: Date(timeIntervalSinceReferenceDate: 1_000),
            previousObservedRemoteModified: Date(timeIntervalSinceReferenceDate: 1_200),
            previousFingerprint: "fp-1",
            currentFingerprint: "fp-1"
        )

        #expect(state == .unknown)
    }
}
