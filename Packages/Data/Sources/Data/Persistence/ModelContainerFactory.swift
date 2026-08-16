import Core
import Foundation
import PersistenceModels
import SwiftData


public enum ModelContainerFactoryError: Error, Equatable, Sendable {
    case migrationPlanNotSupportedForInMemory
}

public enum ModelContainerFactory {
    public static let persistentStoreFileName = "InvoicingApplication.store"
    public static let applicationSupportDirectoryName = "com.jesse.InvoicingApplication"

    public static func persistentStoreURL(
        fileManager: FileManager = .default,
        applicationSupportDirectory: URL? = nil
    ) throws -> URL {
        let appSupport = try applicationSupportDirectory ?? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = appSupport.appendingPathComponent(applicationSupportDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(persistentStoreFileName, isDirectory: false)
    }

    public static func makePersistentContainer(
        models: [any PersistentModel.Type] = PersistenceSchema.appModels,
        migrationPlan: (any SchemaMigrationPlan.Type)? = AppMigrationPlan.self,
        cloudSyncEnabled: Bool = true,
        storeURL: URL? = nil,
        createRecoveryCopyBeforeOpening: Bool = false
    ) throws -> ModelContainer {
        PersistenceValueTransformers.registerAll()
        let schema = Schema(models)
        let resolvedStoreURL = try storeURL ?? persistentStoreURL()
        if createRecoveryCopyBeforeOpening {
            _ = try PersistentStoreRecovery.createRecoveryCopyIfNeeded(for: resolvedStoreURL)
        }
        let configuration = ModelConfiguration(
            "InvoicingApplication",
            schema: schema,
            url: resolvedStoreURL,
            cloudKitDatabase: cloudSyncEnabled
                ? .private(CloudKitConfiguration.containerIdentifier)
                : .none
        )

        if let migrationPlan {
            return try ModelContainer(for: schema, migrationPlan: migrationPlan, configurations: [configuration])
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    public static func makeInMemoryContainer(
        models: [any PersistentModel.Type] = PersistenceSchema.appModels,
        migrationPlan: (any SchemaMigrationPlan.Type)? = nil
    ) throws -> ModelContainer {
        if migrationPlan != nil {
            throw ModelContainerFactoryError.migrationPlanNotSupportedForInMemory
        }
        PersistenceValueTransformers.registerAll()
        let schema = Schema(models)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    public static func makeInMemoryContext(
        models: [any PersistentModel.Type] = PersistenceSchema.appModels,
        migrationPlan: (any SchemaMigrationPlan.Type)? = nil
    ) throws -> (ModelContainer, ModelContext) {
        let container = try makeInMemoryContainer(models: models, migrationPlan: migrationPlan)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return (container, context)
    }

    /// Ephemeral worker context: always manual-save (`autosaveEnabled = false`).
    public static func makeEphemeralContext(from container: ModelContainer) -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }
}
