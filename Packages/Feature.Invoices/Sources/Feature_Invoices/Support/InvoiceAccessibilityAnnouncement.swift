//
//  InvoiceAccessibilityAnnouncement.swift
//  Feature_Invoices
//
//  Created by Jesse Mercer on 24/7/2026.
//

import Foundation
import Accessibility
import SwiftUI

public enum InvoiceAccessibilityAnnouncement: Equatable, Sendable {
    public static func filterChanged(filteredCount: Int, totalCount: Int) -> String {
        let noun = filteredCount == 1 ? "invoice" : "invoices"
        return "Filtered to \(filteredCount) \(noun)"
    }

    public static func filtersCleared(totalCount: Int) -> String {
        let noun = totalCount == 1 ? "invoice" : "invoices"
        return "Filters cleared, showing \(totalCount) \(noun)"
    }

    static func emptyState(state: InvoicesListEmptyState) -> String {
        switch state {
        case .noInvoices:
            return "No invoices yet"
        case .noMatches:
            return "No matching invoices"
        case .needsRefresh:
            return "Invoices need refresh"
        case .content:
            return ""
        }
    }

    public static func selectionChanged(selectedCount: Int) -> String {
        if selectedCount == 0 {
            return "Selection cleared"
        }
        let noun = selectedCount == 1 ? "invoice" : "invoices"
        return "\(selectedCount) \(noun) selected"
    }

    public static func actionFailed(_ detail: String) -> String {
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Invoice action failed" }
        return "Invoice action failed. \(trimmed)"
    }

    public static func refreshFailed(_ detail: String) -> String {
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Invoices couldn't refresh" }
        return "Invoices couldn't refresh. \(trimmed)"
    }

    @MainActor
    public static func announce(_ message: String) {
        guard !message.isEmpty else { return }
        AccessibilityNotification.Announcement(message).post()
    }
}
