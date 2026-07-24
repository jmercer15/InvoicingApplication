import Core

/// Semantic routing commands from the menu bar / keyboard shortcuts (see ``AppNavigationManager/applyRoutingIntent(_:onCreateInvoice:onCreateSession:)``).
public enum WorkspaceRoutingIntent: Sendable {
    case selectTab(AppTab)
    case createNewInvoice
    case createNewSession
    case toggleInspector
}
