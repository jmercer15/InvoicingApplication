import Foundation
import UniformTypeIdentifiers

/// Result of a card move operation
public enum MoveResult: Error, Equatable, Sendable {
    case success
    /// Forward transition succeeded but compliance produced warnings (invoice still moved).
    case successWithComplianceWarnings
    case notFound
    case invalidTransition(from: String, to: String)
    case blocked(String)
    case clientMismatch

    public var isSuccess: Bool {
        switch self {
        case .success, .successWithComplianceWarnings: true
        default: false
        }
    }

    public var description: String {
        switch self {
        case .success: return "Item moved successfully"
        case .successWithComplianceWarnings: return "Item moved with compliance warnings"
        case .notFound: return "Item not found"
        case .invalidTransition(let from, let to): return "Cannot move from '\(from)' to '\(to)'"
        case .blocked(let reason): return "Move blocked: \(reason)"
        case .clientMismatch: return "Sessions must belong to the same client"
        }
    }
}

/// Snapshot of an invoice's state before a bulk action, used for undo.
public struct InvoiceWorkflowSnapshot: Hashable, Sendable {
    public let id: UUID
    public let status: String
    public let sentDate: Date?
    public let paidDate: Date?
}

/// Represents a bulk action that can be undone.
public struct BulkUndoAction: Hashable, Sendable {
    public let label: String
    public let snapshots: [InvoiceWorkflowSnapshot]
}

/// Data for a drag-and-drop operation in the Billing Hub.
public enum BillingHubBoardDragKind: Equatable, Sendable {
    case session(UUID)
    case invoice(UUID)
    case group(UUID) // groupID

    public var id: UUID {
        switch self {
        case .session(let id): return id
        case .invoice(let id): return id
        case .group(let id): return id
        }
    }

    public var type: String {
        switch self {
        case .session: return "session"
        case .invoice: return "invoice"
        case .group: return "group"
        }
    }

    public var contentType: UTType {
        switch self {
        case .session: return .billingHubSessionID
        case .invoice: return .billingHubInvoiceID
        case .group: return .billingHubGroupID
        }
    }

    public var iconName: String {
        switch self {
        case .session: return "calendar"
        case .invoice: return "doc.text"
        case .group: return "square.stack.3d.up"
        }
    }
}

public enum BillingHubDropPolicy: Sendable {
    case sessionsOnly
    case invoicesOnly
    case sessionsAndInvoices

    public func allows(_ dragKind: BillingHubBoardDragKind) -> Bool {
        switch (self, dragKind) {
        case (.sessionsOnly, .session), (.sessionsOnly, .group):
            return true
        case (.invoicesOnly, .invoice):
            return true
        case (.sessionsAndInvoices, _):
            return true
        default:
            return false
        }
    }
}

public extension UTType {
    static let billingHubSessionID = UTType(exportedAs: "com.invoicingapp.billing-hub-session-id")
    static let billingHubInvoiceID = UTType(exportedAs: "com.invoicingapp.billing-hub-invoice-id")
    static let billingHubGroupID = UTType(exportedAs: "com.invoicingapp.billing-hub-group-id")

    static var acceptedTypeIdentifiers: [String] {
        [billingHubSessionID.identifier, billingHubInvoiceID.identifier, billingHubGroupID.identifier]
    }
}
