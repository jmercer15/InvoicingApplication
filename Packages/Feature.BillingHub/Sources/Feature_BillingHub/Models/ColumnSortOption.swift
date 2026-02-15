//
//  ColumnSortOption.swift
//  Feature.BillingHub
//
//  Sorting options for Kanban columns.
//

import Foundation

/// Available sorting options for Kanban columns
public enum ColumnSortOption: String, CaseIterable, Codable {
    /// User-defined manual order (default)
    case manual
    /// Oldest first by date
    case dateAsc
    /// Newest first by date
    case dateDesc
    /// Alphabetical by client name
    case clientName
    /// Lowest amount first (invoices only)
    case amountAsc
    /// Highest amount first (invoices only)
    case amountDesc
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .dateAsc: return "Date (Oldest)"
        case .dateDesc: return "Date (Newest)"
        case .clientName: return "Client Name"
        case .amountAsc: return "Amount (Low)"
        case .amountDesc: return "Amount (High)"
        }
    }
    
    /// Icon for sort menu
    var icon: String {
        switch self {
        case .manual: return "hand.draw"
        case .dateAsc: return "calendar.badge.clock"
        case .dateDesc: return "calendar.badge.clock"
        case .clientName: return "person.text.rectangle"
        case .amountAsc: return "dollarsign.arrow.trianglehead.counterclockwise.rotate.90"
        case .amountDesc: return "dollarsign.arrow.trianglehead.counterclockwise.rotate.90"
        }
    }
    
    /// Whether this option is applicable to invoice columns
    var applicableToInvoices: Bool {
        true
    }
    
    /// Whether this option is applicable to session columns
    var applicableToSessions: Bool {
        switch self {
        case .amountAsc, .amountDesc:
            return false
        default:
            return true
        }
    }
}
