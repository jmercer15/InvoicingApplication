import Foundation
import AppKit

// Define app-wide constants for consistent use across the application
public enum AppConstants {
    // Invoice Status Values (matches InvoiceStatus enum in ModelEnums.swift)
    public static let invoiceStatusReviewDraft = "review_draft"
    public static let invoiceStatusReadyToSend = "ready_to_send"
    public static let invoiceStatusPending = "pending"
    public static let invoiceStatusReceived = "received"
    public static let invoiceStatusOverdue = "overdue"
    public static let invoiceStatusCancelled = "cancelled"
    public static let invoiceStatusVoided = "voided"

    public static let invoiceStatusOptions = [
        invoiceStatusReviewDraft, invoiceStatusReadyToSend, invoiceStatusPending, invoiceStatusReceived,
        invoiceStatusOverdue, invoiceStatusCancelled, invoiceStatusVoided
    ]

    public static func invoiceStatusDisplayName(for status: String?) -> String {
        switch status {
        case invoiceStatusReviewDraft: return "Review Draft"
        case invoiceStatusReadyToSend: return "Ready To Send"
        case invoiceStatusPending: return "Pending"
        case invoiceStatusReceived: return "Received"
        case invoiceStatusOverdue: return "Overdue"
        case invoiceStatusCancelled: return "Cancelled"
        case invoiceStatusVoided: return "Voided"
        default: return status ?? "Unknown"
        }
    }

    // Session Status Values
    public static let sessionStatusPlanned = "scheduled"
    public static let sessionStatusConfirmed = "scheduled"
    public static let sessionStatusCompleted = "completed"
    public static let sessionStatusCancelled = "cancelled"
    public static let sessionStatusNoShow = "no_show"

    // Client/Payee Status Values
    public static let statusActive = "Active"
    public static let statusInactive = "Inactive"
    public static let statusArchived = "Archived"

    // Add these lines:
    public static let clientStatusActive = "Active"
    public static let clientStatusInactive = "Inactive"
    public static let clientStatusOnHold = "On Hold"



    // Unit Types
    public static let unitHour = "Hour"
    public static let unitSession = "Session"
    public static let unitItem = "Item"
    public static let unitEach = "Each"
    public static let unitDay = "Day"
    public static let unitWeek = "Week"
    public static let unitMonth = "Month"
    public static let unitProject = "Project"

    public static let unitOptions = [
        unitHour, unitSession, unitItem, unitEach, unitDay, unitWeek, unitMonth, unitProject
    ]

    // Default values
    public static let defaultInvoiceDueDays = 14
} 

// String extensions for session status shims and status colors
extension String {
    // MARK: - Session Status Constants
    public static var sessionStatusPlanned: String { AppConstants.sessionStatusPlanned }
    public static var sessionStatusConfirmed: String { AppConstants.sessionStatusConfirmed }
    public static var sessionStatusCompleted: String { AppConstants.sessionStatusCompleted }
    public static var sessionStatusCancelled: String { AppConstants.sessionStatusCancelled }
    public static var sessionStatusNoShow: String { AppConstants.sessionStatusNoShow }

    // MARK: - Status Color
    // Returns a dynamic NSColor based on the status string's content
    var statusColor: NSColor {
        switch self {
        // Gray statuses (Draft/Planning)
        case AppConstants.invoiceStatusReviewDraft:
            return .systemGray

        // Yellow statuses (Ready for action)
        case AppConstants.invoiceStatusReadyToSend:
            return .systemYellow

        // Blue statuses (Pending/In Progress)
        case AppConstants.invoiceStatusPending, AppConstants.sessionStatusPlanned:
            return .systemBlue

        // Orange statuses (Pending Action/Inactive)
        case "Inactive", "On Hold", "needs_travel":
            return .systemOrange

        // Green statuses (Completed/Received/Active)
        case AppConstants.invoiceStatusReceived, "Active", AppConstants.sessionStatusCompleted:
            return .systemGreen

        // Red statuses (Needs Attention)
        case AppConstants.invoiceStatusOverdue, AppConstants.invoiceStatusCancelled, AppConstants.sessionStatusNoShow, AppConstants.sessionStatusCancelled:
            return .systemRed

        // Purple statuses (Voided/Special)
        case AppConstants.invoiceStatusVoided:
            return .systemPurple

        // Default color for unknown statuses
        default:
            return .secondaryLabelColor
        }
    }
}

 
