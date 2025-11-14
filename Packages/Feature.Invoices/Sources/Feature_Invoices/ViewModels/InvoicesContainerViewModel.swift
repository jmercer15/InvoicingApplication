// swift-tools-version:5.9

import SwiftUI
import Combine
import PDFKit
import AppKit
import Core
import SharedUI

// The data race warnings below are false positives for ObservableObject usage on main thread

// MARK: - GroupBy Enum
enum GroupBy: String, CaseIterable, Identifiable {
    case none = "None"
    case status = "Status"
    case client = "Client"
    case month = "Month"
    case quarter = "Quarter"
    var id: String { self.rawValue }
}



@MainActor
public class InvoicesContainerViewModel: ObservableObject {
    // MARK: - Dependencies
    let invoicesRepository: InvoicesRepository
    let clientServicesRepository: ClientServicesRepository
    let clientsRepository: ClientsRepository
    
    // MARK: - Published State
    @Published public var selectedInvoice: Invoice?
    @Published private(set) var allInvoices: [Invoice] = []
    @Published var invoiceSearchText: String = ""
    @Published var invoiceFilterStatus: Set<String> = []
    @Published var invoiceSortOrder: InvoicesSortOrder = .dateDesc
    @Published var groupBy: GroupBy = .status
    
    // Sorting controls
    @Published var sortField: SortField = .date
    @Published var sortDirection: SortDirection = .descending
    
    // Detail view management
    @Published private(set) var displayedInvoice: Invoice?
    @Published private(set) var isTransitioningToBlack: Bool = false
    @Published private(set) var invoiceEditorViewModel: InvoiceEditorViewModel?
    @Published var isEditingInvoice: Bool = false
    @Published var showingInvoiceGeneratorSheet: Bool = false
    
    // UI state
    @Published var isGenerateButtonHovered: Bool = false
    @Published var isNewInvoiceButtonHovered: Bool = false
    
    // Private state for tracking changes
    private var previousSelectedInvoice: Invoice?
    private var selectionAnimationTask: Task<Void, Never>? = nil
    
    private var cancellables = Set<AnyCancellable>()
    // Keep a strong reference to the sharing service while composing email
    private var emailSharingService: NSSharingService?
    
    // MARK: - Initializer
    public init(invoicesRepository: InvoicesRepository, clientServicesRepository: ClientServicesRepository, clientsRepository: ClientsRepository) {
        self.invoicesRepository = invoicesRepository
        self.clientServicesRepository = clientServicesRepository
        self.clientsRepository = clientsRepository
        setupBindings()
        Task {
            await fetchAllInvoices()
        }
    }
    
    // MARK: - Data Fetching
    func fetchAllInvoices() async {
        do {
            allInvoices = try await invoicesRepository.fetchAll()
        } catch {
            print("❌ [InvoicesContainerViewModel] Error fetching invoices: \(error)")
            allInvoices = []
        }
    }
    
    func deleteInvoices(_ invoiceIds: [UUID]) async {
        do {
            for invoiceId in invoiceIds {
                try await invoicesRepository.delete(id: invoiceId)
            }
            await fetchAllInvoices()
            
            // Clear selection if deleted invoice was selected
            if let selectedId = selectedInvoice?.id, invoiceIds.contains(selectedId) {
                selectedInvoice = nil
            }
        } catch {
            print("❌ [InvoicesContainerViewModel] Error deleting invoices: \(error)")
        }
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // Handle selection changes
        $selectedInvoice
            .receive(on: RunLoop.main)
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
            
        $groupBy
            .dropFirst()
            .sink { newGroupBy in
                print("[InvoicesContainerViewModel] groupBy changed to: \(newGroupBy.rawValue)")
            }
            .store(in: &cancellables)
            
        $sortField
            .dropFirst()
            .sink { newSortField in
                print("[InvoicesContainerViewModel] sortField changed to: \(newSortField.rawValue)")
                self.updateSortOrder()
            }
            .store(in: &cancellables)
            
        $sortDirection
            .dropFirst()
            .sink { newSortDirection in
                print("[InvoicesContainerViewModel] sortDirection changed to: \(newSortDirection.rawValue)")
                self.updateSortOrder()
            }
            .store(in: &cancellables)
    }
    
    private func updateSortOrder() {
        invoiceSortOrder = InvoicesSortOrder.from(field: sortField, direction: sortDirection)
    }
    
    @MainActor
    private func handleInvoiceSelectionChange(newInvoice: Invoice?) {
        print("[InvoicesContainerViewModel] selectedInvoice changed to: \(newInvoice?.invoiceNumber ?? "nil")")

        guard newInvoice?.id != previousSelectedInvoice?.id else { return }

        selectionAnimationTask?.cancel()
        selectionAnimationTask = nil
        isTransitioningToBlack = false

        let hadPreviousSelection = previousSelectedInvoice != nil || displayedInvoice != nil

        if !hadPreviousSelection {
            applySelectionImmediately(invoice: newInvoice)
            previousSelectedInvoice = newInvoice
            return
        }

        if let newInvoice {
            selectionAnimationTask = Task { [weak self] in
                await self?.animateToInvoice(newInvoice)
            }
        } else {
            selectionAnimationTask = Task { [weak self] in
                await self?.animateToEmptySelection()
            }
        }

        previousSelectedInvoice = newInvoice
    }
    
    private func createInvoiceEditorViewModel(for invoice: Invoice, isNew: Bool) -> InvoiceEditorViewModel {
        let viewModel = InvoiceEditorViewModel(
            invoicesRepository: invoicesRepository,
            clientServicesRepository: clientServicesRepository,
            clientsRepository: clientsRepository,
            invoice: invoice,
            isNew: isNew
        )
        viewModel.onInvoiceDeleted = { [weak self] in
            // Clear the selected invoice when deleted
            self?.selectedInvoice = nil
        }
        return viewModel
    }
    
    private func isNewInvoice(_ invoice: Invoice) -> Bool {
        // Check if this is a new invoice that hasn't been saved yet
        // New invoices will have empty invoice number and no client
        return (invoice.invoiceNumber.isEmpty || invoice.invoiceNumber == "") && invoice.clientId == nil
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

    @MainActor
    private func applySelectionImmediately(invoice: Invoice?) {
        if let invoice {
            displayedInvoice = invoice
            let isNew = isNewInvoice(invoice)
            invoiceEditorViewModel = createInvoiceEditorViewModel(for: invoice, isNew: isNew)
            isEditingInvoice = isNew
        } else {
            displayedInvoice = nil
            invoiceEditorViewModel = nil
            isEditingInvoice = false
        }
        isTransitioningToBlack = false
    }

    @MainActor
    private func animateToInvoice(_ invoice: Invoice) async {
        withAnimation(.easeInOut(duration: 0.12)) {
            isTransitioningToBlack = true
        }

        do {
            try await Task.sleep(nanoseconds: 120_000_000)
        } catch { return }
        guard !Task.isCancelled else { return }

        applySelectionImmediately(invoice: invoice)

        do {
            try await Task.sleep(nanoseconds: 80_000_000)
        } catch { return }
        guard !Task.isCancelled else { return }

        withAnimation(.easeInOut(duration: 0.18)) {
            isTransitioningToBlack = false
        }

        selectionAnimationTask = nil
    }

    @MainActor
    private func animateToEmptySelection() async {
        withAnimation(.easeInOut(duration: 0.12)) {
            isTransitioningToBlack = true
        }

        do {
            try await Task.sleep(nanoseconds: 100_000_000)
        } catch { return }
        guard !Task.isCancelled else { return }

        applySelectionImmediately(invoice: nil)

        withAnimation(.easeInOut(duration: 0.18)) {
            isTransitioningToBlack = false
        }

        selectionAnimationTask = nil
    }
    
    func prepareNewInvoice() {
        let issueDate = Date()
        let newInvoice = Invoice(
            id: UUID(),
            invoiceNumber: "",
            totalAmount: 0.0,
            taxRate: UserDefaults.standard.double(forKey: "defaultTaxRate"),
            creditApplied: 0.0,
            discount: 0.0,
            date: issueDate,
            dueDate: Calendar.current.date(byAdding: .day, value: AppConstants.defaultInvoiceDueDays, to: issueDate),
            issueDate: issueDate,
            paymentTerms: UserDefaults.standard.string(forKey: "defaultPaymentTerms") ?? "\(AppConstants.defaultInvoiceDueDays) days",
            status: "draft",
            currencyCode: "AUD"
        )
        selectedInvoice = newInvoice
        isEditingInvoice = true // Set to true for a new invoice
    }
    
    @MainActor
    func exportInvoiceToPDF(invoice: Invoice) {
        Task {
            guard let pdfData = await generatePdfData(invoice: invoice) else {
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
    }

    @MainActor
    private func generatePdfData(invoice: Invoice) async -> Data? {
        // Fetch invoice items for PDF generation
        do {
            let invoiceItems = try await invoicesRepository.fetchItems(by: invoice.id)
            return InvoiceSharingService.renderPDFData(invoice: invoice, invoiceItems: invoiceItems)
        } catch {
            print("❌ [InvoicesContainerViewModel] Error fetching invoice items for PDF: \(error)")
            return nil
        }
    }
    
    func updateInvoiceStatus(_ invoiceId: UUID, status: String) async {
        do {
            try await invoicesRepository.updateStatus(id: invoiceId, status: status)
            // If status is paid, also update paidDate via repository
            if status == AppConstants.invoiceStatusPaid {
                // Note: Repository should handle paidDate update in updateStatus
                // If not, we may need to fetch, update, and save
            }
        } catch {
            print("❌ [InvoicesContainerViewModel] Error updating invoice status: \(error)")
        }
    }

    @MainActor
    func sendInvoiceViaEmail(invoice: Invoice) {
        Task {
            guard let pdfData = await generatePdfData(invoice: invoice) else {
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
            
            // Determine primary recipient based on billing authority (from snapshot)
            // Note: billingAuthority is stored as String in snapshot, need to parse if needed
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
                service.perform(withItems: [body as NSString, pdfFileURL as NSURL])
                
                // Update invoice status via repository
                if invoice.status == AppConstants.invoiceStatusDraft {
                    try? await invoicesRepository.updateStatus(id: invoice.id, status: "sent")
                }
            }
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

    // Note: Context update removed - repositories handle persistence
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}() 
