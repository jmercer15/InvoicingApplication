import Foundation
import Combine

/// Publisher for invoice change events across features
/// Used to coordinate refresh between Invoice feature and Billing Hub
@MainActor
public final class InvoiceChangePublisher: ObservableObject {
    public static let shared = InvoiceChangePublisher()
    
    /// Published when a specific invoice changes
    public let invoiceChanged = PassthroughSubject<UUID, Never>()
    
    /// Published when any invoice change requires a full refresh
    public let invoicesRefreshNeeded = PassthroughSubject<Void, Never>()
    
    private init() {}
    
    /// Notify that a specific invoice has changed
    public func notifyChange(invoiceId: UUID) {
        invoiceChanged.send(invoiceId)
        invoicesRefreshNeeded.send()
    }
    
    /// Notify that invoices need to be refreshed (e.g., after batch operation)
    public func notifyRefreshNeeded() {
        invoicesRefreshNeeded.send()
    }
}
