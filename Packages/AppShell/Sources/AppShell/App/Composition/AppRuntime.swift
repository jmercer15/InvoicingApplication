import SwiftData
import Core
import Data
import DataInterfaces
import Feature_Settings

/// App-session-scoped runtime: shared database, services, persistence, and singleton tool-window state.
/// Per-workspace state is owned by `WorkspaceSceneSession` and constructed inside each `WindowGroup`.
@MainActor
public struct AppRuntime {
    let database: AppDatabase
    let services: Services
    let persistence: Persistence
    let ndisBillingIntegrationService: any Core.NDISBillingIntegrationServiceProtocol

    var modelContainer: ModelContainer { database.container }
    var settingsContext: ModelContext { persistence.settingsContext }
    var settingsServices: SettingsServices { persistence.settingsServices }
    var cloudKitSyncMonitor: CloudKitSyncMonitor { services.cloudKitSyncMonitor }
    var storeChangeMonitor: SwiftDataStoreChangeMonitor { services.storeChangeMonitor }

    /// App-wide services. Per-window navigation state lives on `WorkspaceSceneSession`.
    public struct Services {
        public let calendarPreferencesStore: CalendarPreferencesStore
        public let geocodingService: GeocodingService
        public let swiftDataGeocodingService: SwiftDataGeocodingService
        public let mmmZoneLookup: MMMZoneLookup
        public let recurrenceRuleManager: RecurrenceRuleManager
        public let cloudKitSyncMonitor: CloudKitSyncMonitor
        public let storeChangeMonitor: SwiftDataStoreChangeMonitor
        public let eventKitSyncService: EventKitSyncService
        public let invoiceDigesting: any InvoiceDigesting
    }

    /// Settings-window-scoped persistence. `settingsContext` is a manual-save context backing the
    /// Settings scene and Settings-only services.
    public struct Persistence {
        public let settingsContext: ModelContext
        public let settingsServices: SettingsServices
    }
}
