import Foundation
import PersistenceModels

/// Session mutation actions delegated from ``CalendarViewModel`` extensions.
@MainActor
protocol CalendarSessionActionCoordinatorHost: AnyObject {
    var pendingInvoicedSessionAction: InvoicedSessionAction? { get set }
}

@MainActor
final class CalendarSessionActionCoordinator {
    private unowned let host: CalendarSessionActionCoordinatorHost

    init(host: CalendarSessionActionCoordinatorHost) {
        self.host = host
    }

    func requireInvoiceConfirmation(
        for session: Session,
        message: String,
        confirmTitle: String = "Continue",
        isDestructive: Bool = false,
        perform: @escaping () async -> Void
    ) -> Bool {
        guard session.invoice != nil else { return false }
        host.pendingInvoicedSessionAction = InvoicedSessionAction(
            invoiceID: session.invoice?.id,
            message: message,
            confirmTitle: confirmTitle,
            isDestructive: isDestructive,
            perform: perform
        )
        return true
    }

    func confirmPendingInvoicedSessionAction() {
        guard let action = host.pendingInvoicedSessionAction else { return }
        host.pendingInvoicedSessionAction = nil
        Task { await action.perform() }
    }

    func cancelPendingInvoicedSessionAction() {
        host.pendingInvoicedSessionAction = nil
    }
}
