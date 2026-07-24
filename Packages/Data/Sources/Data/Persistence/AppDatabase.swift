import Foundation
import SwiftData

/// Canonical persistence facade for app bootstrap and worker creation.
///
/// **Background actors:** `makeDataImporterActor`, `makeDataExporterActor`, `makeBulkClaimBuilderActor`, and `makeTravelChargeAutomationActor` are the supported construction sites for heavy SwiftData model actors. Callers should keep using these rather than ad-hoc `ModelActor` initializers elsewhere.
public struct AppDatabase: Sendable {
    public enum BootstrapError: LocalizedError, Sendable {
        case productionSyncRequired(underlyingError: String)

        public var errorDescription: String? {
            switch self {
            case let .productionSyncRequired(underlyingError):
                return "Production persistence bootstrap requires a CloudKit-compatible store. Underlying error: \(underlyingError)"
            }
        }
    }

    public let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    /// Build the requested SwiftData container and run post-open migrations when persisted storage is used.
    public static func bootstrap(policy: PersistenceBootstrapPolicy = .productionSyncRequired) async throws -> AppDatabase {
        let container: ModelContainer
        switch policy {
        case .productionSyncRequired:
            do {
                container = try ModelContainerFactory.makePersistentContainer(cloudSyncEnabled: policy.cloudSyncEnabled)
            } catch {
                throw BootstrapError.productionSyncRequired(underlyingError: String(describing: error))
            }
        case .localOnly:
            container = try ModelContainerFactory.makePersistentContainer(cloudSyncEnabled: policy.cloudSyncEnabled)
        case .inMemory:
            container = try ModelContainerFactory.makeInMemoryContainer()
        }

        let database = AppDatabase(container: container)
        if !policy.isStoredInMemoryOnly {
            // Migration completion is part of database readiness. Returning earlier lets feature
            // queries race partially migrated values and hides failures behind a detached task.
            try await database.performPostOpenMigrations()
        }
        return database
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

    public func performPostOpenMigrations() async throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let orchestrator = MigrationOrchestrator()
        _ = try orchestrator.executeAllMigrations(modelContext: context)
    }
}

public enum CloudKitConfiguration {
    public static let containerIdentifier = "iCloud.com.jesse.InvoicingApplication"
}
