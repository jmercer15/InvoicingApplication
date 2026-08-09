import PersistenceModels

extension InvoicesContainerViewModel {
    /// List and deep-link selection only. New table-layout editor owns draft lifecycle.
    public func selectInvoice(_ invoice: Invoice) {
        requestSelectInvoice(invoice)
    }

    public func requestSelectInvoice(_ invoice: Invoice) {
        if invoice.id != selectedInvoice?.id {
            selectedInvoice = invoice
        }
        dismissActionError()
    }

    public func clearSelection() {
        requestClearSelection()
    }

    public func requestClearSelection() {
        selectedInvoice = nil
    }

    func applySelection(_ invoice: Invoice?) {
        selectedInvoice = invoice
    }
}
