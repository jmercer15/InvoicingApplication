import PersistenceModels
import Foundation
import SharedUI

extension BillingHubProjectionBuilder {
    
    internal static func filterInvoices(
        _ sourceInvoices: [Invoice],
        searchText: String,
        selectedClientID: UUID?
    ) -> [Invoice] {
        var invoices = sourceInvoices

        if let selectedClientID {
            invoices = invoices.filter { $0.clientId == selectedClientID }
        }

        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            invoices = invoices.filter { invoice in
                invoice.invoiceNumber.localizedCaseInsensitiveContains(trimmedQuery) ||
                    invoice.clientName?.localizedCaseInsensitiveContains(trimmedQuery) == true
            }
        }

        return invoices
    }

    internal static func mapInvoiceToKanbanCard(_ invoice: Invoice, allSessions: [Session]) -> KanbanCardData? {
        guard let columnType = KanbanCardData.BillingColumnType.invoiceColumn(for: canonicalInvoiceStatusToken(invoice.statusToken)) else {
            return nil
        }

        let title = invoice.invoiceNumber.isEmpty ? "Draft Invoice" : "\(invoice.invoiceNumber)"
        let clientName = invoice.clientName ?? "Unknown Client"
        let serviceName: String
        if let firstSessionId = invoice.sessionIds.first,
           let firstSession = allSessions.first(where: { $0.id == firstSessionId }) {
            serviceName = firstSession.assignedServiceName ?? firstSession.title
        } else {
            serviceName = "Invoice Services"
        }
        let date = invoice.issueDate.formatted(.dateTime.day(.twoDigits).month(.twoDigits).year())
        let amount = CurrencyFormatting.display(invoice.totalAmount)
        let priority: Priority = invoice.isOverdue ? .high : .medium

        let invoiceCardData = InvoiceKanbanCardData(
            invoiceId: invoice.id,
            title: title,
            clientName: clientName,
            serviceName: serviceName,
            priority: priority,
            accentColor: columnType.laneTint,
            amount: amount,
            date: date,
            workflowStatus: columnType.workflowStatus,
            columnType: columnType,
            isOverdue: invoice.isOverdue,
            daysOverdue: invoice.daysUntilDue.flatMap { $0 < 0 ? abs($0) : nil },
            rawDate: invoice.issueDate
        )
        return .invoice(invoiceCardData)
    }

    internal static func canonicalInvoiceStatusToken(_ status: String?) -> String? {
        guard let status, ["review_draft", "ready_to_send", "pending", "received", "overdue", "cancelled", "voided"].contains(status) else { return nil }
        return status
    }
}
