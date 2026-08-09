import SwiftData
import Core
import Data
import DataInterfaces

@MainActor
public enum CalendarWorkspaceFactory {
    public struct Dependencies {
        public let modelContext: ModelContext
        public let eventKitService: EventKitSyncService
        public let recurrenceRuleManager: RecurrenceRuleManager
        public let storeChangeMonitor: (any StoreChangeMonitoring)?

        public init(
            modelContext: ModelContext,
            eventKitService: EventKitSyncService,
            recurrenceRuleManager: RecurrenceRuleManager,
            storeChangeMonitor: (any StoreChangeMonitoring)? = nil
        ) {
            self.modelContext = modelContext
            self.eventKitService = eventKitService
            self.recurrenceRuleManager = recurrenceRuleManager
            self.storeChangeMonitor = storeChangeMonitor
        }
    }

    public static func makeViewModel(
        _ dependencies: Dependencies
    ) -> CalendarViewModel {
        let syncService: SyncService = EventKitSyncServiceAdapter(
            modelContext: dependencies.modelContext,
            eventKitService: dependencies.eventKitService
        )
        return CalendarViewModel(
            modelContext: dependencies.modelContext,
            modelContainer: dependencies.modelContext.container,
            syncService: syncService,
            eventKitService: dependencies.eventKitService,
            recurrenceRuleManager: dependencies.recurrenceRuleManager,
            storeChangeMonitor: dependencies.storeChangeMonitor
        )
    }
}

extension EventKitSyncService: CalendarEventService {
}
