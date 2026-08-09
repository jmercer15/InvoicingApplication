import SharedUI
import Foundation

/// App-owned routing bridge used by feature views that surface related entities.
/// Feature packages emit stable UUIDs; AppShell owns tab/path mutation.
struct WorkspaceEntityNavigationHandlers {
    let openInvoice: (UUID) -> Void
    let openInvoiceFromBillingHub: (UUID, UUID?) -> Void
    let openSession: (UUID) -> Void
    let openClient: (UUID) -> Void
    let openPayee: (UUID) -> Void
    let openPlanManager: (UUID) -> Void
    let openNDISItem: (UUID) -> Void
}

/// Continuity stamp when Hub opens an invoice editor (Create Draft or Open Invoice).
enum BillingHubInvoiceNavigationFocus {
    /// Always the opened invoice UUID so Invoices → Back finds the invoice card on the board.
    static func focusCardID(forOpenedInvoice invoiceID: UUID) -> UUID { invoiceID }
}

@MainActor
func makeWorkspaceEntityNavigationHandlers(
    navigationManager: AppNavigationManager
) -> WorkspaceEntityNavigationHandlers {
    WorkspaceEntityNavigationHandlers(
        openInvoice: { navigationManager.navigateToInvoice($0) },
        openInvoiceFromBillingHub: { invoiceID, focusCardID in
            navigationManager.navigateToInvoice(
                invoiceID,
                sourceTab: .billingHub,
                sourceFocusID: focusCardID
            )
        },
        openSession: { navigationManager.navigateToSession($0) },
        openClient: { navigationManager.navigateToClient($0) },
        openPayee: { navigationManager.navigateToPayee($0) },
        openPlanManager: { navigationManager.navigateToPlanManager($0) },
        openNDISItem: { navigationManager.navigateToNDISItem($0) }
    )
}
