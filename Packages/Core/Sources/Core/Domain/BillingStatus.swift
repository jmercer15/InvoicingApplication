import Foundation

/// Canonical billing status enumeration that maps to the kanban workflow
public enum BillingStatus: String, CaseIterable, Codable, Sendable {
    case completed = "completed"
    case grouped = "grouped"
    case addTravel = "needs_travel"
    case reviewDrafts = "review_draft"
    case readyToSend = "ready_to_send"
    case pending = "pending"
    case received = "received"
    case fixAndResubmit = "fix_and_resubmit"

    /// Display name for UI
    public var displayName: String {
        switch self {
        case .completed: return "Completed"
        case .grouped: return "Grouped"
        case .addTravel: return "Add Travel"
        case .reviewDrafts: return "Review Drafts"
        case .readyToSend: return "Ready to Send"
        case .pending: return "Pending"
        case .received: return "Received"
        case .fixAndResubmit: return "Fix and Resubmit"
        }
    }

    /// Column type for kanban board organization
    public var columnType: BillingColumnType {
        switch self {
        case .completed, .grouped:
            return .preparing
        case .addTravel, .reviewDrafts, .readyToSend:
            return .processing
        case .pending, .received:
            return .payment
        case .fixAndResubmit:
            return .processing
        }
    }
}

/// Kanban column grouping for billing workflow
public enum BillingColumnType: String, CaseIterable, Sendable {
    case preparing = "preparing"
    case processing = "processing"
    case payment = "payment"
    
    public var displayName: String {
        switch self {
        case .preparing: return "Preparing"
        case .processing: return "Processing"
        case .payment: return "Payment"
        }
    }
}
