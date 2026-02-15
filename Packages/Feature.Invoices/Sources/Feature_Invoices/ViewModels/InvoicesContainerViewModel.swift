// swift-tools-version:5.9

import SwiftUI
import Combine
import PDFKit
import AppKit
import os
import Core
import Data
import SharedUI
import Feature_InvoiceTemplateEditor

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
    let payeesRepository: PayeeRepository
    let planManagersRepository: PlanManagerRepository
    let sharingService: InvoiceSharingService
    let complianceValidator: NDISComplianceValidator?
    let complianceBlockingEnabled: Bool
    let complianceLogger = Logger(subsystem: "com.invoicing.compliance", category: "InvoicesContainer")
    static let complianceBlockerDowngradeKey = "debug.compliance.downgradeBlockersToWarnings"
    
    // MARK: - Published State
    @Published public var selectedInvoice: Invoice?
    @Published public var isLoading: Bool = false
    @Published private(set) var allInvoices: [Invoice] = []
    @Published var invoiceSearchText: String = ""
    @Published var invoiceFilterStatus: Set<String> = []
    @Published var invoiceSortOrder: InvoicesSortOrder = .dateDesc
    @Published var groupBy: GroupBy = .none
    
    // Sorting controls
    @Published var sortField: SortField = .date
    @Published var sortDirection: SortDirection = .descending
    
    // Detail view management
    @Published private(set) var displayedInvoice: Invoice?
    @Published private(set) var isTransitioningToBlack: Bool = false
    @Published private(set) var invoiceEditorViewModel: InvoiceEditorViewModel?
    @Published var isEditingInvoice: Bool = false
    @Published var showingInvoiceGeneratorSheet: Bool = false
    @Published var complianceStatusMessage: String?
    @Published var complianceStatusIsBlocker: Bool = false
    
    // Date Range Filter (nil means not filtered)
    @Published var filterStartDate: Date? = nil
    @Published var filterEndDate: Date? = nil
    
    // Amount Range Filter (nil means not filtered)
    @Published var filterMinAmount: Double? = nil
    @Published var filterMaxAmount: Double? = nil
    
    // Client Filter (nil or empty means show all)
    @Published var filterClients: Set<String> = []
    
    // Computed helpers for filter active state
    var isDateFilterActive: Bool {
        filterStartDate != nil || filterEndDate != nil
    }
    var isAmountFilterActive: Bool {
        filterMinAmount != nil || filterMaxAmount != nil
    }
    var isClientFilterActive: Bool {
        !filterClients.isEmpty
    }
    
    // Get unique client names from all invoices
    var uniqueClientNames: [String] {
        let names = allInvoices.compactMap { $0.clientName }.filter { !$0.isEmpty }
        return Array(Set(names)).sorted()
    }
    
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
    public init(
        invoicesRepository: InvoicesRepository,
        clientServicesRepository: ClientServicesRepository,
        clientsRepository: ClientsRepository,
        payeesRepository: PayeeRepository,
        planManagersRepository: PlanManagerRepository,
        sharingService: InvoiceSharingService,
        complianceValidator: NDISComplianceValidator? = nil,
        complianceBlockingEnabled: Bool = true
    ) { 
        self.invoicesRepository = invoicesRepository
        self.clientServicesRepository = clientServicesRepository
        self.clientsRepository = clientsRepository
        self.payeesRepository = payeesRepository
        self.planManagersRepository = planManagersRepository
        self.sharingService = sharingService
        self.complianceValidator = complianceValidator
        self.complianceBlockingEnabled = complianceBlockingEnabled
        setupBindings()
        Task {
            await fetchAllInvoices()
        }
    }
    
    // MARK: - Data Fetching
    func fetchAllInvoices() async {
        await MainActor.run { self.isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }
        
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
        
        // Subscribe to cross-feature invoice refresh notifications
        InvoiceChangePublisher.shared.invoicesRefreshNeeded
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { await self?.fetchAllInvoices() }
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
            payeesRepository: payeesRepository,
            planManagersRepository: planManagersRepository,
            sharingService: sharingService,
            invoice: invoice,
            isNew: isNew,
            complianceValidator: complianceValidator,
            complianceBlockingEnabled: complianceBlockingEnabled
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
    public func selectInvoice(byId id: UUID) {
        Task { @MainActor in
            // Try to find in loaded invoices first to avoid refetch
            if let invoice = allInvoices.first(where: { $0.id == id }) {
                self.selectedInvoice = invoice
                return
            }
            
            // Try fetching from repository
            do {
                if let invoice = try await invoicesRepository.fetch(by: id) {
                    self.selectedInvoice = invoice
                }
            } catch {
                print("❌ [InvoicesContainerViewModel] Error fetching invoice for selection: \(error)")
            }
        }
    }

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
            dueDate: Calendar.current.date(byAdding: .day, value: UserDefaults.standard.integer(forKey: "defaultPaymentTerms"), to: issueDate) ?? issueDate,
            issueDate: issueDate,
            notes: UserDefaults.standard.string(forKey: "defaultNotes"),
            paymentTerms: UserDefaults.standard.string(forKey: "defaultPaymentTermsText"),
            status: AppConstants.invoiceStatusReviewDraft,
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
            return await sharingService.renderPDFData(
                invoice: invoice,
                invoiceItems: invoiceItems
            )
        } catch {
            print("❌ [InvoicesContainerViewModel] Error fetching invoice items for PDF: \(error)")
            return nil
        }
    }
    
    func updateInvoiceStatus(_ invoiceId: UUID, status: String) async {
        if let invoice = allInvoices.first(where: { $0.id == invoiceId }) {
            if let validation = await validateInvoiceTransitionIfNeeded(
                invoice: invoice,
                targetStatus: status,
                action: .statusChange
            ) {
                if validation.isBlocked {
                    applyComplianceMessage(blockerSummary(for: validation), isBlocker: true)
                    return
                }
                if !validation.warnings.isEmpty {
                    applyComplianceMessage(warningSummary(for: validation), isBlocker: false)
                }
            }
        }
        do {
            try await invoicesRepository.updateStatus(id: invoiceId, status: status)
            // If status is paid, also update paidDate via repository
            if status == AppConstants.invoiceStatusReceived {
                // Note: Repository should handle paidDate update in updateStatus
                // If not, we may need to fetch, update, and save
            }
            // Notify other features about the change
            InvoiceChangePublisher.shared.notifyChange(invoiceId: invoiceId)
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
                if invoice.status != AppConstants.invoiceStatusPending
                    && invoice.status != AppConstants.invoiceStatusReceived {
                    if let validation = await self.validateInvoiceTransitionIfNeeded(
                        invoice: invoice,
                        targetStatus: AppConstants.invoiceStatusPending,
                        action: .sendInvoice
                    ) {
                        if validation.isBlocked {
                            await MainActor.run {
                                self.applyComplianceMessage(self.blockerSummary(for: validation), isBlocker: true)
                            }
                            return
                        }
                        if !validation.warnings.isEmpty {
                            await MainActor.run {
                                self.applyComplianceMessage(self.warningSummary(for: validation), isBlocker: false)
                            }
                        }
                    }
                    try? await invoicesRepository.updateStatus(id: invoice.id, status: AppConstants.invoiceStatusPending)
                    InvoiceChangePublisher.shared.notifyChange(invoiceId: invoice.id)
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

private extension InvoicesContainerViewModel {
    func validateInvoiceTransitionIfNeeded(
        invoice: Invoice,
        targetStatus: String,
        action: ComplianceAction
    ) async -> ComplianceValidationResult? {
        guard complianceBlockingEnabled, let complianceValidator else { return nil }
        guard isForwardInvoiceTransition(from: invoice.status, to: targetStatus) else { return nil }
        do {
            let result = try await complianceValidator.validateInvoiceTransition(
                invoiceId: invoice.id,
                action: action,
                targetStatus: targetStatus
            )
            let adjustedResult = applyDebugBlockerDowngradeIfNeeded(
                result,
                invoiceId: invoice.id,
                action: action,
                targetStatus: targetStatus
            )
            logComplianceValidationResult(
                adjustedResult,
                invoiceId: invoice.id,
                action: action,
                targetStatus: targetStatus
            )
            return adjustedResult
        } catch {
            complianceLogger.error(
                "validation_failed action=\(action.rawValue, privacy: .public) invoice_id=\(invoice.id.uuidString, privacy: .public) target_status=\(targetStatus, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
            return ComplianceValidationResult(
                blockers: [
                    ComplianceIssue(
                        id: "COMPLIANCE-VAL-001",
                        severity: .blocker,
                        message: "Unable to validate compliance: \(error.localizedDescription)",
                        entityId: invoice.id
                    )
                ]
            )
        }
    }

    func applyComplianceMessage(_ message: String, isBlocker: Bool) {
        complianceStatusMessage = message
        complianceStatusIsBlocker = isBlocker
    }

    func blockerSummary(for result: ComplianceValidationResult) -> String {
        let messages = result.blockers.prefix(2).map(\.message).joined(separator: " ")
        return "Blocked by compliance (\(result.blockers.count)): \(messages)"
    }

    func warningSummary(for result: ComplianceValidationResult) -> String {
        let messages = result.warnings.prefix(2).map(\.message).joined(separator: " ")
        return "Compliance warnings (\(result.warnings.count)): \(messages)"
    }

    var complianceBlockerDowngradeEnabled: Bool {
#if DEBUG
        UserDefaults.standard.bool(forKey: Self.complianceBlockerDowngradeKey)
#else
        false
#endif
    }

    func applyDebugBlockerDowngradeIfNeeded(
        _ result: ComplianceValidationResult,
        invoiceId: UUID,
        action: ComplianceAction,
        targetStatus: String
    ) -> ComplianceValidationResult {
        guard complianceBlockerDowngradeEnabled, !result.blockers.isEmpty else { return result }
        let downgradedWarnings = result.blockers.map {
            ComplianceIssue(
                id: $0.id,
                severity: .warning,
                message: $0.message,
                entityId: $0.entityId,
                field: $0.field
            )
        }
        complianceLogger.warning(
            "debug_downgrade_enabled action=\(action.rawValue, privacy: .public) invoice_id=\(invoiceId.uuidString, privacy: .public) target_status=\(targetStatus, privacy: .public) downgraded_blocker_count=\(result.blockers.count, privacy: .public)"
        )
        return ComplianceValidationResult(
            warnings: result.warnings + downgradedWarnings,
            blockers: []
        )
    }

    func logComplianceValidationResult(
        _ result: ComplianceValidationResult,
        invoiceId: UUID,
        action: ComplianceAction,
        targetStatus: String
    ) {
        if !result.blockers.isEmpty {
            let ruleIds = result.blockers.map(\.id).joined(separator: ",")
            let issueEntityIds = result.blockers.compactMap(\.entityId).map(\.uuidString).joined(separator: ",")
            complianceLogger.error(
                "block_event action=\(action.rawValue, privacy: .public) invoice_id=\(invoiceId.uuidString, privacy: .public) target_status=\(targetStatus, privacy: .public) blocker_count=\(result.blockers.count, privacy: .public) rule_ids=\(ruleIds, privacy: .public) issue_entity_ids=\(issueEntityIds, privacy: .public)"
            )
        }

        if !result.warnings.isEmpty {
            let ruleIds = result.warnings.map(\.id).joined(separator: ",")
            complianceLogger.info(
                "warning_event action=\(action.rawValue, privacy: .public) invoice_id=\(invoiceId.uuidString, privacy: .public) target_status=\(targetStatus, privacy: .public) warning_count=\(result.warnings.count, privacy: .public) rule_ids=\(ruleIds, privacy: .public)"
            )
        }
    }

    func isForwardInvoiceTransition(from current: String, to target: String) -> Bool {
        guard let currentRank = workflowRank(for: current),
              let targetRank = workflowRank(for: target) else {
            return false
        }
        return targetRank > currentRank
    }

    func workflowRank(for status: String) -> Int? {
        switch status {
        case AppConstants.invoiceStatusReviewDraft:
            return 0
        case AppConstants.invoiceStatusReadyToSend:
            return 1
        case AppConstants.invoiceStatusPending, AppConstants.invoiceStatusOverdue:
            return 2
        case AppConstants.invoiceStatusReceived:
            return 3
        default:
            return nil
        }
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}() 
