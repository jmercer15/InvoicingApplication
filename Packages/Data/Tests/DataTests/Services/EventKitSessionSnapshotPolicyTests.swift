@testable import Data
import Core
import Foundation
import Testing
import PersistenceModels
@Suite struct EventKitSessionSnapshotPolicyTests {
    @Test func TwoPassStalePolicy() {
        let firstMiss = EventKitSyncPolicy.staleMissOutcome(
            currentMisses: 0,
            hasWindowMatch: false,
            hasResolvedMatch: false
        )
        #expect(firstMiss.nextMisses == 1)
        #expect(!(firstMiss.shouldMarkStale))

        let secondMiss = EventKitSyncPolicy.staleMissOutcome(
            currentMisses: firstMiss.nextMisses,
            hasWindowMatch: false,
            hasResolvedMatch: false
        )
        #expect(secondMiss.nextMisses == 2)
        #expect(secondMiss.shouldMarkStale)
    }

    @Test func ReattachResetsConsecutiveMisses() {
        let reset = EventKitSyncPolicy.staleMissOutcome(
            currentMisses: 2,
            hasWindowMatch: false,
            hasResolvedMatch: true
        )

        #expect(reset.nextMisses == 0)
        #expect(!(reset.shouldMarkStale))
    }

    @Test func NilRemoteModifiedWithStableFingerprintIsUnknownNotChanged() {
        let state = EventKitSyncWatermark.classifyRemoteFreshness(
            remoteLastModified: nil,
            watermark: Date(timeIntervalSinceReferenceDate: 5_000),
            previousObservedRemoteModified: Date(timeIntervalSinceReferenceDate: 5_100),
            previousFingerprint: "stable",
            currentFingerprint: "stable"
        )

        #expect(state == .unknown)
    }
}
