import Foundation

// MARK: - Compliance Issue

/// A single issue discovered during compliance validation.
public struct ComplianceIssue: Sendable, Equatable, Hashable {
    public enum Severity: String, Sendable {
        case warning
        case blocker
    }

    public let id: String
    public let severity: Severity
    public let message: String
    public let entityID: UUID?
    public let field: String?

    public init(id: String, severity: Severity, message: String, entityID: UUID? = nil, field: String? = nil) {
        self.id = id
        self.severity = severity
        self.message = message
        self.entityID = entityID
        self.field = field
    }
}

// MARK: - Compliance Validation Result

/// The result of a compliance validation pass, containing any warnings and blockers.
public struct ComplianceValidationResult: Sendable {
    public let warnings: [ComplianceIssue]
    public let blockers: [ComplianceIssue]

    public init(warnings: [ComplianceIssue] = [], blockers: [ComplianceIssue] = []) {
        self.warnings = warnings
        self.blockers = blockers
    }

    public var isBlocked: Bool { !blockers.isEmpty }
}

// MARK: - Compliance Action

/// Actions that can trigger compliance validation.
public enum ComplianceAction: String, Sendable {
    case approveDraft
    case sendInvoice
    case exportInvoice
    case markPaid
    case statusChange
    case bulkSendReady
    case bulkCompletePending
}

// MARK: - Compliance Validating Protocol

/// Protocol for NDIS compliance validation.
/// Defined in Core to allow feature packages to depend on abstractions
/// rather than concrete implementations in the Data layer.
public protocol ComplianceValidating: Sendable {
    func validateInvoiceTransition(
        invoiceId: UUID,
        action: ComplianceAction,
        targetStatus: String?
    ) async throws -> ComplianceValidationResult

    func validateBulkInvoices(
        invoiceIds: [UUID],
        action: ComplianceAction
    ) async throws -> [UUID: ComplianceValidationResult]

    func validateSessionForInvoicing(
        sessionId: UUID
    ) async throws -> ComplianceValidationResult

    /// Snapshot-based validation for PDF export/share/print without requiring a persisted invoice fetch.
    func validateInvoiceForExport(
        invoice: InvoiceSnapshot,
        items: [InvoiceItemSnapshot],
        business: BusinessSnapshot?,
        strict: Bool
    ) -> ComplianceValidationResult
}

// MARK: - Default Parameter Values

public extension ComplianceValidating {
    /// Convenience overload providing a default `nil` targetStatus.
    func validateInvoiceTransition(
        invoiceId: UUID,
        action: ComplianceAction
    ) async throws -> ComplianceValidationResult {
        try await validateInvoiceTransition(invoiceId: invoiceId, action: action, targetStatus: nil)
    }

    func validateInvoiceForExport(
        invoice: InvoiceSnapshot,
        items: [InvoiceItemSnapshot],
        business: BusinessSnapshot?,
        strict: Bool = true
    ) -> ComplianceValidationResult {
        _ = invoice
        _ = items
        _ = business
        _ = strict
        return ComplianceValidationResult()
    }
}
