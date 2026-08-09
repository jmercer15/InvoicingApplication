import SwiftUI
import Core
import DataInterfaces
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
            .environment(\.referenceDataFetching, deps.workspace.referenceDataFetching)
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
            .environment(\.referenceDataFetching, deps.settings.referenceDataFetching)
            .environment(\.claimBatchPersisting, deps.settings.claimBatchPersisting)
            .environment(\.businessPersisting, deps.settings.businessPersisting)
            .environment(\.travelChargeReviewFetching, deps.settings.travelChargeReviewFetching)
            .environment(\.databaseHealthChecking, deps.settings.databaseHealthChecking)
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
