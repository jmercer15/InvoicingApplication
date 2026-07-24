import XCTest
import SwiftData
import Core
@testable import Data

final class AppDatabaseBootstrapTests: XCTestCase {
    func testBootstrapPoliciesExposeExpectedStorageAndSyncFlags() {
        XCTAssertTrue(PersistenceBootstrapPolicy.productionSyncRequired.cloudSyncEnabled)
        XCTAssertFalse(PersistenceBootstrapPolicy.productionSyncRequired.isStoredInMemoryOnly)

        XCTAssertFalse(PersistenceBootstrapPolicy.localOnly.cloudSyncEnabled)
        XCTAssertFalse(PersistenceBootstrapPolicy.localOnly.isStoredInMemoryOnly)

        XCTAssertFalse(PersistenceBootstrapPolicy.inMemory.cloudSyncEnabled)
        XCTAssertTrue(PersistenceBootstrapPolicy.inMemory.isStoredInMemoryOnly)
    }

    @MainActor
    func testInMemoryBootstrapSucceedsAndMainContextDisablesAutosave() async throws {
        let database = try await AppDatabase.bootstrap(policy: .inMemory)
        let context = database.makeMainContext()

        XCTAssertFalse(context.autosaveEnabled)
    }

    /// Two workspace windows must each receive an independent `ModelContext` so that staged changes
    /// in one window's UI do not leak into another window's UI before save. They must, however,
    /// share the same underlying `ModelContainer` so persisted state stays coherent.
    @MainActor
    func testMakeMainContextReturnsIndependentManualSaveContextsSharingTheSameContainer() async throws {
        let database = try await AppDatabase.bootstrap(policy: .inMemory)
        let firstContext = database.makeMainContext()
        let secondContext = database.makeMainContext()

        XCTAssertFalse(firstContext.autosaveEnabled)
        XCTAssertFalse(secondContext.autosaveEnabled)
        XCTAssertFalse(firstContext === secondContext)
        XCTAssertTrue(firstContext.container === secondContext.container)
        XCTAssertTrue(firstContext.container === database.container)
    }

    @MainActor
    func testUnsavedChangesDoNotLeakBetweenWorkspaceContexts() async throws {
        let database = try await AppDatabase.bootstrap(policy: .inMemory)
        let firstContext = database.makeMainContext()
        let secondContext = database.makeMainContext()
        let clientName = "Scene Isolation Test Client"

        firstContext.insert(Client(fullName: clientName))

        var descriptor = FetchDescriptor<Client>(
            predicate: #Predicate { $0.fullName == clientName }
        )
        descriptor.fetchLimit = 1

        XCTAssertTrue(try secondContext.fetch(descriptor).isEmpty)

        try firstContext.save()

        XCTAssertEqual(try secondContext.fetch(descriptor).count, 1)
    }
}
