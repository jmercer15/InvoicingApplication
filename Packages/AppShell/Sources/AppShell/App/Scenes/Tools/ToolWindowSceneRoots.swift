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
    @Environment(\.openWindow) private var openWindow
    @Environment(ApplicationWorkspaceContext.self) private var workspaceContext
    @Environment(ToolWindowPresenceRegistry.self) private var toolWindowPresence
    @State private var fallbackSession: WorkspaceSceneSession?
    @State private var toolWindowContext = ToolWindowContext(kind: .activityMonitor)
    @State private var appDependencies: AppDependencies
    @State private var pendingCrossFeatureNavigation: ActivityCrossFeatureNavigation.Destination?

    init(runtime: AppRuntime) {
        self.runtime = runtime
        _appDependencies = State(initialValue: AppDependencies(runtime: runtime))
    }

    @ViewBuilder
    var body: some View {
        // Display may use fallback for in-window Activity UI; cross-feature jumps must not.
        let displaySession = workspaceContext.activeWorkspaceSceneSession ?? fallbackSession
        Group {
            if let displaySession {
                ActivityPlaceholderView(
                    billingHubViewModel: displaySession.features.billingHub,
                    openInvoice: { id in
                        navigateCrossFeature(.invoice(id))
                    },
                    openSession: { id in
                        navigateCrossFeature(.session(id))
                    }
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
        .onChange(of: workspaceContext.activeWorkspaceSceneSession?.id) { _, _ in
            flushPendingCrossFeatureNavigationIfPossible()
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

    private func navigateCrossFeature(_ destination: ActivityCrossFeatureNavigation.Destination) {
        if let navigationManager = ActivityCrossFeatureNavigation.navigationManager(
            for: workspaceContext.activeWorkspaceSceneSession
        ) {
            ActivityCrossFeatureNavigation.apply(destination, on: navigationManager)
            return
        }
        pendingCrossFeatureNavigation = destination
        openWindow(id: AppSceneID.workspace.rawValue)
    }

    private func flushPendingCrossFeatureNavigationIfPossible() {
        guard let pending = pendingCrossFeatureNavigation,
              let navigationManager = ActivityCrossFeatureNavigation.navigationManager(
                for: workspaceContext.activeWorkspaceSceneSession
              ) else {
            return
        }
        pendingCrossFeatureNavigation = nil
        ActivityCrossFeatureNavigation.apply(pending, on: navigationManager)
    }
}
