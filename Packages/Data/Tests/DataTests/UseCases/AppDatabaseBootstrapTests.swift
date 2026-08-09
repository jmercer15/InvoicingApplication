import Testing
import SwiftData
import Core
import PersistenceModels
@testable import Data

@Suite struct AppDatabaseBootstrapTests {
    @Test func BootstrapPoliciesExposeExpectedStorageAndSyncFlags() {
        #expect(PersistenceBootstrapPolicy.productionSyncRequired.cloudSyncEnabled)
        #expect(!(PersistenceBootstrapPolicy.productionSyncRequired.isStoredInMemoryOnly))

        #expect(!(PersistenceBootstrapPolicy.localOnly.cloudSyncEnabled))
        #expect(!(PersistenceBootstrapPolicy.localOnly.isStoredInMemoryOnly))

        #expect(!(PersistenceBootstrapPolicy.inMemory.cloudSyncEnabled))
        #expect(PersistenceBootstrapPolicy.inMemory.isStoredInMemoryOnly)
    }

    @MainActor
    @Test func InMemoryBootstrapSucceedsAndMainContextDisablesAutosave() async throws {
        let database = try await AppDatabase.bootstrap(policy: .inMemory)
        let context = database.makeMainContext()

        #expect(!(context.autosaveEnabled))
    }

    /// Two workspace windows must each receive an independent `ModelContext` so that staged changes
    /// in one window's UI do not leak into another window's UI before save. They must, however,
    /// share the same underlying `ModelContainer` so persisted state stays coherent.
    @MainActor
    @Test func MakeMainContextReturnsIndependentManualSaveContextsSharingTheSameContainer() async throws {
        let database = try await AppDatabase.bootstrap(policy: .inMemory)
        let firstContext = database.makeMainContext()
        let secondContext = database.makeMainContext()

        #expect(!(firstContext.autosaveEnabled))
        #expect(!(secondContext.autosaveEnabled))
        #expect(!(firstContext === secondContext))
        #expect(firstContext.container === secondContext.container)
        #expect(firstContext.container === database.container)
    }

    @MainActor
    @Test func UnsavedChangesDoNotLeakBetweenWorkspaceContexts() async throws {
        let database = try await AppDatabase.bootstrap(policy: .inMemory)
        let firstContext = database.makeMainContext()
        let secondContext = database.makeMainContext()
        let clientName = "Scene Isolation Test Client"

        firstContext.insert(Client(fullName: clientName))

        func matchingClients(in context: ModelContext) throws -> [Client] {
            try context.fetch(FetchDescriptor<Client>()).filter { $0.fullName == clientName }
        }

        #expect(try matchingClients(in: secondContext).isEmpty)

        try firstContext.save()

        #expect(try matchingClients(in: secondContext).count == 1)
    }
}
