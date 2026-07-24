import SwiftUI
import SwiftData

/// Inspector singleton tool window. Owns a per-scene `WorkspaceSceneSession` and publishes
/// focused-scene tool window context for command routing.
struct InspectorSceneRoot: View {
    let runtime: AppRuntime

    @Environment(\.modelContext) private var modelContext
    @Environment(ApplicationWorkspaceContext.self) private var workspaceContext
    @Environment(ToolWindowPresenceRegistry.self) private var toolWindowPresence
    @State private var fallbackSession: WorkspaceSceneSession?
    @State private var toolWindowContext = ToolWindowContext(kind: .standaloneInspector)
    @State private var appDependencies: AppDependencies

    init(runtime: AppRuntime) {
        self.runtime = runtime
        _appDependencies = State(initialValue: AppDependencies(runtime: runtime))
    }

    @ViewBuilder
    var body: some View {
        let session = workspaceContext.activeWorkspaceSceneSession ?? fallbackSession
        Group {
            if let session {
                InspectorPlaceholderView(
                    features: session.features,
                    navigationManager: session.navigationManager
                )
                .withAppDependencies(appDependencies)
            } else {
                ActivityPlaceholderLoadingView()
            }
        }
        .focusedSceneValue(\.toolWindowContext, toolWindowContext)
        .onAppear {
            toolWindowContext.isOpen = true
            toolWindowPresence.setInspectorStandaloneOpen(true)
        }
        .onDisappear {
            toolWindowContext.isOpen = false
            toolWindowPresence.setInspectorStandaloneOpen(false)
        }
        .task {
            guard fallbackSession == nil else { return }
            await Task.yield()
            fallbackSession = WorkspaceSceneSession(
                .init(
                    database: runtime.database,
                    services: runtime.services,
                    ndisBillingIntegrationService: runtime.ndisBillingIntegrationService,
                    modelContext: modelContext
                )
            )
        }
    }
}

/// Activity singleton tool window.
struct ActivitySceneRoot: View {
    let runtime: AppRuntime

    @Environment(\.modelContext) private var modelContext
    @Environment(ApplicationWorkspaceContext.self) private var workspaceContext
    @Environment(ToolWindowPresenceRegistry.self) private var toolWindowPresence
    @State private var fallbackSession: WorkspaceSceneSession?
    @State private var toolWindowContext = ToolWindowContext(kind: .activityMonitor)
    @State private var appDependencies: AppDependencies

    init(runtime: AppRuntime) {
        self.runtime = runtime
        _appDependencies = State(initialValue: AppDependencies(runtime: runtime))
    }

    @ViewBuilder
    var body: some View {
        let session = workspaceContext.activeWorkspaceSceneSession ?? fallbackSession
        Group {
            if let session {
                let entityNavigation = makeWorkspaceEntityNavigationHandlers(
                    navigationManager: session.navigationManager
                )
                ActivityPlaceholderView(
                    billingHubViewModel: session.features.billingHub,
                    openInvoice: entityNavigation.openInvoice,
                    openSession: entityNavigation.openSession
                )
                .withAppDependencies(appDependencies, includeCloudKitSyncMonitor: true)
            } else {
                ActivityPlaceholderLoadingView()
            }
        }
        .focusedSceneValue(\.toolWindowContext, toolWindowContext)
        .onAppear {
            toolWindowContext.isOpen = true
            toolWindowPresence.setActivityMonitorOpen(true)
        }
        .onDisappear {
            toolWindowContext.isOpen = false
            toolWindowPresence.setActivityMonitorOpen(false)
        }
        .task {
            guard fallbackSession == nil else { return }
            await Task.yield()
            fallbackSession = WorkspaceSceneSession(
                .init(
                    database: runtime.database,
                    services: runtime.services,
                    ndisBillingIntegrationService: runtime.ndisBillingIntegrationService,
                    modelContext: modelContext
                )
            )
        }
    }
}
