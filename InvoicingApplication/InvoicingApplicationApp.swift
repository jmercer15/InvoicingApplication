import SwiftUI
import AppKit
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
    }

    var body: some Scene {
        InvoicingApplicationSceneTree(
            session: $session,
            workspaceContext: workspaceContext,
            toolWindowPresence: toolWindowPresence
        )
    }
}
