import Foundation
import SwiftData



@globalActor
public actor BackgroundPersistenceActor: GlobalActor {
    public static let shared = BackgroundPersistenceActor()
    
    public let modelContainer: ModelContainer
    
    /// A dedicated background context for heavy operations and writes.
    /// This context is bound to the BackgroundPersistenceActor.
    public lazy var backgroundContext: ModelContext = {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        return context
    }()
    
    private init() {
        let schema = Schema([
            ClientEntity.self,
            BusinessEntity.self,
            AddressEntity.self,
            InvoiceEntity.self,
            InvoiceItemEntity.self,
            ClientServiceEntity.self,
            PayeeEntity.self,
            PlanManagerEntity.self,
            SessionEntity.self,
            TravelChargeEntity.self,
            TravelChargeAuditLogEntity.self,
            TravelChargeReviewItemEntity.self,
            CreditHistoryEntryEntity.self,
            NDISItemEntity.self,
            RegionalPriceEntity.self,
            ServiceAgreementEntity.self,
            SupportLogEntity.self,
            BulkClaimBatchEntity.self,
            BulkClaimLineEntity.self
        ])

        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            PersistentStoreSanitizer.sanitizeLegacyStatusesIfNeeded()
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("[BackgroundPersistenceActor] ModelContainer initialized successfully.")
        } catch {
            fatalError("[BackgroundPersistenceActor] Failed to create ModelContainer: \(error)")
        }
    }
    
    /// Executes all pending migrations using the background context.
    public func performMigrations() {
        let orchestrator = MigrationOrchestrator()
        do {
            _ = try orchestrator.executeAllMigrations(modelContext: backgroundContext)
        } catch {
            print("[BackgroundPersistenceActor] Migration failed: \(error)")
        }
    }

    /// Creates a new ModelContext bound to the Main Actor.
    /// Must be called from the Main Actor.
    @MainActor
    public func createMainContext() -> ModelContext {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        return context
    }
}
