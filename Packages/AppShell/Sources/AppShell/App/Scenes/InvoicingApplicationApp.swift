//
//  InvoicingApplicationApp.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//

import SwiftUI
import SwiftData

@MainActor
public struct InvoicingApplicationSceneTree: Scene {
    @Binding private var session: AppSession
    private let workspaceContext: ApplicationWorkspaceContext
    private let toolWindowPresence: ToolWindowPresenceRegistry

    public init(
        session: Binding<AppSession>,
        workspaceContext: ApplicationWorkspaceContext,
        toolWindowPresence: ToolWindowPresenceRegistry
    ) {
        self._session = session
        self.workspaceContext = workspaceContext
        self.toolWindowPresence = toolWindowPresence
    }

    public var body: some Scene {
        WindowGroup("Workspace", id: AppSceneID.workspace.rawValue) {
            SessionPhaseRoot(
                phase: session.phase,
                retry: { await session.bootstrap() },
                startFresh: { await session.startFresh() },
                loading: { WorkspaceStartupLoadingView() },
                ready: { runtime in
                    WorkspaceWindowRoot(runtime: runtime)
                        .manualSaveModelContext(container: runtime.modelContainer)
                }
            )
            .environment(workspaceContext)
            .environment(toolWindowPresence)
            .task {
                await session.bootstrap()
            }
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.expanded)
        #endif
        .commands {
            SidebarCommands()
            ToolbarCommands()
            InspectorCommands()
            TextEditingCommands()
            TextFormattingCommands()
            AppCommandSet()
        }

        Settings {
            SessionPhaseRoot(
                phase: session.phase,
                retry: { await session.bootstrap() },
                startFresh: { await session.startFresh() },
                loading: { SettingsStartupLoadingView() },
                ready: { runtime in
                    SettingsSceneRoot(runtime: runtime)
                        .manualSaveModelContext(container: runtime.modelContainer)
                }
            )
            .environment(workspaceContext)
            .environment(toolWindowPresence)
            .task {
                await session.bootstrap()
            }
        }

        UtilityWindow("Inspector", id: AppSceneID.inspector.rawValue) {
            SessionPhaseRoot(
                phase: session.phase,
                retry: { await session.bootstrap() },
                startFresh: { await session.startFresh() },
                loading: { ActivityPlaceholderLoadingView() },
                ready: { runtime in
                    InspectorSceneRoot(runtime: runtime)
                        .manualSaveModelContext(container: runtime.modelContainer)
                }
            )
            .environment(workspaceContext)
            .environment(toolWindowPresence)
            .task {
                await session.bootstrap()
            }
        }
        .commandsRemoved()
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        UtilityWindow("Activity", id: AppSceneID.activity.rawValue) {
            SessionPhaseRoot(
                phase: session.phase,
                retry: { await session.bootstrap() },
                startFresh: { await session.startFresh() },
                loading: { ActivityPlaceholderLoadingView() },
                ready: { runtime in
                    ActivitySceneRoot(runtime: runtime)
                        .manualSaveModelContext(container: runtime.modelContainer)
                }
            )
            .environment(workspaceContext)
            .environment(toolWindowPresence)
            .task {
                await session.bootstrap()
            }
        }
        .commandsRemoved()
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
    }

}
