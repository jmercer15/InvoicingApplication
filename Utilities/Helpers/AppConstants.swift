import Foundation
import AppKit

// Define app-wide constants for consistent use across the application
enum AppConstants {
    // Invoice Status Values
    static let invoiceStatusDraft = "Draft"
    static let invoiceStatusIssued = "Issued"
    static let invoiceStatusPaid = "Paid"
    static let invoiceStatusOverdue = "Overdue"
    static let invoiceStatusCancelled = "Cancelled"
    static let invoiceStatusOutstanding = "Outstanding"
    static let invoiceStatusArchived = "Archived"
    static let invoiceStatusOptions = [
        invoiceStatusDraft, invoiceStatusIssued, invoiceStatusPaid,
        invoiceStatusOverdue, invoiceStatusCancelled, invoiceStatusOutstanding, invoiceStatusArchived
    ]
    
    // Session Status Values
    static let sessionStatusPlanned = "Planned"
    static let sessionStatusConfirmed = "Confirmed"
    static let sessionStatusCompleted = "Completed" 
    static let sessionStatusCancelled = "Cancelled"
    static let sessionStatusNoShow = "No Show"
    
    // Client/Payee Status Values
    static let statusActive = "Active"
    static let statusInactive = "Inactive"
    static let statusArchived = "Archived"
    
    // Add these lines:
    static let clientStatusActive = "Active"
    static let clientStatusInactive = "Inactive"
    static let clientStatusOnHold = "On Hold"
    
    // Dashboard
    static let dashboardRanges = ["Week", "Month", "Quarter", "Year", "All Time"]
    
    // Unit Types
    static let unitHour = "Hour"
    static let unitSession = "Session"
    static let unitItem = "Item"
    static let unitEach = "Each"
    static let unitDay = "Day"
    static let unitWeek = "Week"
    static let unitMonth = "Month"
    static let unitProject = "Project"

    static let unitOptions = [
        unitHour, unitSession, unitItem, unitEach, unitDay, unitWeek, unitMonth, unitProject
    ]
    
    // Default values
    static let defaultInvoiceDueDays = 14
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
    static var sessionStatusPlanned: String { AppConstants.sessionStatusPlanned }
    static var sessionStatusConfirmed: String { AppConstants.sessionStatusConfirmed }
    static var sessionStatusCompleted: String { AppConstants.sessionStatusCompleted }
    static var sessionStatusCancelled: String { AppConstants.sessionStatusCancelled }
    static var sessionStatusNoShow: String { AppConstants.sessionStatusNoShow }
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

// Array extension for dashboard ranges
extension Array where Element == String {
    static var dashboardRanges: [String] { AppConstants.dashboardRanges }
} 