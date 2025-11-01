import SwiftUI
import Combine
import PDFKit
import AppKit
import UniformTypeIdentifiers
import SwiftData
import Core
import SharedUI
import Data

class InvoiceEditorViewModel: ObservableObject, @unchecked Sendable {
    private var modelContext: ModelContext
    @Bindable var invoice: InvoiceEntity // Direct reference to the SwiftData model
    let isNewInvoice: Bool
    private var emailSharingService: NSSharingService?
    private var emailSharingDelegate: EmailSharingDelegate?

    // Callback for when invoice is deleted
    var onInvoiceDeleted: (() -> Void)?

    init(context: ModelContext, invoice existingInvoice: InvoiceEntity, isNew: Bool) {
        self.modelContext = context
        self.isNewInvoice = isNew
        self.invoice = existingInvoice
        self.onInvoiceDeleted = nil
        // Currency fixed to AUD for now
        if invoice.currencyCode.isEmpty {
            invoice.currencyCode = "AUD"
        }
    }

    // MARK: - Totals Recalculation (exposed for UI change hooks)
    func recomputeTotals() {
        updateInvoiceCalculatedFields()
    }
    
    // MARK: - Line Item Management
    func addNewInvoiceItem() {
        let newItem = InvoiceItemEntity(id: UUID(), itemDescription: "New Service/Item")
        newItem.quantity = 1.0
        newItem.rate = 0.0
        newItem.amount = 0.0
        newItem.position = Int32(invoice.itemsArray.count)
        newItem.date = invoice.issueDate
        newItem.taxRate = invoice.taxRate
        newItem.invoice = invoice
        modelContext.insert(newItem)
    }

    func deleteInvoiceItems(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { invoice.itemsArray[$0] }
        for item in itemsToDelete {
            modelContext.delete(item)
        }
        
        // Reposition remaining items
        let remainingItems = invoice.itemsArray.filter { !itemsToDelete.contains($0) }
        for (index, item) in remainingItems.enumerated() {
            item.position = Int32(index)
        }
    }
    
    func moveInvoiceItem(from source: IndexSet, to destination: Int) {
        var items = invoice.itemsArray
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.position = Int32(index)
        }
    }

    // MARK: - Client Change Handling
    func onClientChanged(to newClient: ClientEntity?) {
        // Generate invoice number when client is selected for new invoices
        if isNewInvoice && (invoice.invoiceNumber.isEmpty || invoice.invoiceNumber == "") {
            invoice.invoiceNumber = generateNextInvoiceNumber(for: newClient)
        }
    }

    // MARK: - Invoice Number Generation
    func generateNextInvoiceNumber(for client: ClientEntity?) -> String {
        InvoiceNumberingService.nextNumber(for: client, context: modelContext)
    }

    // MARK: - Save and Cancel
    func saveInvoice(completion: @escaping (Bool, String?) -> Void) {
        // Validate before saving
        if invoice.client == nil {
            completion(false, nil)
            return
        }
        if invoice.itemsArray.isEmpty {
            completion(false, nil)
            return
        }
        if let due = invoice.dueDate, due < invoice.issueDate {
            completion(false, nil)
            return
        }

        do {
            // For new invoices, ensure they have a proper invoice number if empty
            if isNewInvoice && (invoice.invoiceNumber.isEmpty || invoice.invoiceNumber == "") {
                invoice.invoiceNumber = generateNextInvoiceNumber(for: invoice.client)
            }
            
            // Update calculated fields before saving
            updateInvoiceCalculatedFields()
            
            // Snapshot related entity data into the invoice's own properties
            invoice.snapshotRelatedData()
            
            try modelContext.save()
            completion(true, invoice.invoiceNumber)
        } catch {
            _ = error as NSError
            modelContext.rollback()
            completion(false, nil)
        }
    }
    
    // MARK: - Helper Methods
    private func updateInvoiceCalculatedFields() {
        // Update line item amounts
        for item in invoice.itemsArray {
            item.amount = item.lineTotal
        }
        
        // Update the total amount based on current line items and calculations
        invoice.totalAmount = invoice.calculatedTotal
        
        // Update the date field if it's not set (use issue date as fallback)
        if invoice.date == Date.distantPast {
            invoice.date = invoice.issueDate
        }
    }

    // On cancel, discard tempInvoice and reset UI
    func cancelEditing() {
        // For new invoices, delete from context and call onInvoiceDeleted
        if isNewInvoice {
            modelContext.delete(invoice)
            do {
                try modelContext.save()
            } catch {
                print("Error deleting cancelled invoice: \(error)")
            }
            onInvoiceDeleted?()
            return
        }
        // For existing invoices, just rollback changes
        modelContext.rollback()
    }

    func deleteInvoiceAndDismiss() {
        if isNewInvoice {
            // For new invoices, delete from context
            modelContext.delete(invoice)
            do {
                try modelContext.save()
            } catch {
                print("Error deleting new invoice: \(error)")
            }
            onInvoiceDeleted?()
            return
        }
        // For existing invoices, delete from context
        modelContext.delete(invoice)
        do {
            try modelContext.save()
            onInvoiceDeleted?()
        } catch {
            print("Error deleting existing invoice: \(error)")
        }
    }

    // MARK: - Void and Credit Note
    func voidInvoice() {
        guard !isNewInvoice else { return }
        invoice.status = .voided
        do { try modelContext.save() } catch { print("Error voiding invoice: \(error)") }
    }

    func createCreditNote(from amount: Double, notes: String? = nil) {
        guard amount > 0 else { return }
        if let client = invoice.client {
            client.creditAmount += amount
            let entry = CreditHistoryEntryEntity(id: UUID())
            entry.date = Date()
            entry.amount = amount
            entry.type = .creditNote
            entry.notes = notes
            entry.relatedInvoiceNumber = invoice.invoiceNumber
            entry.client = client
            modelContext.insert(entry)
        }
        do { try modelContext.save() } catch { print("Error creating credit note: \(error)") }
    }

    // MARK: - Printing and Exporting
    @MainActor
    func exportInvoiceToPDF() {
        guard let currentBusiness = getBusiness() else {
            print("Business details are not loaded yet. Cannot export PDF.")
            return
        }

        guard let pdfData = generatePdfData(invoice: invoice, business: currentBusiness) else {
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
        guard let currentBusiness = getBusiness() else { return nil }
        guard let pdfData = generatePdfData(invoice: invoice, business: currentBusiness) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Invoice-\(invoice.invoiceNumber).pdf")
        do { try pdfData.write(to: url) } catch { return nil }
        return url
    }

    func shareBodyText() -> String {
        "Please find attached your invoice \(invoice.invoiceNumber)."
    }

    @MainActor
    func itemProviderForPDFSharing() -> NSItemProvider? {
        guard let currentBusiness = getBusiness() else { return nil }
        guard let pdfData = generatePdfData(invoice: invoice, business: currentBusiness) else { return nil }

        let provider = NSItemProvider()
        provider.suggestedName = "Invoice-\(invoice.invoiceNumber).pdf"
        provider.registerDataRepresentation(forTypeIdentifier: UTType.pdf.identifier, visibility: .all) { completion in
            completion(pdfData, nil)
            return nil
        }
        return provider
    }

    @MainActor
    private func generatePdfData(invoice: InvoiceEntity, business: BusinessEntity) -> Data? {
        // Create a view with proper styling
        let viewToRender = A4InvoiceSheetView(invoice: invoice, business: business)
            .environment(\.modelContext, modelContext)
            .environment(\.colorScheme, .light)
            .background(Color("White", bundle: .sharedUI)) // Ensure white background
            .frame(width: 595, height: 842)

        // Configure the renderer with proper settings
        let renderer = ImageRenderer(content: viewToRender)
        renderer.proposedSize = .init(width: 595, height: 842)
        renderer.scale = 3.0 // Higher scale for better quality
        
        // Set to opaque since we have a white background
        renderer.isOpaque = true
        
        // Use CGImage-based rendering for better quality
        if let cgImage = renderer.cgImage {
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: 595, height: 842))
            
            guard let pdfPage = PDFPage(image: nsImage) else {
                print("Failed to create PDF page from image for PDF data generation.")
                return nil
            }
            
            let pdfDocument = PDFDocument()
            pdfDocument.insert(pdfPage, at: 0)
            
            return pdfDocument.dataRepresentation()
        } else {
            // Fallback to the original method if cgImage fails
            guard let image = renderer.nsImage else {
                print("Failed to render invoice view to image for PDF data generation.")
                return nil
            }
            
            guard let pdfPage = PDFPage(image: image) else {
                print("Failed to create PDF page from image for PDF data generation.")
                return nil
            }
            
            let pdfDocument = PDFDocument()
            pdfDocument.insert(pdfPage, at: 0)
            
            return pdfDocument.dataRepresentation()
        }
    }

    @MainActor
    func sendInvoiceViaEmail() {
        guard let currentBusiness = getBusiness() else {
            print("Business details are not loaded yet. Cannot send email.")
            return
        }

        guard let pdfData = generatePdfData(invoice: invoice, business: currentBusiness) else {
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

        // Use snapshot data if available, otherwise fall back to relationships
        let billingAuthority = invoice.billingAuthority ?? invoice.client?.billingAuthority
        let billToEmail = invoice.billToEmail
        let billToName = invoice.billToName
        let clientEmail = invoice.clientEmail ?? invoice.client?.email
        let clientName = invoice.clientName ?? invoice.client?.fullName
        let payeeEmail = invoice.payeeEmail ?? invoice.client?.payee?.email
        let payeeName = invoice.payeeName ?? invoice.client?.payee?.fullName
        
        // Determine primary recipient based on billing authority
        switch billingAuthority {
        case .parentGuardian:
            if let email = billToEmail ?? payeeEmail, !email.isEmpty {
                primaryRecipient = (email: email, name: billToName ?? payeeName ?? "Parent/Guardian")
            }
        case .client:
            if let email = billToEmail ?? clientEmail, !email.isEmpty {
                primaryRecipient = (email: email, name: billToName ?? clientName ?? "Client")
            }
        default:
            // Fallback to client email
            if let email = clientEmail, !email.isEmpty {
                primaryRecipient = (email: email, name: clientName ?? "Client")
            }
        }
        
        // Add other enabled recipients as CC (using snapshot data when available)
        if let client = invoice.client {
            if client.sendInvoicesToClient ?? true, let email = clientEmail, !email.isEmpty {
                let clientRecipient = (email: email, name: clientName ?? "Client")
                if primaryRecipient?.email != email {
                    ccRecipients.append(clientRecipient)
                }
            }
            
            if client.sendInvoicesToPayee ?? true, let email = payeeEmail, !email.isEmpty {
                let payeeRecipient = (email: email, name: payeeName ?? "Parent/Guardian")
                if primaryRecipient?.email != email {
                    ccRecipients.append(payeeRecipient)
                }
            }
            
            if client.sendInvoicesToPlanManager ?? true, let planManager = client.planManager, let planManagerEmail = planManager.email, !planManagerEmail.isEmpty {
                let planManagerRecipient = (email: planManagerEmail, name: planManager.name ?? "Plan Manager")
                if primaryRecipient?.email != planManagerEmail {
                    ccRecipients.append(planManagerRecipient)
                }
            }
        }

        guard let primary = primaryRecipient else {
            print("No valid primary recipient found for invoice \(invoice.invoiceNumber).")
            return
        }

        // Compose with attachment via NSSharingService
        let businessName = invoice.businessName ?? currentBusiness.name
        let subject = "Invoice \(invoice.invoiceNumber) from \(businessName) - Due \(dateFormatter.string(from: invoice.dueDate ?? Date()))"
        let body = "Dear \(primary.name),\n\nPlease find attached your invoice \(invoice.invoiceNumber)."
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("Invoice-\(invoice.invoiceNumber).pdf")
        do { try pdfData.write(to: tmpURL) } catch { print("[Email] Failed to write PDF: \(error)"); return }
        if let service = NSSharingService(named: .composeEmail) {
            service.recipients = [primary.email] + ccRecipients.map { $0.email }
            service.subject = subject
            // Keep a strong reference to avoid premature deallocation
            self.emailSharingService = service
            // Provide a dedicated NSObject delegate to observe completion
            let delegate = EmailSharingDelegate()
            delegate.onFinish = { [weak self] in
                self?.emailSharingService = nil
                self?.emailSharingDelegate = nil
                // Mark sent on success path (best-effort)
                Task { @MainActor in
                    self?.invoice.sentDate = Date()
                    if self?.invoice.status?.rawValue == AppConstants.invoiceStatusDraft {
                        self?.invoice.status = .sent
                    }
                    try? self?.modelContext.save()
                }
            }
            self.emailSharingDelegate = delegate
            service.delegate = delegate
            // Include body text and file URL to ensure the attachment is honored across mail clients
            service.perform(withItems: [body as NSString, tmpURL as NSURL])
        }
    }

// Keep the protocol conformance at file scope
// moved to file scope at bottom
    
    // MARK: - Helper Methods for Business Data
    private func getBusiness() -> BusinessEntity? {
        // Try to get business from invoice first, then fetch from context
        if let business = invoice.business {
            return business
        }
        
        let businessDescriptor = FetchDescriptor<BusinessEntity>()
        return (try? modelContext.fetch(businessDescriptor))?.first
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
        let currentInvoice = invoice
        let currentBusiness = getBusiness()
        let printView = A4InvoiceSheetView(invoice: currentInvoice, business: currentBusiness)
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

    /// Duplicate the current invoice and its line items
    func duplicateInvoice() {
        let newInvoice = InvoiceEntity(id: UUID(), invoiceNumber: generateNextInvoiceNumber(for: invoice.client))
        newInvoice.status = .draft
        newInvoice.issueDate = Date()
        newInvoice.dueDate = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        newInvoice.discount = invoice.discount
        newInvoice.taxRate = invoice.taxRate
        newInvoice.creditApplied = 0.0
        newInvoice.paymentTerms = invoice.paymentTerms
        newInvoice.client = invoice.client
        newInvoice.payee = invoice.payee
        newInvoice.business = getBusiness()
        newInvoice.date = Date() // Set the date field
        
        // Duplicate line items
        let items = invoice.items
            for item in items {
                let newItem = InvoiceItemEntity(id: UUID(), itemDescription: item.itemDescription)
                newItem.quantity = item.quantity
                newItem.rate = item.rate
                newItem.position = item.position
                newItem.invoice = newInvoice
                newItem.amount = item.amount
                newItem.taxRate = item.taxRate
                newItem.date = item.date
                newItem.serviceDate = item.serviceDate
                newItem.unit = item.unit
                newItem.clientService = item.clientService
                newItem.session = item.session
                modelContext.insert(newItem)
            }
        
        // Calculate and set the total amount for the duplicated invoice
        let subtotal = newInvoice.itemsArray.reduce(0) { $0 + ($1.rate * $1.quantity) }
        let discountAmount = subtotal * (newInvoice.discount / 100.0)
        let subtotalAfterDiscount = subtotal * (1.0 - (newInvoice.discount / 100.0))
        let taxAmount = subtotalAfterDiscount * (newInvoice.taxRate / 100.0)
        newInvoice.totalAmount = subtotal - discountAmount + taxAmount - newInvoice.creditApplied
        
        modelContext.insert(newInvoice)
        do {
            try modelContext.save()
        } catch {
            print("[VM] Error duplicating invoice: \(error)")
        }
    }
    
    /// Apply the maximum available credit from the client to the invoice
    func applyMaxClientCredit() {
        guard let client = invoice.client else { return }
        
        // Get the client's available credit (you may need to adjust this based on your data model)
        let availableCredit = client.creditAmount
        
        // Apply the credit, but don't exceed the invoice total
        let maxCreditToApply = min(availableCredit, invoice.calculatedTotal)
        invoice.creditApplied = maxCreditToApply
    }
}
