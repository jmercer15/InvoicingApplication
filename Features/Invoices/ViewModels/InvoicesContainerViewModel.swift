import SwiftUI
import Combine
import PDFKit
import SwiftData
import AppKit

class InvoicesContainerViewModel: ObservableObject {
    // MARK: - Dependencies
    private var modelContext: ModelContext
    
    // MARK: - Published State
    @Published var selectedInvoice: InvoiceEntity?
    @Published var invoiceSearchText: String = ""
    @Published var invoiceFilterStatus: Set<String> = []
    @Published var invoiceSortOrder: InvoicesSortOrder = .dateDesc
    
    // Detail view management
    @Published private(set) var displayedInvoice: InvoiceEntity?
    @Published private(set) var isTransitioningToBlack: Bool = false
    @Published private(set) var invoiceEditorViewModel: InvoiceEditorViewModel?
    @Published var isEditingInvoice: Bool = false
    @Published var showingInvoiceGeneratorSheet: Bool = false
    
    // UI state
    @Published var isGenerateButtonHovered: Bool = false
    @Published var isNewInvoiceButtonHovered: Bool = false
    
    // Private state for tracking changes
    private var previousSelectedInvoice: InvoiceEntity?
    
    private var cancellables = Set<AnyCancellable>()
    // Keep a strong reference to the sharing service while composing email
    private var emailSharingService: NSSharingService?
    
    // MARK: - Initializer
    init(context: ModelContext) {
        self.modelContext = context
        setupBindings()
        
        // Observe changes to the ModelContext
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // Handle selection changes
        $selectedInvoice
            .removeDuplicates()
            .sink { [weak self] newInvoice in
                self?.handleInvoiceSelectionChange(newInvoice: newInvoice)
            }
            .store(in: &cancellables)
        
        // Debug logging for other changes
        $invoiceSearchText
            .dropFirst()
            .sink { newText in
                print("[InvoicesContainerViewModel] invoiceSearchText changed to: \(newText)")
            }
            .store(in: &cancellables)
            
        $invoiceFilterStatus
            .dropFirst()
            .sink { newFilterStatus in
                print("[InvoicesContainerViewModel] invoiceFilterStatus changed to: \(newFilterStatus.debugDescription)")
            }
            .store(in: &cancellables)
            
        $invoiceSortOrder
            .dropFirst()
            .sink { newSortOrder in
                print("[InvoicesContainerViewModel] invoiceSortOrder changed to: \(newSortOrder.rawValue)")
            }
            .store(in: &cancellables)
    }
    
    private func handleInvoiceSelectionChange(newInvoice: InvoiceEntity?) {
        print("[InvoicesContainerViewModel] selectedInvoice changed to: \(newInvoice?.invoiceNumber ?? "nil")")
        
        // Check if the currently displayed invoice has been deleted from the context
        if let currentDisplayed = displayedInvoice,
           let _ = invoiceEditorViewModel,
           newInvoice == nil && previousSelectedInvoice != nil {
            // In SwiftData, direct check for 'isDeleted' is not as straightforward as CoreData's 'isDeleted' property.
            // Instead, we can try to refetch the object. If it's nil, it's deleted.
            let descriptor = FetchDescriptor<InvoiceEntity>()
            if let invoices = try? modelContext.fetch(descriptor),
               !invoices.contains(where: { $0.id == currentDisplayed.id }) {
                print("[InvoicesContainerViewModel] Detected invoice deletion, clearing display")
                // Invoice was deleted, clear everything immediately
                DispatchQueue.main.async { [weak self] in
                    self?.displayedInvoice = nil
                    self?.invoiceEditorViewModel = nil
                    self?.isEditingInvoice = false
                    self?.isTransitioningToBlack = false
                }
                return
            }
        }
        
        if previousSelectedInvoice != nil && newInvoice != nil && previousSelectedInvoice?.id != newInvoice?.id {
            // Case 1: Switching between two different VALID invoices
            DispatchQueue.main.async {
                self.isTransitioningToBlack = true
                self.invoiceEditorViewModel = nil // Clear the old view model
                self.isEditingInvoice = false // Not editing when switching to an existing invoice
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.displayedInvoice = newInvoice
                    if let inv = newInvoice {
                        // Create the new view model *after* the black screen is up
                        let isNew = self.isNewInvoice(inv)
                        self.invoiceEditorViewModel = self.createInvoiceEditorViewModel(for: inv, isNew: isNew)
                        self.isEditingInvoice = isNew // Edit mode for new invoices
                    }
                    
                    self.isTransitioningToBlack = false
                }
            }
        } else if let inv = newInvoice, previousSelectedInvoice == nil {
            // Case 2: Selecting an invoice when nothing was selected
            DispatchQueue.main.async {
                self.isTransitioningToBlack = false
                self.displayedInvoice = inv
                let isNew = self.isNewInvoice(inv)
                self.invoiceEditorViewModel = self.createInvoiceEditorViewModel(for: inv, isNew: isNew)
                self.isEditingInvoice = isNew // Edit mode for new invoices
            }
        } else if newInvoice == nil && previousSelectedInvoice != nil {
            // Case 3: Deselecting an invoice (or invoice was deleted)
            DispatchQueue.main.async {
                self.isTransitioningToBlack = false
                self.displayedInvoice = nil
                self.invoiceEditorViewModel = nil
                self.isEditingInvoice = false
            }
            print("[InvoicesContainerViewModel] Cleared selection - showing empty state")
        } else if let inv = newInvoice, inv.id == previousSelectedInvoice?.id, self.invoiceEditorViewModel == nil {
            // Case 4: Reselecting the same item or updating it
            DispatchQueue.main.async {
                self.isTransitioningToBlack = false
                self.displayedInvoice = inv
                let isNew = self.isNewInvoice(inv)
                self.invoiceEditorViewModel = self.createInvoiceEditorViewModel(for: inv, isNew: isNew)
                self.isEditingInvoice = isNew // Edit mode for new invoices
            }
        }
        
        // Update the previousSelectedInvoice
        previousSelectedInvoice = newInvoice
    }
    
    private func createInvoiceEditorViewModel(for invoice: InvoiceEntity, isNew: Bool) -> InvoiceEditorViewModel {
        let viewModel = InvoiceEditorViewModel(context: modelContext, invoice: invoice, isNew: isNew)
        viewModel.onInvoiceDeleted = { [weak self] in
            // Clear the selected invoice when deleted
            DispatchQueue.main.async {
                self?.selectedInvoice = nil
            }
        }
        return viewModel
    }
    
    private func isNewInvoice(_ invoice: InvoiceEntity) -> Bool {
        // Check if this is a new invoice that hasn't been saved yet
        // New invoices will have empty invoice number and no client
        return (invoice.invoiceNumber.isEmpty || invoice.invoiceNumber == "") && invoice.client == nil
    }
    
    // MARK: - Public Methods
    func initializeIfNeeded() {
        // Initialize displayedInvoice and viewModel when the view appears
        if let initialInvoice = selectedInvoice, self.displayedInvoice == nil {
            self.displayedInvoice = initialInvoice
            let isNew = self.isNewInvoice(initialInvoice)
            self.invoiceEditorViewModel = createInvoiceEditorViewModel(for: initialInvoice, isNew: isNew)
            self.isEditingInvoice = isNew // Edit mode for new invoices
        }
        self.isTransitioningToBlack = false // Ensure it's false initially
    }
    
    func prepareNewInvoice() {
        let newInvoice = InvoiceEntity(id: UUID(), invoiceNumber: "")
        newInvoice.date = Date()
        let issueDate = newInvoice.issueDate
        newInvoice.dueDate = Calendar.current.date(byAdding: .day, value: AppConstants.defaultInvoiceDueDays, to: issueDate)
        newInvoice.status = AppConstants.invoiceStatusDraft
        newInvoice.paymentTerms = UserDefaults.standard.string(forKey: "defaultPaymentTerms") ?? "\(AppConstants.defaultInvoiceDueDays) days"
        newInvoice.taxRate = UserDefaults.standard.double(forKey: "defaultTaxRate") // Assumes defaultTaxRate exists in UserDefaults
        newInvoice.currencyCode = "AUD"
        // Don't set a temporary number here, generate it on save if needed
        
        // Insert the invoice into the model context immediately so it can be tracked and properly deleted if cancelled
        modelContext.insert(newInvoice)
        selectedInvoice = newInvoice
        isEditingInvoice = true // Set to true for a new invoice
    }
    
    @MainActor
    func exportInvoiceToPDF(invoice: InvoiceEntity) {
        guard invoice.business != nil else {
            print("Business details are not loaded yet. Cannot export PDF.")
            return
        }

        guard let pdfData = generatePdfData(invoice: invoice) else {
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

    @MainActor
    private func generatePdfData(invoice: InvoiceEntity) -> Data? {
        let business = invoice.business ?? {
            let descriptor = FetchDescriptor<BusinessEntity>()
            return (try? modelContext.fetch(descriptor))?.first
        }()
        guard let biz = business else { return nil }
        return InvoiceSharingService.renderPDFData(invoice: invoice, business: biz, context: modelContext)
    }
    
    func updateInvoiceStatus(_ invoice: InvoiceEntity, status: String) {
        invoice.status = status
        // Add paidDate logic if status is "Paid"
        if status == AppConstants.invoiceStatusPaid {
            invoice.paidDate = Date()
        } else {
            invoice.paidDate = nil
        }
        _ = saveContext()
    }

    private func saveContext() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            print("Error saving context: \(error)")
            // Handle error (e.g., show alert)
            // Consider rolling back if appropriate
            modelContext.rollback()
            return false
        }
    }

    @MainActor
    func sendInvoiceViaEmail(invoice: InvoiceEntity) {
        guard let pdfData = generatePdfData(invoice: invoice) else {
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
        case "Parent/Guardian":
            if let email = billToEmail ?? payeeEmail, !email.isEmpty {
                primaryRecipient = (email: email, name: billToName ?? payeeName ?? "Parent/Guardian")
            }
        case "Client":
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
                let planManagerRecipient = (email: planManagerEmail, name: planManager.businessName ?? "Plan Manager")
                if primaryRecipient?.email != planManagerEmail {
                    ccRecipients.append(planManagerRecipient)
                }
            }
        }

        guard let primary = primaryRecipient else {
            print("No valid primary recipient found for invoice \(invoice.invoiceNumber).")
            return
        }

        let subject = "Invoice \(invoice.invoiceNumber) from \(invoice.businessName ?? invoice.business?.name ?? "Your Business") - Due \(dateFormatter.string(from: invoice.dueDate ?? Date()))"
        let body = "Dear \(primary.name),\n\nPlease find attached your invoice \(invoice.invoiceNumber)."

        // Use NSSharingService to compose with the attachment
        if let service = NSSharingService(named: .composeEmail) {
            service.recipients = [primary.email] + ccRecipients.map { $0.email }
            service.subject = subject
            self.emailSharingService = service
            service.perform(withItems: [body as NSString, pdfFileURL as NSURL])
            // Mark sent at initiation (or wire a delegate similar to editor)
            invoice.sentDate = Date()
            if invoice.status == AppConstants.invoiceStatusDraft {
                invoice.status = AppConstants.invoiceStatusIssued
            }
            _ = saveContext()
        }
    }

    // Helper function for dynamic filter button text
    func filterStatusText() -> String {
        if invoiceFilterStatus.isEmpty {
            return "Filter Status"
        } else if invoiceFilterStatus.count == AppConstants.invoiceStatusOptions.count {
            return "All Statuses"
        } else {
            return "Filtered (\(invoiceFilterStatus.count))"
        }
    }

    // Helper function for dynamic filter button icon
    func filterStatusIcon() -> String {
        invoiceFilterStatus.isEmpty ? "line.horizontal.3.decrease.circle" : "line.horizontal.3.decrease.circle.fill"
    }

    // Update the modelContext if a new one is provided
    func updateContextIfNeeded(_ newContext: ModelContext) {
        if modelContext !== newContext {
            modelContext = newContext
        }
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}() 