import Foundation
import AppKit

// Define app-wide constants for consistent use across the application
public enum AppConstants {
    // Invoice Status Values
    public static let invoiceStatusDraft = "Draft"
    public static let invoiceStatusIssued = "Issued"
    public static let invoiceStatusPaid = "Paid"
    public static let invoiceStatusOverdue = "Overdue"
    public static let invoiceStatusCancelled = "Cancelled"
    public static let invoiceStatusOutstanding = "Outstanding"
    public static let invoiceStatusArchived = "Archived"
    public static let invoiceStatusOptions = [
        invoiceStatusDraft, invoiceStatusIssued, invoiceStatusPaid,
        invoiceStatusOverdue, invoiceStatusCancelled, invoiceStatusOutstanding, invoiceStatusArchived
    ]

    // Session Status Values
    public static let sessionStatusPlanned = "Planned"
    public static let sessionStatusConfirmed = "Confirmed"
    public static let sessionStatusCompleted = "Completed"
    public static let sessionStatusCancelled = "Cancelled"
    public static let sessionStatusNoShow = "No Show"

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

// String extensions for easy access to AppConstants and status colors
extension String {
    // MARK: - Invoice Status Constants
    static var invoiceStatusDraft: String { AppConstants.invoiceStatusDraft }
    static var invoiceStatusIssued: String { AppConstants.invoiceStatusIssued }
    static var invoiceStatusPaid: String { AppConstants.invoiceStatusPaid }
    static var invoiceStatusOverdue: String { AppConstants.invoiceStatusOverdue }
    static var invoiceStatusCancelled: String { AppConstants.invoiceStatusCancelled }
    static var invoiceStatusOutstanding: String { AppConstants.invoiceStatusOutstanding }

    // MARK: - Session Status Constants
    public static var sessionStatusPlanned: String { AppConstants.sessionStatusPlanned }
    public static var sessionStatusConfirmed: String { AppConstants.sessionStatusConfirmed }
    public static var sessionStatusCompleted: String { AppConstants.sessionStatusCompleted }
    public static var sessionStatusCancelled: String { AppConstants.sessionStatusCancelled }
    public static var sessionStatusNoShow: String { AppConstants.sessionStatusNoShow }
    static var sessionStatusPending: String { AppConstants.sessionStatusPlanned } // Alias for Planned

    // MARK: - General Status Constants
    static var statusActive: String { AppConstants.statusActive }
    static var statusInactive: String { AppConstants.statusInactive }
    static var statusArchived: String { AppConstants.statusArchived }

    // MARK: - Client Status Constants
    static var clientStatusActive: String { AppConstants.clientStatusActive }
    static var clientStatusInactive: String { AppConstants.clientStatusInactive }
    static var clientStatusOnHold: String { AppConstants.clientStatusOnHold }

    // MARK: - Status Color
    // Returns a dynamic NSColor based on the status string's content
    var statusColor: NSColor {
        switch self.lowercased() {
        // Blue statuses (Planning/Drafting)
        case "draft", "planned":
            return .systemBlue

        // Orange statuses (Pending Action/Inactive)
        case "issued", "outstanding", "inactive", "on hold":
            return .systemOrange

        // Green statuses (Completed/Active)
        case "paid", "completed", "active":
            return .systemGreen

        // Red statuses (Needs Attention/Cancelled)
        case "overdue", "cancelled", "no show":
            return .systemRed

        // Gray statuses (Archived/Historical)
        case "archived":
            return .systemGray

        // Default color for unknown statuses
        default:
            return .secondaryLabelColor
        }
    }
}

 