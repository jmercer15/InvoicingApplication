import SwiftData
import Core
import Data
import Feature_Calendar

@MainActor
final class CalendarFeature {
    private struct Dependencies {
        let context: ModelContext
        let services: AppRuntime.Services
    }

    private let dependencies: Dependencies
    private var storage: CalendarViewModel?

    init(context: ModelContext, services: AppRuntime.Services) {
        self.dependencies = Dependencies(context: context, services: services)
    }

    func viewModel() -> CalendarViewModel {
        if let storage {
            return storage
        }

        let viewModel = CalendarWorkspaceFactory.makeViewModel(
            .init(
                modelContext: dependencies.context,
                eventKitService: dependencies.services.eventKitSyncService,
                recurrenceRuleManager: dependencies.services.recurrenceRuleManager,
                storeChangeMonitor: dependencies.services.storeChangeMonitor
            )
        )
        storage = viewModel
        return viewModel
    }
}
