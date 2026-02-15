//
//  BillingTransitionRules.swift
//  Core
//
//  Centralized transition rules for billing workflow status changes.
//
//  ## Session Workflow
//  Sessions flow through preparing columns before becoming invoices:
//  `Completed` ↔ `Grouped` ↔ `Add Travel`
//
//  ## Invoice Workflow
//  Invoices flow through processing and payment columns:
//  `Review Drafts` → `Ready to Send` → `Pending` → `Received`
//  (backward transitions are allowed one step at a time)
//

import Foundation

/// Defines valid transitions between billing statuses for sessions and invoices.
/// Use this enum to validate user-initiated status changes before persisting them.
public enum BillingTransitionRules {
    
    // MARK: - Session Transitions
    
    /// Valid transitions for session billing statuses.
    /// Sessions can move freely between preparing columns.
    private static let validSessionTransitions: [BillingStatus: Set<BillingStatus>] = [
        .completed: [.grouped, .addTravel],
        .grouped: [.completed, .addTravel],
        .addTravel: [.grouped, .completed]
    ]
    
    /// Check if a session transition is valid
    /// - Parameters:
    ///   - source: The current status
    ///   - destination: The target status
    /// - Returns: `true` if the transition is allowed
    public static func isValidSessionTransition(from source: BillingStatus, to destination: BillingStatus) -> Bool {
        // Same status is always valid (no-op)
        if source == destination { return true }
        return validSessionTransitions[source]?.contains(destination) ?? false
    }
    
    /// Get allowed next statuses for a session
    /// - Parameter status: The current session status
    /// - Returns: Array of valid destination statuses
    public static func allowedNextStates(forSession status: BillingStatus) -> [BillingStatus] {
        Array(validSessionTransitions[status] ?? [])
    }
    
    // MARK: - Invoice Transitions
    
    /// Invoice workflow order (left to right = forward progression)
    private static let invoiceWorkflowOrder: [BillingStatus] = [
        .reviewDrafts, .readyToSend, .pending, .received
    ]
    
    /// Valid transitions for invoice billing statuses.
    /// Invoices can move forward or backward one step at a time.
    /// Note: "overdue" is treated as equivalent to "pending" for transition purposes.
    private static let validInvoiceTransitions: [BillingStatus: Set<BillingStatus>] = [
        .reviewDrafts: [.readyToSend],
        .readyToSend: [.reviewDrafts, .pending],
        .pending: [.readyToSend, .received],
        .received: [.pending]
    ]
    
    /// Check if an invoice transition is valid
    /// - Parameters:
    ///   - source: The current status
    ///   - destination: The target status
    /// - Returns: `true` if the transition is allowed
    public static func isValidInvoiceTransition(from source: BillingStatus, to destination: BillingStatus) -> Bool {
        // Same status is always valid (no-op)
        if source == destination { return true }
        return validInvoiceTransitions[source]?.contains(destination) ?? false
    }
    
    /// Check if an invoice transition is valid using raw status strings.
    /// Handles special cases like "overdue" which maps to "pending".
    public static func isValidInvoiceTransition(fromRaw source: String, toRaw destination: String) -> Bool {
        guard let sourceStatus = normalizeInvoiceStatus(source),
              let destStatus = normalizeInvoiceStatus(destination) else {
            return false
        }
        return isValidInvoiceTransition(from: sourceStatus, to: destStatus)
    }
    
    /// Check if an invoice transition is moving backward in the workflow
    /// - Parameters:
    ///   - source: The current status
    ///   - destination: The target status
    /// - Returns: `true` if moving toward earlier stages (e.g., Pending → Ready to Send)
    public static func isBackwardInvoiceTransition(from source: BillingStatus, to destination: BillingStatus) -> Bool {
        guard let sourceIndex = invoiceWorkflowOrder.firstIndex(of: source),
              let destIndex = invoiceWorkflowOrder.firstIndex(of: destination) else {
            return false
        }
        return destIndex < sourceIndex
    }
    
    /// Get allowed next statuses for an invoice
    /// - Parameter status: The current invoice status
    /// - Returns: Array of valid destination statuses
    public static func allowedNextStates(forInvoice status: BillingStatus) -> [BillingStatus] {
        Array(validInvoiceTransitions[status] ?? [])
    }
    
    // MARK: - Helpers
    
    /// Normalize raw status string to BillingStatus for invoices.
    /// Handles special cases like "overdue" → .pending
    private static func normalizeInvoiceStatus(_ raw: String) -> BillingStatus? {
        if raw == "overdue" {
            return .pending
        }
        return BillingStatus(rawValue: raw)
    }
    
    /// Determines if moving an invoice to a destination requires clearing sent/paid dates.
    /// Used for backward transitions in the workflow.
    /// - Parameter destination: The target status
    /// - Returns: Tuple indicating which dates should be cleared
    public static func requiresDateClearing(to destination: BillingStatus) -> (clearSentDate: Bool, clearPaidDate: Bool) {
        switch destination {
        case .reviewDrafts:
            return (clearSentDate: true, clearPaidDate: true)
        case .readyToSend:
            return (clearSentDate: true, clearPaidDate: true)
        case .pending:
            return (clearSentDate: false, clearPaidDate: true)
        case .received:
            return (clearSentDate: false, clearPaidDate: false)
        default:
            return (clearSentDate: false, clearPaidDate: false)
        }
    }
}
