import SwiftUI
import SwiftData
import Core
import Data

/// Per-window workspace root. Each `WindowGroup` instance creates its own
/// `WorkspaceSceneSession`, giving every workspace window independent navigation and feature
/// view-model caches. Features inherit SwiftUI's scene `ModelContext` from the scene model container.
@MainActor
struct WorkspaceWindowRoot: View {
    let runtime: AppRuntime

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ApplicationWorkspaceContext.self) private var workspaceContext
    @State private var sceneSession: WorkspaceSceneSession?
    @State private var appDependencies: AppDependencies

    init(runtime: AppRuntime) {
        self.runtime = runtime
        _appDependencies = State(initialValue: AppDependencies(runtime: runtime))
    }

    var body: some View {
        Group {
            if let sceneSession {
                ContentView(
                    features: sceneSession.features,
                    navigationManager: sceneSession.navigationManager
                )
                .withAppDependencies(appDependencies)
                .focusedSceneValue(\.activeWorkspaceSceneSession, sceneSession)
            } else {
                WorkspaceStartupLoadingView()
            }
        }
        .task {
            guard sceneSession == nil else { return }
            await Task.yield()
            let session = WorkspaceSceneSession(
                .init(
                    database: runtime.database,
                    services: runtime.services,
                    ndisBillingIntegrationService: runtime.ndisBillingIntegrationService,
                    modelContext: modelContext
                )
            )
            sceneSession = session
            workspaceContext.activate(session)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, let sceneSession else { return }
            workspaceContext.activate(sceneSession)
        }
        .onDisappear {
            guard let sceneSession else { return }
            workspaceContext.release(sceneSession)
        }
    }
}
