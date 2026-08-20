import Testing
import CoreTesting
import Core
import PersistenceModels
@testable import Data

@MainActor
@Suite(.tags(.unit))
struct CloudKitSyncMonitorTests {
    @Test func headlessMonitorStartsIdleWithoutLiveCloudKit() {
        let monitor = CloudKitSyncMonitor(startsLiveMonitoring: false)
        #expect(monitor.syncState == .idle)
        #expect(!monitor.syncState.isActive)
        #expect(!monitor.syncState.isError)
    }

    @Test func syncStateDisplayTextMatchesPhase() {
        #expect(CloudKitSyncState.idle.displayText == "Idle")
        #expect(CloudKitSyncState.importing.displayText == "Importing")
        #expect(CloudKitSyncState.exporting.displayText == "Exporting")
        #expect(CloudKitSyncState.error("quota").displayText == "quota")
        #expect(CloudKitSyncState.persistentError("offline").displayText == "offline")
    }
}
