import SwiftUI
import Core
import SharedUI
import WorkspaceUI

public extension View {
    /// Injects the app-wide dependency graph plus compatibility environment keys currently used by features.
    @ViewBuilder
    func withAppDependencies(
        _ deps: AppDependencies,
        includeCloudKitSyncMonitor: Bool = false
    ) -> some View {
        let configured = self
            .environment(deps)
            .environment(deps.workspace)
            .environment(deps.runtime.storeChangeMonitor)
            .bridgeWorkspaceDependencies(deps.workspace)

        if includeCloudKitSyncMonitor {
            configured.environment(\EnvironmentValues.cloudKitSyncMonitor, deps.workspace.cloudKitSyncMonitor)
        } else {
            configured
        }
    }

    private func bridgeWorkspaceDependencies(_ workspace: WorkspaceDependencies) -> some View {
        self.workspaceStandardServicesEnvironment(standardServicesDependencies(workspace))
    }

    func withSettingsDependencies(_ deps: AppDependencies) -> some View {
        self
            .environment(deps)
            .environment(deps.settings)
            .environment(\.modelContext, deps.settings.modelContext)
            .environment(\.settingsServices, deps.settings.settingsServices)
            .workspaceStandardServicesEnvironment(settingsStandardServicesDependencies(deps.workspace))
    }

    private func settingsStandardServicesDependencies(_ workspace: WorkspaceDependencies) -> WorkspaceStandardServicesDependencies {
        WorkspaceStandardServicesDependencies(
            geocodingService: workspace.geocodingService,
            swiftDataGeocodingService: workspace.swiftDataGeocodingService,
            eventKitSyncService: workspace.eventKitSyncService,
            calendarPreferencesStore: workspace.calendarPreferencesStore,
            mmmZoneLookup: workspace.mmmZoneLookup,
            recurrenceRuleManager: workspace.recurrenceRuleManager,
            ndisBillingIntegrationService: workspace.ndisBillingIntegrationService
        )
    }

    private func standardServicesDependencies(_ workspace: WorkspaceDependencies) -> WorkspaceStandardServicesDependencies {
        WorkspaceStandardServicesDependencies(
            geocodingService: workspace.geocodingService,
            swiftDataGeocodingService: workspace.swiftDataGeocodingService,
            eventKitSyncService: workspace.eventKitSyncService,
            calendarPreferencesStore: workspace.calendarPreferencesStore,
            mmmZoneLookup: workspace.mmmZoneLookup,
            recurrenceRuleManager: workspace.recurrenceRuleManager,
            ndisBillingIntegrationService: workspace.ndisBillingIntegrationService
        )
    }
}
