import Foundation
import SwiftUI
import Core

public enum Priority: String, CaseIterable, Identifiable, Sendable {
    case low, medium, high

    public var id: String { rawValue }
}

public struct SessionKanbanCardData: Identifiable, Equatable, Sendable {
    public var id: UUID { sessionId }
    public let sessionId: UUID
    public let clientID: UUID?
    public let title: String
    public let clientName: String
    public let serviceName: String
    public let travelRate: Decimal?
    public let travelRateUnit: String?
    public let suggestedTravelDistanceKM: Double?
    public let suggestedTravelTimeMinutes: Double?
    public let priority: Priority
    public let accentColor: Color
    public let duration: String
    public let date: String
    public let hasIssues: Bool
    public let workflowStatus: KanbanCardData.WorkflowStatus
    public let columnType: KanbanCardData.BillingColumnType
    public let startTime: Date?
    public let endTime: Date?
    public let groupID: UUID?

    public static func == (lhs: SessionKanbanCardData, rhs: SessionKanbanCardData) -> Bool {
        lhs.id == rhs.id
    }
}

public struct InvoiceKanbanCardData: Identifiable, Equatable, Sendable {
    public var id: UUID { invoiceId }
    public let invoiceId: UUID
    public let title: String
    public let clientName: String
    public let serviceName: String
    public let priority: Priority
    public let accentColor: Color
    public let amount: String
    public let date: String
    public let workflowStatus: KanbanCardData.WorkflowStatus
    public let columnType: KanbanCardData.BillingColumnType
    public let isOverdue: Bool
    public let daysOverdue: Int?
    public let rawDate: Date?

    public static func == (lhs: InvoiceKanbanCardData, rhs: InvoiceKanbanCardData) -> Bool {
        lhs.id == rhs.id
    }
}

public enum KanbanCardData: Identifiable, Equatable, Sendable {
    case session(SessionKanbanCardData)
    case invoice(InvoiceKanbanCardData)

    public var id: UUID {
        switch self {
        case .session(let data): return data.id
        case .invoice(let data): return data.id
        }
    }

    public var columnType: BillingColumnType {
        switch self {
        case .session(let data): return data.columnType
        case .invoice(let data): return data.columnType
        }
    }

    public var currentWorkflowStatus: WorkflowStatus {
        switch self {
        case .session(let data): return data.workflowStatus
        case .invoice(let data): return data.workflowStatus
        }
    }

    public enum WorkflowStatus: String, CaseIterable, Identifiable, Sendable {
        case completed, grouped, readyToInvoice, draftReview, readyToSend, pendingPayment, paymentReceived
        
        public var id: String { rawValue }

        var recordTitle: String {
            switch self {
            case .completed: "Completed"
            case .grouped: "Grouped"
            case .readyToInvoice: "Travel Review"
            case .draftReview: "Draft Review"
            case .readyToSend: "Ready to Send"
            case .pendingPayment: "Sent"
            case .paymentReceived: "Payment Received"
            }
        }
    }

    public enum BillingColumnType: String, CaseIterable, Identifiable, Codable, Sendable {
        case completed, grouped, addTravel, reviewDrafts, readyToSend, pending, received
        
        public var id: String { rawValue }
    }

    public static func == (lhs: KanbanCardData, rhs: KanbanCardData) -> Bool {
        lhs.id == rhs.id
    }
}

extension KanbanCardData.BillingColumnType {
    var statusToken: String {
        billingStatus.rawValue
    }

    var laneTitle: String {
        switch self {
        case .completed: "Completed"
        case .grouped: "Grouped"
        case .addTravel: "Add Travel"
        case .reviewDrafts: "Review Drafts"
        case .readyToSend: "Ready to Send"
        case .pending: "Sent"
        case .received: "Payment Received"
        }
    }

    var menuTitle: String {
        switch self {
        case .pending: "Sent"
        case .received: "Payment Received"
        default: laneTitle
        }
    }

    var laneIcon: String {
        switch self {
        case .completed: "calendar.badge.checkmark"
        case .grouped: "rectangle.on.rectangle.badge.gearshape"
        case .addTravel: "car"
        case .reviewDrafts: "doc.text.magnifyingglass"
        case .readyToSend: "square.and.arrow.up.badge.clock"
        case .pending: "paperplane"
        case .received: "checkmark.seal"
        }
    }

    var laneTint: Color {
        switch self {
        case .completed, .grouped:
            BillingHubTheme.Columns.preparing
        case .addTravel, .reviewDrafts, .readyToSend:
            BillingHubTheme.Columns.processing
        case .pending, .received:
            BillingHubTheme.Columns.payment
        }
    }

    var workflowStatus: KanbanCardData.WorkflowStatus {
        switch self {
        case .completed: .completed
        case .grouped: .grouped
        case .addTravel: .readyToInvoice
        case .reviewDrafts: .draftReview
        case .readyToSend: .readyToSend
        case .pending: .pendingPayment
        case .received: .paymentReceived
        }
    }

    var billingStatus: BillingStatus {
        switch self {
        case .completed: .completed
        case .grouped: .grouped
        case .addTravel: .addTravel
        case .reviewDrafts: .reviewDrafts
        case .readyToSend: .readyToSend
        case .pending: .pending
        case .received: .received
        }
    }

    var isInvoiceLane: Bool {
        switch self {
        case .reviewDrafts, .readyToSend, .pending, .received:
            true
        case .completed, .grouped, .addTravel:
            false
        }
    }

    /// "What to do next" copy shown in place of the generic drag target when a lane has no
    /// cards, so an empty column teaches the workflow instead of just looking unfinished.
    var emptyStateMessage: String {
        switch self {
        case .completed:
            "Sessions you mark Completed in Calendar will show up here."
        case .grouped:
            "Drag Completed sessions here to prepare them for a draft invoice."
        case .addTravel:
            "Sessions with travel to review will appear here."
        case .reviewDrafts:
            "Create a draft invoice from Grouped to review it here."
        case .readyToSend:
            "Approve a draft in Review Drafts to queue it for sending."
        case .pending:
            "Send an invoice to track it here while payment is outstanding."
        case .received:
            "Mark payment received to see it here."
        }
    }

    static func invoiceColumn(for statusToken: String?) -> Self? {
        switch statusToken {
        case BillingStatus.reviewDrafts.rawValue:
            .reviewDrafts
        case BillingStatus.readyToSend.rawValue:
            .readyToSend
        case BillingStatus.pending.rawValue, "overdue":
            .pending
        case BillingStatus.received.rawValue:
            .received
        default:
            nil
        }
    }
}

extension KanbanCardData {
    var titleText: String {
        switch self {
        case .session(let data): data.title
        case .invoice(let data): data.title
        }
    }

    var subtitleText: String {
        switch self {
        case .session(let data): data.clientName
        case .invoice(let data): data.clientName
        }
    }

    var accentColor: Color {
        switch self {
        case .session(let data): data.accentColor
        case .invoice(let data): data.accentColor
        }
    }

    var detailText: String? {
        switch self {
        case .session(let data): data.date
        case .invoice(let data): data.date
        }
    }

    var statusText: String? {
        switch self {
        case .session(let data): data.duration
        case .invoice(let data): data.amount
        }
    }

    var trailingMetadataSymbol: String {
        switch self {
        case .session: "clock"
        case .invoice: "banknote"
        }
    }
}
