import Core
import Foundation

/// Semantic routing commands from the menu bar / keyboard shortcuts (see ``AppNavigationManager/applyRoutingIntent(_:onCreateInvoice:onCreateSession:)``).
public enum WorkspaceRoutingIntent: Sendable {
    case selectTab(AppTab)
    /// Switch to Billing Hub and focus Completed card(s) for the given session id(s).
    case openBillingHub(focusSessionIDs: [UUID])
    case createNewInvoice
    case createNewSession
    case toggleInspector
}
