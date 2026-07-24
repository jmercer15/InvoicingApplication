import Core
import Data
import Foundation
import SwiftData

extension BillingHubViewModel {
    
    public func moveInvoice(_ id: UUID, to column: KanbanCardData.BillingColumnType) async {
        guard let modelID = await invoiceModelID(for: id) else { return }
        do {
            let result = try await workflow.moveInvoice(modelID: modelID, to: column, complianceValidator: complianceValidator)
            switch result {
            case .successWithComplianceWarnings:
                bulkActionFeedback = "Compliance warnings: review details before the next step."
            case .blocked(let message):
                bulkActionFeedback = message
            default:
                break
            }
        } catch {
            print("❌ [BillingHubViewModel] Invoice move error: \(error)")
        }
    }
    
    public func createDraftInvoicesForGroupedSessions(from projection: BillingHubBoardProjection) async {
        let groups = projection.groupedSessions
        guard !groups.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        
        var created = 0
        for group in groups {
            guard let clientId = await clientIdForFirstSession(in: group) else { continue }
            let sessionReferences = await sessionReferences(for: group.sessions.map(\.id))
            guard !sessionReferences.isEmpty else { continue }
            do {
                let report = try await workflow.createDraftInvoices(
                    sessions: sessionReferences,
                    clientID: clientId,
                    ndisService: ndisBillingIntegrationService
                )
                if report.invoice != nil { created += 1 }
            } catch {
                print("❌ [BillingHubViewModel] Draft creation error: \(error)")
            }
        }
        
        if created > 0 {
            bulkActionFeedback = "Created \(created) draft invoices."
        }
    }

    public func sendAllReadyToSendInvoices(from projection: BillingHubBoardProjection) async {
        let invoices = projection.invoicesByStatus[.readyToSend] ?? []
        guard !invoices.isEmpty else { return }

        let ids = invoices.map(\.id)
        do {
            if let validator = complianceValidator {
                let results = try await validator.validateBulkInvoices(invoiceIds: ids, action: .bulkSendReady)
                let allowed = ids.filter { !(results[$0]?.isBlocked ?? true) }
                var blockedCount = ids.count - allowed.count
                var allowedModelIDs: [PersistentIdentifier] = []
                for invoiceId in allowed {
                    if let mid = await invoiceModelID(for: invoiceId) { allowedModelIDs.append(mid) }
                }
                blockedCount += allowed.count - allowedModelIDs.count
                let processedCount: Int
                if allowedModelIDs.isEmpty {
                    processedCount = 0
                } else {
                    processedCount = try await workflow.bulkUpdateInvoices(modelIDs: allowedModelIDs, targetStatus: .pending) { invoice in
                        invoice.sentDate = Date()
                    }
                }
                if processedCount > 0 || blockedCount > 0 {
                    bulkActionFeedback = "Processed \(processedCount), blocked \(blockedCount)."
                }
            } else {
                var modelIDs: [PersistentIdentifier] = []
                for invoiceId in ids {
                    if let mid = await invoiceModelID(for: invoiceId) { modelIDs.append(mid) }
                }
                let count = try await workflow.bulkUpdateInvoices(modelIDs: modelIDs, targetStatus: .pending) { invoice in
                    invoice.sentDate = Date()
                }
                if count > 0 {
                    bulkActionFeedback = "Sent \(count) invoices."
                }
            }
        } catch {
            print("❌ [BillingHubViewModel] Bulk send error: \(error)")
        }
    }

    public func completeAllPendingInvoices(from projection: BillingHubBoardProjection) async {
        let invoices = projection.invoicesByStatus[.pending] ?? []
        guard !invoices.isEmpty else { return }

        let ids = invoices.map(\.id)
        do {
            if let validator = complianceValidator {
                let results = try await validator.validateBulkInvoices(invoiceIds: ids, action: .bulkCompletePending)
                let allowed = ids.filter { !(results[$0]?.isBlocked ?? true) }
                var blockedCount = ids.count - allowed.count
                var allowedModelIDs: [PersistentIdentifier] = []
                for invoiceId in allowed {
                    if let mid = await invoiceModelID(for: invoiceId) { allowedModelIDs.append(mid) }
                }
                blockedCount += allowed.count - allowedModelIDs.count
                let processedCount: Int
                if allowedModelIDs.isEmpty {
                    processedCount = 0
                } else {
                    processedCount = try await workflow.bulkUpdateInvoices(modelIDs: allowedModelIDs, targetStatus: .received) { invoice in
                        if invoice.paidDate == nil { invoice.paidDate = Date() }
                    }
                }
                if processedCount > 0 || blockedCount > 0 {
                    bulkActionFeedback = "Processed \(processedCount), blocked \(blockedCount)."
                }
            } else {
                var modelIDs: [PersistentIdentifier] = []
                for invoiceId in ids {
                    if let mid = await invoiceModelID(for: invoiceId) { modelIDs.append(mid) }
                }
                let count = try await workflow.bulkUpdateInvoices(modelIDs: modelIDs, targetStatus: .received) { invoice in
                    if invoice.paidDate == nil { invoice.paidDate = Date() }
                }
                if count > 0 {
                    bulkActionFeedback = "Completed \(count) invoices."
                }
            }
        } catch {
            print("❌ [BillingHubViewModel] Bulk complete error: \(error)")
        }
    }

    public func updateInvoiceDetails(id: UUID, clientName: String) async {
        guard let modelID = await invoiceModelID(for: id) else { return }
        do {
            try await workflow.updateInvoiceDetails(modelID: modelID, clientName: clientName)
        } catch { print("❌ Update invoice details error: \(error)") }
    }

    public func fetchComplianceChecklist(for id: UUID) async -> Core.ComplianceValidationResult? {
        return try? await complianceValidator?.validateInvoiceTransition(invoiceId: id, action: .approveDraft)
    }

    public func createDraftInvoice(fromGroupID groupID: UUID) async {
        let sessionReferences: [SessionWorkflowReference]
        do {
            sessionReferences = try await workflow.sessionWorkflowReferencesForGroup(groupID: groupID)
        } catch {
            return
        }
        let sessionIDs = sessionReferences.map(\.sessionID)
        guard !sessionIDs.isEmpty else { return }
        await createInvoiceFromSessions(sessionIDs)
    }

    public func createInvoiceFromSessions(_ sessionIDs: [UUID]) async {
        guard let firstID = sessionIDs.first,
              let clientID = try? await workflow.clientIdForSession(id: firstID) else { return }
        let sessionReferences = await sessionReferences(for: sessionIDs)
        guard !sessionReferences.isEmpty else { return }
        do {
            let report = try await workflow.createDraftInvoices(
                sessions: sessionReferences,
                clientID: clientID,
                ndisService: ndisBillingIntegrationService
            )
            _ = report.invoice
        } catch { print("❌ Create invoice error: \(error)") }
    }

    public func approveDraftInvoice(id: UUID, dueDate _: Date) async {
        await moveInvoice(id, to: .readyToSend)
    }

    public func requestChanges(for id: UUID) async {
        await moveInvoice(id, to: .reviewDrafts)
    }

    public func invoice(byId id: UUID) async -> Invoice? {
        fetchInvoiceOnMainContext(by: id)
    }

    public func updateInvoiceStatus(_ id: UUID, to column: KanbanCardData.BillingColumnType) async {
        await moveInvoice(id, to: column)
    }

    public func sendInvoice(id: UUID, recipients _: String, subject _: String, message _: String) async {
        await moveInvoice(id, to: .pending)
    }

    public func sendTestInvoice(id _: UUID, recipients _: String, subject _: String, message _: String) async {
    }

    public func moveInvoiceBackToDraftReview(id: UUID) async {
        await moveInvoice(id, to: .reviewDrafts)
    }

    public func finalizePayment(id: UUID, amount _: String, date _: Date, method _: String, reference _: String) async {
        await moveInvoice(id, to: .received)
    }

    public func savePaymentDraft(id _: UUID, amount _: String, date _: Date, method _: String, reference _: String) async {
    }

    public func markInvoiceOverdue(id _: UUID) async {
    }

    public func moveInvoiceBackToReadyToSend(id: UUID) async {
        await moveInvoice(id, to: .readyToSend)
    }

    public func reopenInvoiceAsPending(id: UUID) async {
        await moveInvoice(id, to: .pending)
    }

    public func sendReceipt(id _: UUID, recipientEmail _: String, includePDF _: Bool) async {
    }

    public func exportReceiptPDF(id _: UUID) async -> URL? {
        return nil
    }
}
