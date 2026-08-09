import Core
import PersistenceModels
import Foundation
import SwiftData

extension BillingHubViewModel: BillingHubInvoiceCoordinatorHost {}

extension BillingHubViewModel {
    @discardableResult
    public func moveInvoice(_ id: UUID, to column: KanbanCardData.BillingColumnType) async -> MoveResult? {
        await invoiceCoordinator.moveInvoice(id, to: column)
    }

    public func createDraftInvoicesForGroupedSessions(from projection: BillingHubBoardProjection) async {
        await invoiceCoordinator.createDraftInvoicesForGroupedSessions(from: projection)
    }

    public func createDraftInvoice(fromGroupID groupID: UUID) async -> DraftInvoiceCreationOutcome? {
        await invoiceCoordinator.createDraftInvoice(fromGroupID: groupID)
    }

    @discardableResult
    public func createInvoiceFromSessions(_ sessionIDs: [UUID]) async -> DraftInvoiceCreationOutcome? {
        await invoiceCoordinator.createInvoiceFromSessions(sessionIDs)
    }

    public func markReadyToSendInvoicesSent(from projection: BillingHubBoardProjection) async {
        await invoiceCoordinator.markReadyToSendInvoicesSent(from: projection)
    }

    public func completeAllPendingInvoices(from projection: BillingHubBoardProjection) async {
        await invoiceCoordinator.completeAllPendingInvoices(from: projection)
    }

    @discardableResult
    public func updateInvoiceDetails(id: UUID, clientName: String) async -> Bool {
        await invoiceCoordinator.updateInvoiceDetails(id: id, clientName: clientName)
    }

    public func fetchComplianceChecklist(for id: UUID) async throws -> Core.ComplianceValidationResult? {
        try await invoiceCoordinator.fetchComplianceChecklist(for: id)
    }

    @discardableResult
    public func approveDraftInvoice(id: UUID, dueDate: Date) async -> Bool {
        await invoiceCoordinator.approveDraftInvoice(id: id, dueDate: dueDate)
    }

    @discardableResult
    public func requestChanges(for id: UUID, reason: String) async -> Bool {
        await invoiceCoordinator.requestChanges(for: id, reason: reason)
    }

    public func invoice(byId id: UUID) async -> Invoice? {
        await invoiceCoordinator.invoice(byId: id)
    }

    public func updateInvoiceStatus(_ id: UUID, to column: KanbanCardData.BillingColumnType) async {
        await invoiceCoordinator.updateInvoiceStatus(id, to: column)
    }

    @discardableResult
    public func markInvoiceSentManually(id: UUID) async -> Bool {
        await invoiceCoordinator.markInvoiceSentManually(id: id)
    }

    @discardableResult
    public func sendInvoice(
        id: UUID,
        recipients: String,
        cc: String,
        subject: String,
        message: String,
        attachPDF: Bool,
        sendCopyToSelf: Bool
    ) async -> Bool {
        await invoiceCoordinator.sendInvoice(
            id: id,
            recipients: recipients,
            cc: cc,
            subject: subject,
            message: message,
            attachPDF: attachPDF,
            sendCopyToSelf: sendCopyToSelf
        )
    }

    func sendInvoiceWithOutcome(
        id: UUID,
        recipients: String,
        additionalRecipients: String,
        subject: String,
        message: String,
        attachPDF: Bool,
        sendCopyToSelf: Bool
    ) async -> BillingHubInvoiceSendOutcome {
        await invoiceCoordinator.sendInvoiceWithOutcome(
            id: id,
            recipients: recipients,
            additionalRecipients: additionalRecipients,
            subject: subject,
            message: message,
            attachPDF: attachPDF,
            sendCopyToSelf: sendCopyToSelf
        )
    }

    public func sendTestInvoice(
        id: UUID,
        recipients: String,
        cc: String,
        subject: String,
        message: String,
        attachPDF: Bool
    ) async {
        await invoiceCoordinator.sendTestInvoice(
            id: id,
            recipients: recipients,
            cc: cc,
            subject: subject,
            message: message,
            attachPDF: attachPDF
        )
    }

    public func moveInvoiceBackToDraftReview(id: UUID) async -> Bool {
        await invoiceCoordinator.moveInvoiceBackToDraftReview(id: id)
    }

    @discardableResult
    public func finalizePayment(id: UUID, amount: String, date: Date, method: String, reference: String) async -> Bool {
        await invoiceCoordinator.finalizePayment(
            id: id,
            amount: amount,
            date: date,
            method: method,
            reference: reference
        )
    }

    @discardableResult
    public func savePaymentDraft(id: UUID, amount: String, date: Date, method: String, reference: String) async -> Bool {
        await invoiceCoordinator.savePaymentDraft(
            id: id,
            amount: amount,
            date: date,
            method: method,
            reference: reference
        )
    }

    @discardableResult
    public func markInvoiceOverdue(id: UUID) async -> Bool {
        await invoiceCoordinator.markInvoiceOverdue(id: id)
    }

    @discardableResult
    public func moveInvoiceBackToReadyToSend(id: UUID) async -> Bool {
        await invoiceCoordinator.moveInvoiceBackToReadyToSend(id: id)
    }

    @discardableResult
    public func reopenInvoiceAsPending(id: UUID) async -> Bool {
        await invoiceCoordinator.reopenInvoiceAsPending(id: id)
    }

    func sendReceiptWithOutcome(
        id: UUID,
        recipientEmail: String,
        includePDF: Bool
    ) async -> BillingHubReceiptSendOutcome {
        await invoiceCoordinator.sendReceiptWithOutcome(
            id: id,
            recipientEmail: recipientEmail,
            includePDF: includePDF
        )
    }

    @discardableResult
    public func sendReceipt(id: UUID, recipientEmail: String, includePDF: Bool) async -> Bool {
        await invoiceCoordinator.sendReceipt(id: id, recipientEmail: recipientEmail, includePDF: includePDF)
    }

    func exportReceiptPDFWithOutcome(id: UUID) async -> BillingHubReceiptExportOutcome {
        await invoiceCoordinator.exportReceiptPDFWithOutcome(id: id)
    }

    public func exportReceiptPDF(id: UUID) async -> URL? {
        await invoiceCoordinator.exportReceiptPDF(id: id)
    }
}
