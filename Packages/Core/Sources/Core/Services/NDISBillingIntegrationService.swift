import Foundation

/// Protocol consumed by feature layers while the concrete implementation lives in Data.
public protocol NDISBillingIntegrationServiceProtocol: Sendable {
    func generateNDISInvoice(for sessionIds: [UUID], clientId: UUID) async throws -> NDISBillingReport
}

public struct NDISBillingReport: Sendable {
    public let invoice: InvoiceSnapshot?
    public let processedSessionsCount: Int
    public let successfulSessionsCount: Int
    public let failedSessions: [NDISBillingIssue]

    public init(
        invoice: InvoiceSnapshot?,
        processedSessionsCount: Int,
        successfulSessionsCount: Int,
        failedSessions: [NDISBillingIssue]
    ) {
        self.invoice = invoice
        self.processedSessionsCount = processedSessionsCount
        self.successfulSessionsCount = successfulSessionsCount
        self.failedSessions = failedSessions
    }
}

public struct NDISBillingIssue: Sendable {
    public let sessionId: UUID
    public let sessionTitle: String
    public let reason: String

    public init(sessionId: UUID, sessionTitle: String, reason: String) {
        self.sessionId = sessionId
        self.sessionTitle = sessionTitle
        self.reason = reason
    }
}
