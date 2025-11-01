import Foundation

/// Invoice-related errors
public enum InvoiceError: Error, LocalizedError {
    case noSessionsProvided
    case sessionsNotFound
    case sessionsHaveNoClient
    case sessionsHaveDifferentClients
    case clientNotFound
    case invoiceNotFound
    
    public var errorDescription: String? {
        switch self {
        case .noSessionsProvided:
            return "No sessions provided for invoice creation"
        case .sessionsNotFound:
            return "One or more sessions could not be found"
        case .sessionsHaveNoClient:
            return "Sessions must be associated with a client"
        case .sessionsHaveDifferentClients:
            return "All sessions must belong to the same client"
        case .clientNotFound:
            return "Client not found"
        case .invoiceNotFound:
            return "Invoice not found"
        }
    }
}
