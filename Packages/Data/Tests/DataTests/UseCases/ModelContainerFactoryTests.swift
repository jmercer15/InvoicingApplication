import Foundation
import Testing
import SwiftData
@testable import Data
import Core
import PersistenceModels

@MainActor
@Suite struct ModelContainerFactoryTests {
    @Test func AppSchemaContainsExpectedCoreModels() {
        let modelIDs = Set(PersistenceModels.PersistenceSchema.appModels.map(ObjectIdentifier.init))

        #expect(modelIDs.contains(ObjectIdentifier(Client.self)))
        #expect(modelIDs.contains(ObjectIdentifier(Invoice.self)))
        #expect(modelIDs.contains(ObjectIdentifier(Session.self)))
        #expect(modelIDs.contains(ObjectIdentifier(TravelCharge.self)))
        #expect(modelIDs.contains(ObjectIdentifier(TravelChargeAuditLog.self)))
        #expect(modelIDs.contains(ObjectIdentifier(ServiceAgreement.self)))
        #expect(modelIDs.contains(ObjectIdentifier(SupportLog.self)))
        #expect(modelIDs.contains(ObjectIdentifier(SoleTraderCredential.self)))
    }

    @Test func MakeInMemoryContainerWithAppSchemaSucceeds() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        #expect(container.mainContext.container === container)
    }

    @Test func MakeInMemoryContainerWithSubsetSchemaSucceeds() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer(
            models: [RegionalPrice.self]
        )
        #expect(container.mainContext.container === container)
    }

    @Test func MakePersistentContainerWithSubsetSchemaSucceeds() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModelContainerFactoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        PersistenceValueTransformers.registerAll()
        let schema = Schema([RegionalPrice.self])
        let configuration = ModelConfiguration(
            schema: schema,
            url: tempDir.appendingPathComponent("subset.store"),
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        #expect(container.mainContext.container === container)
    }

    /// Regression: equal-checksum VersionedSchemas must not produce MigrationStage.custom pairs.
    @Test func MakePersistentContainerWithAppMigrationPlanDoesNotThrowEqualModelReference() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppMigrationPlan-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        PersistenceValueTransformers.registerAll()
        let schema = Schema(PersistenceModels.PersistenceSchema.appModels)
        let storeURL = tempDir.appendingPathComponent("app.store")
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )

        let first = try ModelContainer(
            for: schema,
            migrationPlan: AppMigrationPlan.self,
            configurations: [configuration]
        )
        #expect(first.mainContext.container === first)

        let reopened = try ModelContainer(
            for: schema,
            migrationPlan: AppMigrationPlan.self,
            configurations: [configuration]
        )
        #expect(reopened.mainContext.container === reopened)
    }

    @Test func MakeInMemoryContextReturnsContainerAndContext() throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext(
            models: [RegionalPrice.self]
        )
        #expect(context.container === container)
        #expect(!(context.autosaveEnabled))
    }

    @Test func persistentStoreURLAndRecoveryCopyUseAppSpecificDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModelContainerFactoryRecovery-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = try ModelContainerFactory.persistentStoreURL(applicationSupportDirectory: directory)
        #expect(storeURL.lastPathComponent == ModelContainerFactory.persistentStoreFileName)
        #expect(storeURL.deletingLastPathComponent().lastPathComponent == ModelContainerFactory.applicationSupportDirectoryName)

        try Data("store".utf8).write(to: storeURL)
        try Data("wal".utf8).write(to: URL(fileURLWithPath: storeURL.path + "-wal"))
        let recoveryCopy = try PersistentStoreRecovery.createRecoveryCopyIfNeeded(for: storeURL)
        let recoveryDirectory = try #require(recoveryCopy)
        #expect(FileManager.default.fileExists(atPath: recoveryDirectory.appendingPathComponent(storeURL.lastPathComponent).path))
        #expect(FileManager.default.fileExists(atPath: recoveryDirectory.appendingPathComponent(storeURL.lastPathComponent + "-wal").path))
        #expect(FileManager.default.fileExists(atPath: storeURL.path))
    }

    @Test func freshInstallArchiveMovesStoreAndSidecarsWithoutDeletion() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FreshInstallArchive-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let storeURL = directory.appendingPathComponent("InvoicingApplication.store")
        try Data("store".utf8).write(to: storeURL)
        try Data("shm".utf8).write(to: URL(fileURLWithPath: storeURL.path + "-shm"))

        let archiveResult = try PersistentStoreRecovery.archiveForFreshInstall(storeURL: storeURL)
        let archive = try #require(archiveResult)
        #expect(!FileManager.default.fileExists(atPath: storeURL.path))
        #expect(FileManager.default.fileExists(atPath: archive.appendingPathComponent(storeURL.lastPathComponent).path))
        #expect(FileManager.default.fileExists(atPath: archive.appendingPathComponent(storeURL.lastPathComponent + "-shm").path))
    }
}
