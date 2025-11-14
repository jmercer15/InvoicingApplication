import SwiftUI
import Combine
import PDFKit
import AppKit
import UniformTypeIdentifiers
import Core
import SharedUI

@MainActor
class InvoiceEditorViewModel: ObservableObject {
    private let invoicesRepository: InvoicesRepository
    let clientServicesRepository: ClientServicesRepository
    private let clientsRepository: ClientsRepository
    
    // Store the domain model and create mutable state for editing
    @Published private(set) var invoice: Invoice
    @Published var invoiceItems: [InvoiceItem] = []
    
    // Mutable properties for two-way binding (since domain model is immutable)
    @Published var discount: Double = 0.0
    @Published var taxRate: Double = 0.0
    @Published var creditApplied: Double = 0.0
    @Published var invoiceNumber: String = ""
    @Published var issueDate: Date = Date()
    @Published var dueDate: Date?
    @Published var paymentTerms: String?
    @Published var notes: String?
    @Published var currencyCode: String = "AUD"
    @Published var status: String?
    
    // Client selection properties
    @Published var selectedClientId: UUID? {
        didSet {
            Task { await fetchSelectedClient() }
        }
    }
    @Published var selectedClient: Client?
    @Published var allClients: [Client] = []
    
    let isNewInvoice: Bool
    private var emailSharingService: NSSharingService?
    private var emailSharingDelegate: EmailSharingDelegate?

    // Callback for when invoice is deleted
    var onInvoiceDeleted: (() -> Void)?

    init(invoicesRepository: InvoicesRepository, clientServicesRepository: ClientServicesRepository, clientsRepository: ClientsRepository, invoice existingInvoice: Invoice, isNew: Bool) {
        self.invoicesRepository = invoicesRepository
        self.clientServicesRepository = clientServicesRepository
        self.clientsRepository = clientsRepository
        self.isNewInvoice = isNew
        self.invoice = existingInvoice
        self.onInvoiceDeleted = nil
        self.selectedClientId = existingInvoice.clientId
        
        // Initialize mutable properties from domain model
        self.discount = existingInvoice.discount
        self.taxRate = existingInvoice.taxRate
        self.creditApplied = existingInvoice.creditApplied
        self.invoiceNumber = existingInvoice.invoiceNumber
        self.issueDate = existingInvoice.issueDate
        self.dueDate = existingInvoice.dueDate
        self.paymentTerms = existingInvoice.paymentTerms
        self.notes = existingInvoice.notes
        self.currencyCode = existingInvoice.currencyCode.isEmpty ? "AUD" : existingInvoice.currencyCode
        self.status = existingInvoice.status
        
        // Load invoice items and clients
        Task {
            await loadInvoiceItems()
            await fetchAllClients()
            await fetchSelectedClient()
        }
    }
    
    private func loadInvoiceItems() async {
        do {
            invoiceItems = try await invoicesRepository.fetchItems(by: invoice.id)
        } catch {
            print("❌ [InvoiceEditorViewModel] Error loading invoice items: \(error)")
            invoiceItems = []
        }
    }

    // MARK: - Computed Properties for Totals
    
    var subtotal: Double {
        invoiceItems.reduce(0.0) { $0 + $1.lineTotal }
    }
    
    var discountAmount: Double {
        subtotal * (discount / 100.0)
    }
    
    var taxAmount: Double {
        let taxableSubtotalAfterDiscount = subtotal * (1.0 - (discount / 100.0))
        return taxableSubtotalAfterDiscount * (taxRate / 100.0)
    }
    
    var calculatedTotal: Double {
        subtotal - discountAmount + taxAmount - creditApplied
    }
    
    // MARK: - Totals Recalculation (exposed for UI change hooks)
    func recomputeTotals() {
        updateInvoiceCalculatedFields()
    }
    
    // MARK: - Line Item Management
    func addNewInvoiceItem() {
        let newItem = InvoiceItem(
            id: UUID(),
            invoiceId: invoice.id,
            itemDescription: "New Service/Item",
            quantity: 1.0,
            rate: 0.0,
            position: Int32(invoiceItems.count)
        )
        invoiceItems.append(newItem)
    }

    func deleteInvoiceItems(at offsets: IndexSet) {
        let indices = offsets.sorted(by: >)
        for index in indices {
            guard index < invoiceItems.count else { continue }
            let item = invoiceItems[index]
            Task {
                do {
                    try await invoicesRepository.removeItem(id: item.id)
                    await loadInvoiceItems()
                } catch {
                    print("❌ [InvoiceEditorViewModel] Error deleting item: \(error)")
                }
            }
        }
        
        // Remove from local array immediately for UI responsiveness
        invoiceItems.remove(atOffsets: offsets)
        
        // Reposition remaining items
        for (index, item) in invoiceItems.enumerated() {
            let updatedItem = InvoiceItem(
                id: item.id,
                invoiceId: item.invoiceId,
                sessionId: item.sessionId,
                clientServiceId: item.clientServiceId,
                itemDescription: item.itemDescription,
                quantity: item.quantity,
                rate: item.rate,
                position: Int32(index)
            )
            invoiceItems[index] = updatedItem
            Task {
                try? await invoicesRepository.updateItem(updatedItem)
            }
        }
    }
    
    func moveInvoiceItem(from source: IndexSet, to destination: Int) {
        invoiceItems.move(fromOffsets: source, toOffset: destination)
        
        // Update positions via repository
        for (index, item) in invoiceItems.enumerated() {
            let updatedItem = InvoiceItem(
                id: item.id,
                invoiceId: item.invoiceId,
                sessionId: item.sessionId,
                clientServiceId: item.clientServiceId,
                itemDescription: item.itemDescription,
                quantity: item.quantity,
                rate: item.rate,
                position: Int32(index)
            )
            invoiceItems[index] = updatedItem
            Task {
                try? await invoicesRepository.updateItem(updatedItem)
            }
        }
    }
    
    func updateInvoiceItem(_ item: InvoiceItem, description: String? = nil, quantity: Double? = nil, rate: Double? = nil, clientServiceId: UUID? = nil) {
        guard let index = invoiceItems.firstIndex(where: { $0.id == item.id }) else { return }
        
        let updatedItem = InvoiceItem(
            id: item.id,
            invoiceId: item.invoiceId,
            sessionId: item.sessionId,
            clientServiceId: clientServiceId ?? item.clientServiceId,
            itemDescription: description ?? item.itemDescription,
            quantity: quantity ?? item.quantity,
            rate: rate ?? item.rate,
            position: item.position
        )
        
        invoiceItems[index] = updatedItem
        
        Task {
            do {
                try await invoicesRepository.updateItem(updatedItem)
                await loadInvoiceItems() // Reload to ensure consistency
            } catch {
                print("❌ [InvoiceEditorViewModel] Error updating item: \(error)")
            }
        }
    }

    // MARK: - Client Management
    func fetchAllClients() async {
        do {
            allClients = try await clientsRepository.fetchAll()
        } catch {
            print("❌ [InvoiceEditorViewModel] Error fetching clients: \(error)")
            allClients = []
        }
    }
    
    func fetchSelectedClient() async {
        guard let clientId = selectedClientId else {
            selectedClient = nil
            return
        }
        do {
            selectedClient = try await clientsRepository.fetch(by: clientId)
        } catch {
            print("❌ [InvoiceEditorViewModel] Error fetching selected client: \(error)")
            selectedClient = nil
        }
    }
    
    func applyMaxClientCredit() {
        guard let client = selectedClient else { return }
        creditApplied = min(client.creditAmount, calculatedTotal)
    }
    
    // MARK: - Client Change Handling
    func onClientChanged(to clientId: UUID?) {
        // Update selected client ID
        selectedClientId = clientId
        
        // Generate invoice number when client is selected for new invoices
        if isNewInvoice && invoiceNumber.isEmpty {
            Task {
                do {
                    invoiceNumber = try await invoicesRepository.generateInvoiceNumber()
                } catch {
                    print("❌ [InvoiceEditorViewModel] Error generating invoice number: \(error)")
                }
            }
        }
    }

    // MARK: - Invoice Number Generation
    func generateNextInvoiceNumber() async -> String {
        do {
            return try await invoicesRepository.generateInvoiceNumber()
        } catch {
            print("❌ [InvoiceEditorViewModel] Error generating invoice number: \(error)")
            return ""
        }
    }

    // MARK: - Save and Cancel
    func saveInvoice(completion: @escaping (Bool, String?) -> Void) {
        Task {
            // Validate before saving
            guard invoice.clientId != nil else {
                completion(false, nil)
                return
            }
            guard !invoiceItems.isEmpty else {
                completion(false, nil)
                return
            }
            if let due = dueDate, due < issueDate {
                completion(false, nil)
                return
            }

            do {
                // For new invoices, ensure they have a proper invoice number if empty
                if isNewInvoice && invoiceNumber.isEmpty {
                    invoiceNumber = try await invoicesRepository.generateInvoiceNumber()
                }
                
                // Calculate total amount
                let subtotal = invoiceItems.reduce(0.0) { $0 + $1.lineTotal }
                let discountAmount = subtotal * (discount / 100.0)
                let subtotalAfterDiscount = subtotal - discountAmount
                let taxAmount = subtotalAfterDiscount * (taxRate / 100.0)
                let totalAmount = subtotalAfterDiscount + taxAmount - creditApplied
                
                // Create updated invoice domain model
                let updatedInvoice = Invoice(
                    id: invoice.id,
                    invoiceNumber: invoiceNumber,
                    totalAmount: totalAmount,
                    taxRate: taxRate,
                    creditApplied: creditApplied,
                    discount: discount,
                    date: invoice.date == Date.distantPast ? issueDate : invoice.date,
                    dueDate: dueDate,
                    issueDate: issueDate,
                    notes: notes,
                    paidDate: invoice.paidDate,
                    paymentTerms: paymentTerms,
                    status: status,
                    sentDate: invoice.sentDate,
                    currencyCode: currencyCode,
                    // Preserve snapshot data from original invoice
                    businessName: invoice.businessName,
                    businessABN: invoice.businessABN,
                    businessEmail: invoice.businessEmail,
                    businessAddress: invoice.businessAddress,
                    businessPhone: invoice.businessPhone,
                    clientName: invoice.clientName,
                    clientNDISNumber: invoice.clientNDISNumber,
                    clientEmail: invoice.clientEmail,
                    clientPhone: invoice.clientPhone,
                    clientAddress: invoice.clientAddress,
                    billingAuthority: invoice.billingAuthority,
                    billToName: invoice.billToName,
                    billToEmail: invoice.billToEmail,
                    billToAddress: invoice.billToAddress,
                    payeeName: invoice.payeeName,
                    payeeEmail: invoice.payeeEmail,
                    payeePhone: invoice.payeePhone,
                    payeeAddress: invoice.payeeAddress,
                    bankName: invoice.bankName,
                    bankAccountName: invoice.bankAccountName,
                    bankBSB: invoice.bankBSB,
                    bankAccountNumber: invoice.bankAccountNumber,
                    clientId: invoice.clientId,
                    businessId: invoice.businessId,
                    payeeId: invoice.payeeId,
                    sessionIds: invoice.sessionIds
                )
                
                // Save invoice
                let savedInvoice = isNewInvoice 
                    ? try await invoicesRepository.create(updatedInvoice)
                    : try await invoicesRepository.update(updatedInvoice)
                
                // Save/update items
                for (index, item) in invoiceItems.enumerated() {
                    let itemWithPosition = InvoiceItem(
                        id: item.id,
                        invoiceId: savedInvoice.id,
                        sessionId: item.sessionId,
                        clientServiceId: item.clientServiceId,
                        itemDescription: item.itemDescription,
                        quantity: item.quantity,
                        rate: item.rate,
                        position: Int32(index)
                    )
                    
                    if item.id == UUID() || invoiceItems.firstIndex(where: { $0.id == item.id }) == nil {
                        _ = try await invoicesRepository.addItem(itemWithPosition)
                    } else {
                        _ = try await invoicesRepository.updateItem(itemWithPosition)
                    }
                }
                
                // Update local invoice reference
                self.invoice = savedInvoice
                await loadInvoiceItems()
                
                completion(true, savedInvoice.invoiceNumber)
            } catch {
                print("❌ [InvoiceEditorViewModel] Error saving invoice: \(error)")
                completion(false, nil)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func updateInvoiceCalculatedFields() {
        // Note: Calculations now done in saveInvoice method
        // This method kept for compatibility but no longer mutates entities
    }

    // On cancel, discard tempInvoice and reset UI
    func cancelEditing() {
        // For new invoices, just call onInvoiceDeleted (no need to delete from repository as it wasn't saved)
        if isNewInvoice {
            onInvoiceDeleted?()
            return
        }
        // For existing invoices, reload from repository to discard changes
        Task {
            do {
                if let reloadedInvoice = try await invoicesRepository.fetch(by: invoice.id) {
                    self.invoice = reloadedInvoice
                    await loadInvoiceItems()
                }
            } catch {
                print("❌ [InvoiceEditorViewModel] Error reloading invoice: \(error)")
            }
        }
    }

    func deleteInvoiceAndDismiss() {
        Task {
            do {
                try await invoicesRepository.delete(id: invoice.id)
                onInvoiceDeleted?()
            } catch {
                print("❌ [InvoiceEditorViewModel] Error deleting invoice: \(error)")
            }
        }
    }

    // MARK: - Void and Credit Note
    func voidInvoice() {
        guard !isNewInvoice else { return }
        Task {
            do {
                try await invoicesRepository.updateStatus(id: invoice.id, status: "voided")
            } catch {
                print("❌ [InvoiceEditorViewModel] Error voiding invoice: \(error)")
            }
        }
    }

    func createCreditNote(from amount: Double, notes: String? = nil) {
        guard amount > 0, let clientId = invoice.clientId else { return }
        // Note: Credit note creation requires ClientsRepository for updating client credit
        // This functionality should be moved to a use case or service
        print("⚠️ [InvoiceEditorViewModel] Credit note creation requires ClientsRepository - not implemented")
    }

    // MARK: - Printing and Exporting
    @MainActor
    func exportInvoiceToPDF() {
        guard let pdfData = InvoiceSharingService.renderPDFData(invoice: invoice, invoiceItems: invoiceItems) else {
            print("Failed to generate PDF data for export.")
            return
        }

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.showsTagField = false
        savePanel.nameFieldStringValue = "Invoice-\(invoice.invoiceNumber).pdf"

        savePanel.begin { result in
            guard result == .OK, let url = savePanel.url else { return }

            do {
                try pdfData.write(to: url)
                print("PDF exported successfully to \(url.lastPathComponent).")
            } catch {
                print("Failed to write PDF to \(url): \(error.localizedDescription).")
            }
        }
    }

    // MARK: - Sharing
    @MainActor
    func generateTemporaryPDFFileURLForSharing() -> URL? {
        return InvoiceSharingService.temporaryPDFURL(invoice: invoice, invoiceItems: invoiceItems)
    }

    func shareBodyText() -> String {
        "Please find attached your invoice \(invoice.invoiceNumber)."
    }

    @MainActor
    func itemProviderForPDFSharing() -> NSItemProvider? {
        return InvoiceSharingService.pdfItemProvider(invoice: invoice, invoiceItems: invoiceItems)
    }

    @MainActor
    func sendInvoiceViaEmail() {
        guard let pdfData = InvoiceSharingService.renderPDFData(invoice: invoice, invoiceItems: invoiceItems) else {
            print("Failed to generate PDF data for email.")
            return
        }

        let pdfFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Invoice-\(invoice.invoiceNumber).pdf")

        do {
            try pdfData.write(to: pdfFileURL)
        } catch {
            print("Failed to write PDF data to temporary file: \(error.localizedDescription)")
            return
        }

        var primaryRecipient: (email: String, name: String)? = nil
        var ccRecipients: [(email: String, name: String)] = []

        // Use snapshot data from domain model
        let billToEmail = invoice.billToEmail
        let billToName = invoice.billToName
        let clientEmail = invoice.clientEmail
        let clientName = invoice.clientName
        let payeeEmail = invoice.payeeEmail
        let payeeName = invoice.payeeName
        
        // Determine primary recipient based on billing authority
        // Note: billingAuthority is stored as String in snapshot
        if let email = billToEmail ?? clientEmail, !email.isEmpty {
            primaryRecipient = (email: email, name: billToName ?? clientName ?? "Client")
        } else if let email = payeeEmail, !email.isEmpty {
            primaryRecipient = (email: email, name: payeeName ?? "Parent/Guardian")
        }

        guard let primary = primaryRecipient else {
            print("No valid primary recipient found for invoice \(invoice.invoiceNumber).")
            return
        }

        let subject = "Invoice \(invoice.invoiceNumber) from \(invoice.businessName ?? "Your Business") - Due \(dateFormatter.string(from: invoice.dueDate ?? Date()))"
        let body = "Dear \(primary.name),\n\nPlease find attached your invoice \(invoice.invoiceNumber)."

        // Use NSSharingService to compose with the attachment
        if let service = NSSharingService(named: .composeEmail) {
            service.recipients = [primary.email] + ccRecipients.map { $0.email }
            service.subject = subject
            self.emailSharingService = service
            // Provide a dedicated NSObject delegate to observe completion
            let delegate = EmailSharingDelegate()
            delegate.onFinish = { [weak self] in
                self?.emailSharingService = nil
                self?.emailSharingDelegate = nil
                // Mark sent on success path (best-effort)
                Task { @MainActor in
                    guard let self = self else { return }
                    if self.status == AppConstants.invoiceStatusDraft {
                        try? await self.invoicesRepository.updateStatus(id: self.invoice.id, status: "sent")
                        // Reload invoice to get updated sentDate
                        if let updatedInvoice = try? await self.invoicesRepository.fetch(by: self.invoice.id) {
                            self.invoice = updatedInvoice
                        }
                    }
                }
            }
            self.emailSharingDelegate = delegate
            service.delegate = delegate
            // Include body text and file URL to ensure the attachment is honored across mail clients
            service.perform(withItems: [body as NSString, pdfFileURL as NSURL])
        }
    }

// Keep the protocol conformance at file scope
// moved to file scope at bottom
    
    // MARK: - Helper Methods for Business Data
    // Note: Business data is stored in invoice snapshot (businessName, businessABN, etc.)
    // A4InvoiceSheetView already accepts domain models (Invoice, InvoiceItem, BusinessInfo)
    private func getBusinessData() -> (name: String?, abn: String?, email: String?, address: String?, phone: String?) {
        return (
            name: invoice.businessName,
            abn: invoice.businessABN,
            email: invoice.businessEmail,
            address: invoice.businessAddress,
            phone: invoice.businessPhone
        )
    }
}

// MARK: - Sharing delegate helper
private final class EmailSharingDelegate: NSObject, NSSharingServiceDelegate {
    var onFinish: (() -> Void)?
    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        onFinish?()
    }
    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: Error) {
        onFinish?()
    }
}

// MARK: - Deep Copy Helpers (Removed - Invoice domain model no longer exists)
// Removed InvoiceItem extension - domain model no longer exists

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

extension InvoiceEditorViewModel {
    /// Print the current invoice using A4InvoiceSheetView and NSPrintOperation (macOS only)
    func printInvoice() {
        let printView = SharedUI.A4InvoiceSheetView(invoice: invoice, invoiceItems: invoiceItems)
        let hostingView = NSHostingView(rootView: printView.frame(width: 794, height: 1123)) // A4 size in points
        guard let printInfo = NSPrintInfo.shared.copy() as? NSPrintInfo else {
            print("Failed to copy NSPrintInfo")
            return
        }
        printInfo.horizontalPagination = .automatic
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = true
        printInfo.topMargin = 20
        printInfo.bottomMargin = 20
        printInfo.leftMargin = 20
        printInfo.rightMargin = 20
        let printOperation = NSPrintOperation(view: hostingView, printInfo: printInfo)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        printOperation.run()
    }
}
