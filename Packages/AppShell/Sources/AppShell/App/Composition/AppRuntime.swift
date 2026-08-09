import SwiftData
import Core
import Data
import DataInterfaces

/// App-session-scoped runtime wiring shared database, services, persistence, and tool-window state.
/// Per-workspace UI state lives on ``WorkspaceSceneSession`` inside each scene `WindowGroup`.
@MainActor
public struct AppRuntime {
    let database: AppDatabase
    let services: Services
    let persistence: Persistence
    let ndisBillingIntegrationService: any Core.NDISBillingIntegrationServiceProtocol

    var modelContainer: ModelContainer { database.container }
    var settingsContext: ModelContext { persistence.settingsContext }
    var settingsServices: SettingsServices { persistence.settingsServices }
    var settingsPersistence: SettingsPersistence { persistence.settingsPersistence }
    var cloudKitSyncMonitor: CloudKitSyncMonitor { services.cloudKitSyncMonitor }
    var storeChangeMonitor: SwiftDataStoreChangeMonitor { services.storeChangeMonitor }

    /// App-wide services wired once at bootstrap. Per-window navigation state lives on `WorkspaceSceneSession`.
    public struct Services {
        /// User calendar display/sync preferences (week start, visible calendars, etc.).
        public let calendarPreferencesStore: CalendarPreferencesStore
        /// Pure MapKit geocoder actor (no SwiftData persistence).
        public let geocodingService: GeocodingService
        /// Main-actor geocoder that writes coordinates onto SwiftData entities.
        public let swiftDataGeocodingService: SwiftDataGeocodingService
        /// Modified Monash Model zone lookup for NDIS travel pricing.
        public let mmmZoneLookup: MMMZoneLookup
        /// Recurrence rule expansion and editing helpers shared by calendar flows.
        public let recurrenceRuleManager: RecurrenceRuleManager
        /// Observes CloudKit sync events for Settings status UI.
        public let cloudKitSyncMonitor: CloudKitSyncMonitor
        /// Publishes coarse store revision changes for catalogue refresh hooks.
        public let storeChangeMonitor: SwiftDataStoreChangeMonitor
        /// EventKit ↔ SwiftData session synchronization service.
        public let eventKitSyncService: EventKitSyncService
        /// Invoice PDF/layout digest helper used by template and export flows.
        public let invoiceDigesting: any InvoiceDigesting
        /// Read-only reference data (clients, payees, NDIS items) for feature modules.
        public let referenceDataFetching: any ReferenceDataFetching
        /// NDIS catalogue/version fetch surface for Feature.NDIS.
        public let ndisCatalogueFetching: any NDISCatalogueFetching
    }

    /// Settings-window-scoped persistence. `settingsContext` is a manual-save context backing the
    /// Settings scene and Settings-only services.
    public struct Persistence {
        public let settingsContext: ModelContext
        public let settingsServices: SettingsServices
        public let settingsPersistence: SettingsPersistence
    }

    /// Protocol-backed persistence helpers for Settings feature modules.
    public struct SettingsPersistence {
        public let claimBatchPersisting: any ClaimBatchPersisting
        public let businessPersisting: any BusinessPersisting
        public let travelChargeReviewFetching: any TravelChargeReviewFetching
        public let databaseHealthChecking: any DatabaseHealthChecking
        public let clientRelationshipDeleting: any ClientRelationshipDeleting

        public init(
            claimBatchPersisting: any ClaimBatchPersisting,
            businessPersisting: any BusinessPersisting,
            travelChargeReviewFetching: any TravelChargeReviewFetching,
            databaseHealthChecking: any DatabaseHealthChecking,
            clientRelationshipDeleting: any ClientRelationshipDeleting
        ) {
            self.claimBatchPersisting = claimBatchPersisting
            self.businessPersisting = businessPersisting
            self.travelChargeReviewFetching = travelChargeReviewFetching
            self.databaseHealthChecking = databaseHealthChecking
            self.clientRelationshipDeleting = clientRelationshipDeleting
        }
    }
}
