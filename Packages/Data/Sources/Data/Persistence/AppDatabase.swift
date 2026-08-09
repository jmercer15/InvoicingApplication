import Foundation
import SwiftData

/// Canonical persistence facade for app bootstrap and worker creation.
///
/// **Manual-save contract:** Every app `ModelContext` — workspace scene environments, Settings,
/// `makeMainContext()`, and ephemeral billing/worker contexts — must keep `autosaveEnabled = false`.
/// Call `save()` explicitly to commit. Use `ModelContainerFactory.makeEphemeralContext(from:)` for
/// short-lived contexts off the shared container.
///
/// **Background actors:** `makeDataImporterActor`, `makeDataExporterActor`, `makeBulkClaimBuilderActor`, and `makeTravelChargeAutomationActor` are the supported construction sites for heavy SwiftData model actors. Callers should keep using these rather than ad-hoc `ModelActor` initializers elsewhere.
public struct AppDatabase: Sendable {
    public enum BootstrapError: LocalizedError, Sendable {
        case productionSyncRequired(underlyingError: String)
        case existingStoreRequiresFreshStart(storePath: String, underlyingError: String)

        public var errorDescription: String? {
            switch self {
            case let .productionSyncRequired(underlyingError):
                return "Production persistence bootstrap requires a CloudKit-compatible store. Underlying error: \(underlyingError)"
            case let .existingStoreRequiresFreshStart(storePath, _):
                return "An existing data store cannot be opened by this version. Its files remain at \(storePath). Choose Start Fresh to archive that store and create empty app data."
            }
        }
    }

    public let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    /// Build requested SwiftData container.
    public static func bootstrap(policy: PersistenceBootstrapPolicy = .productionSyncRequired) async throws -> AppDatabase {
        let container: ModelContainer
        switch policy {
        case .productionSyncRequired:
            do {
                container = try ModelContainerFactory.makePersistentContainer(cloudSyncEnabled: policy.cloudSyncEnabled)
            } catch {
                let storeURL = try ModelContainerFactory.persistentStoreURL()
                if !AppMigrationPlan.legacyStoreMigrationIsQualified,
                   FileManager.default.fileExists(atPath: storeURL.path) {
                    throw BootstrapError.existingStoreRequiresFreshStart(
                        storePath: storeURL.path,
                        underlyingError: String(describing: error)
                    )
                }
                throw BootstrapError.productionSyncRequired(underlyingError: String(describing: error))
            }
        case .localOnly:
            container = try ModelContainerFactory.makePersistentContainer(cloudSyncEnabled: policy.cloudSyncEnabled)
        case .inMemory:
            container = try ModelContainerFactory.makeInMemoryContainer()
        }

        return AppDatabase(container: container)
    }

    @MainActor
    public func makeMainContext() -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    public func makeDataImporterActor() async -> DataImporterActor {
        DataImporterActor(modelContainer: container)
    }

    public func makeDataExporterActor() async -> DataExporterActor {
        DataExporterActor(modelContainer: container)
    }

    public func makeBulkClaimBuilderActor() async -> BulkClaimBuilderActor {
        BulkClaimBuilderActor(modelContainer: container)
    }

    public func makeTravelChargeAutomationActor() async -> TravelChargeAutomationActor {
        TravelChargeAutomationActor(modelContainer: container)
    }

    /// Compatibility placeholder. Marker-file migrations are intentionally no longer run at
    /// bootstrap. Historical transformations belong in fixture-qualified schema stages.
    public func performPostOpenMigrations() async throws {}

    /// Explicit fresh-install escape hatch for incompatible canonical stores.
    /// Call only after user confirmation; archived files remain beside the store directory.
    public static func archiveExistingStoreForFreshInstall() throws -> URL? {
        let storeURL = try ModelContainerFactory.persistentStoreURL()
        return try PersistentStoreRecovery.archiveForFreshInstall(storeURL: storeURL)
    }
}

public enum CloudKitConfiguration {
    public static let containerIdentifier = "iCloud.com.jesse.InvoicingApplication"
}
