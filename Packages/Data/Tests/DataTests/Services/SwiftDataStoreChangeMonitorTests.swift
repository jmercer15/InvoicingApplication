import Foundation
import Testing
import SwiftData
import Core
import PersistenceModels
@testable import Data

@MainActor
@Suite struct SwiftDataStoreChangeMonitorTests {
    @Test func ContainerLevelMonitorObservesSavesFromIndependentContexts() async throws {
        let database = try await AppDatabase.bootstrap(policy: .inMemory)
        let monitor = SwiftDataStoreChangeMonitor(modelContainer: database.container)
        let workspaceContext = database.makeMainContext()
        let settingsContext = database.makeMainContext()

        var observedRevisions: [Int] = []
        monitor.onRevisionChange { revision in
            observedRevisions.append(revision)
        }

        #expect(monitor.revision == 0)
        #expect(observedRevisions == [0])

        workspaceContext.insert(Business(abn: "11 111 111 111"))
        try workspaceContext.save()
        try await waitForRevision(monitor, observedRevisions: observedRevisions, atLeast: 1)

        settingsContext.insert(Business(abn: "22 222 222 222"))
        try settingsContext.save()
        try await waitForRevision(monitor, observedRevisions: observedRevisions, atLeast: 2)

        #expect(observedRevisions.max() ?? 0 >= 2)
    }

    private func waitForRevision(
        _ monitor: SwiftDataStoreChangeMonitor,
        observedRevisions: @autoclosure () -> [Int],
        atLeast expected: Int,
        timeout: TimeInterval = 5.0
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while monitor.revision < expected || (observedRevisions().max() ?? 0) < expected {
            if Date() >= deadline {
                Issue.record("Expected revision >= \(expected), got monitor.revision \(monitor.revision), observedRevisions max \(observedRevisions().max() ?? 0)")
                return
            }
            await Task.yield()
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}
