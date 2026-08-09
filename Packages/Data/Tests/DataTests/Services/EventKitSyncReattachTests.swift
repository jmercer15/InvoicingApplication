@testable import Data
import Core
import Testing
import PersistenceModels
@Suite struct EventKitSyncReattachTests {
    @Test func MovedOutOfWindowReattach() {
        #expect(EventKitSyncPolicy.didReattach(
                hasWindowMatch: false,
                hasResolvedMatch: true
            ))
        let outcome = EventKitSyncPolicy.staleMissOutcome(
            currentMisses: 1,
            hasWindowMatch: false,
            hasResolvedMatch: true
        )
        #expect(outcome.nextMisses == 0)
        #expect(!(outcome.shouldMarkStale))
    }

    @Test func UnresolvedRequiresTwoMissesBeforeStale() {
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
}
