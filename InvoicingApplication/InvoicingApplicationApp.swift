import SwiftUI
import AppKit
import AppIntents
import AppShell

@MainActor
@main
struct InvoicingApplicationApp: App {
    @State private var session = AppSession()
    @State private var workspaceContext = ApplicationWorkspaceContext()
    @State private var toolWindowPresence = ToolWindowPresenceRegistry()

    init() {
        // Configure the appearance of NSWindow's titlebar controls
        NSWindow.allowsAutomaticWindowTabbing = false
        AppIntentBootstrap.registerSharedDependencies()
        AppShortcutParameterRefresh.prepareForLaunch()
        AppShortcutParameterRefresh.refreshHandler = {
            InvoicingAppShortcuts.updateAppShortcutParameters()
        }
        // No eager launch refresh — LinkDaemon often returns 9004 for minutes under Xcode,
        // and each call also triggers CSInlineDonation SetStore noise.
    }

    var body: some Scene {
        InvoicingApplicationSceneTree(
            session: $session,
            workspaceContext: workspaceContext,
            toolWindowPresence: toolWindowPresence
        )
        .environment(WorkspaceIntentDeliveryCenter.shared)
    }
}

extension InvoicingApplicationApp: AppIntentsPackage {
    nonisolated static var includedPackages: [any AppIntentsPackage.Type] {
        [AppShellAppIntentsPackage.self]
    }
}
