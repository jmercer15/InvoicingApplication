import SwiftUI
import Combine
import PDFKit
import AppKit
import UniformTypeIdentifiers
import os
import Core
import Data
import SharedUI
import Feature_InvoiceTemplateEditor

@MainActor
class InvoiceEditorViewModel: ObservableObject {
    private let invoicesRepository: InvoicesRepository
    let clientServicesRepository: ClientServicesRepository
    private let clientsRepository: ClientsRepository
    private let payeesRepository: PayeeRepository
    private let planManagersRepository: PlanManagerRepository
    private let complianceValidator: NDISComplianceValidator?
    private let complianceBlockingEnabled: Bool
    private let complianceLogger = Logger(subsystem: "com.invoicing.compliance", category: "InvoiceEditor")
    private static let complianceBlockerDowngradeKey = "debug.compliance.downgradeBlockersToWarnings"
    
    // Template dependencies for PDF export
    let sharingService: InvoiceSharingService
    
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
    @Published var status: String = AppConstants.invoiceStatusReviewDraft
    @Published var paidDate: Date?
    @Published var sentDate: Date?
    
    // Billing Information
    @Published var billingAuthority: String?
    @Published var billToName: String?
    @Published var billToEmail: String?

    @Published var billToAddress: String?
    
    // Stable ID for temporary addresses created from strings
    private let temporaryAddressId = UUID()
    
    // Billing Selection Logic
    enum BillingSelection: String, CaseIterable, Identifiable {
        case client = "Client"
        case payee = "Payee"
        case planManager = "Plan Manager"
        var id: String { self.rawValue }
    }
    
    @Published var billingSelection: BillingSelection = .client {
        didSet {
            // Auto-populate when selection mode changes
            applyBillingSelection()
        }
    }
    
    @Published var selectedPayeeId: UUID? {
        didSet {
            // Auto-populate when payee is selected
            if billingSelection == .payee {
                applyPayeeBilling(payeeId: selectedPayeeId)
            }
        }
    }
    
    @Published var selectedPlanManagerId: UUID? {
        didSet {
            // Auto-populate when plan manager is selected
            if billingSelection == .planManager {
                applyPlanManagerBilling(planManagerId: selectedPlanManagerId)
            }
        }
    }
    
    @Published var allPayees: [Payee] = []
    @Published var allPlanManagers: [PlanManager] = []
    
    // Client selection properties
    @Published var selectedClientId: UUID? {
        didSet {
            Task { await fetchSelectedClient() }
        }
    }
    @Published var selectedClient: Client?
    @Published var allClients: [Client] = []
    
    // Template Management
    let templateManager = TemplateManager()
    @Published var availableTemplates: [TemplateMetadata] = []
    @Published var selectedTemplateId: UUID?
    
    let isNewInvoice: Bool
    private var emailSharingService: NSSharingService?
    private var emailSharingDelegate: EmailSharingDelegate?

    // Callback for when invoice is deleted
    var onInvoiceDeleted: (() -> Void)?
    
    @Published public var isLoading: Bool = false
    @Published var complianceStatusMessage: String?
    @Published var complianceStatusIsBlocker: Bool = false

    init(
        invoicesRepository: InvoicesRepository,
        clientServicesRepository: ClientServicesRepository,
        clientsRepository: ClientsRepository,
        payeesRepository: PayeeRepository,
        planManagersRepository: PlanManagerRepository,
        sharingService: InvoiceSharingService,
        invoice existingInvoice: Invoice,
        isNew: Bool,
        complianceValidator: NDISComplianceValidator? = nil,
        complianceBlockingEnabled: Bool = true
    ) {
        self.invoicesRepository = invoicesRepository
        self.clientServicesRepository = clientServicesRepository
        self.clientsRepository = clientsRepository
        self.payeesRepository = payeesRepository
        self.planManagersRepository = planManagersRepository
        self.complianceValidator = complianceValidator
        self.complianceBlockingEnabled = complianceBlockingEnabled
        self.sharingService = sharingService
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
        self.paidDate = existingInvoice.paidDate
        self.sentDate = existingInvoice.sentDate
        
        self.billingAuthority = existingInvoice.billingAuthority
        self.billToName = existingInvoice.billToName
        self.billToEmail = existingInvoice.billToEmail
        self.billToAddress = existingInvoice.billToAddress?.fullFormattedAddress
        
        self.billToAddress = existingInvoice.billToAddress?.fullFormattedAddress
        
        // Initialize template selection
        self.selectedTemplateId = existingInvoice.templateId
        
        // Load invoice items and clients
        Task {
            await MainActor.run { self.isLoading = true }
            defer { Task { @MainActor in self.isLoading = false } }
            
            await loadTemplates()
            await loadInvoiceItems()
            await fetchAllClients()
            await fetchAllPayees()
            await fetchAllPlanManagers()
            await fetchSelectedClient()
        }
    }
    
    // MARK: - Billing Logic
    
    private func fetchAllPayees() async {
        do {
            allPayees = try await payeesRepository.fetchAll()
        } catch {
            print("❌ [InvoiceEditorViewModel] Error fetching payees: \(error)")
            allPayees = []
        }
    }
    
    private func fetchAllPlanManagers() async {
        do {
            allPlanManagers = try await planManagersRepository.fetchAll()
        } catch {
            print("❌ [InvoiceEditorViewModel] Error fetching plan managers: \(error)")
            allPlanManagers = []
        }
    }
    
    private func applyBillingSelection() {
        switch billingSelection {
        case .client:
            applyClientBilling()
        case .payee:
            // If we already have a selected payee, refresh fields.
            // If not, we might select the client's default payee if available.
            if let id = selectedPayeeId {
                applyPayeeBilling(payeeId: id)
            } else if let client = selectedClient, let clientPayee = client.payee {
                selectedPayeeId = clientPayee.id
                // didSet will trigger applyPayee
            }
        case .planManager:
            // Similar logic for Plan Manager
            if let id = selectedPlanManagerId {
                applyPlanManagerBilling(planManagerId: id)
            } else if let client = selectedClient, let clientPM = client.planManager {
                selectedPlanManagerId = clientPM.id
                // didSet will trigger applyPlanManager
            }
        }
    }
    
    private func applyClientBilling() {
        guard let client = selectedClient else { return }
        billingAuthority = "Client"
        billToName = client.fullName
        billToEmail = client.email
        billToAddress = client.address?.fullFormattedAddress
    }
    
    private func applyPayeeBilling(payeeId: UUID?) {
        guard let id = payeeId, let payee = allPayees.first(where: { $0.id == id }) else { return }
        billingAuthority = "Parent/Guardian"
        billToName = payee.fullName
        billToEmail = payee.email
        billToAddress = payee.address?.fullFormattedAddress
    }
    
    private func applyPlanManagerBilling(planManagerId: UUID?) {
        guard let id = planManagerId, let pm = allPlanManagers.first(where: { $0.id == id }) else { return }
        billingAuthority = "Plan Manager"
        billToName = pm.name
        billToEmail = pm.email
        billToAddress = pm.address?.fullFormattedAddress
    }
    
    func onClientChanged(to clientId: UUID?) {
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

    private func loadInvoiceItems() async {
        do {
            invoiceItems = try await invoicesRepository.fetchItems(by: invoice.id)
        } catch {
            print("❌ [InvoiceEditorViewModel] Error loading invoice items: \(error)")
            invoiceItems = []
        }
    }

    private func loadTemplates() async {
        availableTemplates = await templateManager.browseTemplates()
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

    // MARK: - Live Preview Snapshot
    var currentInvoiceSnapshot: Invoice {
        var snapshot = invoice
        snapshot.invoiceNumber = invoiceNumber
        snapshot.issueDate = issueDate
        snapshot.dueDate = dueDate
        snapshot.paymentTerms = paymentTerms
        snapshot.notes = notes
        snapshot.discount = discount
        snapshot.taxRate = taxRate
        snapshot.creditApplied = creditApplied
        snapshot.currencyCode = currencyCode
        snapshot.status = status
        snapshot.templateId = selectedTemplateId

        snapshot.billingAuthority = billingAuthority
        snapshot.billToName = billToName
        snapshot.billToEmail = billToEmail
        snapshot.billToAddress = invoice.billToAddress ?? (billToAddress != nil ? Address(id: temporaryAddressId, streetName: billToAddress!) : nil)

        if let client = selectedClient {
            snapshot.clientId = client.id
            snapshot.clientName = client.fullName
            snapshot.clientEmail = client.email
            snapshot.clientAddress = client.address
            snapshot.clientNDISNumber = client.ndisNumber
        } else {
            snapshot.clientId = nil
            snapshot.clientName = nil
            snapshot.clientEmail = nil
            snapshot.clientAddress = nil
            snapshot.clientNDISNumber = nil
        }

        return snapshot
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

        invoiceItems.remove(atOffsets: offsets)

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
                await loadInvoiceItems()
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
            if billingSelection == .client {
                applyClientBilling()
            }
        } catch {
            print("❌ [InvoiceEditorViewModel] Error fetching selected client: \(error)")
            selectedClient = nil
        }
    }

    func applyMaxClientCredit() {
        guard let client = selectedClient else { return }
        creditApplied = min(client.creditAmount, calculatedTotal)
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
            guard selectedClientId != nil else {
                completion(false, "Please select a client before saving the invoice.")
                return
            }
            guard !invoiceItems.isEmpty else {
                completion(false, "Please add at least one line item before saving.")
                return
            }
            if let due = dueDate, due < issueDate {
                completion(false, "Due date cannot be before the issue date.")
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
                    paidDate: paidDate,
                    paymentTerms: paymentTerms,
                    status: status,
                    sentDate: sentDate,
                    currencyCode: currencyCode,
                    // Preserve snapshot data from original invoice
                    businessName: invoice.businessName,
                    businessABN: invoice.businessABN,
                    businessEmail: invoice.businessEmail,
                    businessAddress: invoice.businessAddress,
                    businessPhone: invoice.businessPhone,
                    clientName: selectedClient?.fullName ?? invoice.clientName,
                    clientNDISNumber: selectedClient?.ndisNumber ?? invoice.clientNDISNumber,
                    clientEmail: selectedClient?.email ?? invoice.clientEmail,
                    clientPhone: selectedClient?.phone ?? invoice.clientPhone,
                    clientAddress: selectedClient?.address ?? invoice.clientAddress,
                    billingAuthority: billingAuthority,
                    billToName: billToName,
                    billToEmail: billToEmail,
                    billToAddress: invoice.billToAddress ?? (invoice.billToAddress == nil && billToAddress != nil ? Address(id: temporaryAddressId, streetName: billToAddress ?? "") : nil),
                    // Note: Ideally billToAddress in VM should be an Address struct, but currently it's a String (formatted).
                    // We might lose granularity here if the user edits the string directly.
                    // For now, we preserve the original if available, or create a simple one from the string.
                    payeeName: invoice.payeeName,
                    payeeEmail: invoice.payeeEmail,
                    payeePhone: invoice.payeePhone,
                    payeeAddress: invoice.payeeAddress,
                    bankName: invoice.bankName,
                    bankAccountName: invoice.bankAccountName,
                    bankBSB: invoice.bankBSB,
                    bankAccountNumber: invoice.bankAccountNumber,
                    clientId: selectedClientId,
                    businessId: invoice.businessId,
                    payeeId: invoice.payeeId,
                    templateId: selectedTemplateId,
                    sessionIds: invoice.sessionIds
                )
                
                // Save invoice
                let savedInvoice = isNewInvoice 
                    ? try await invoicesRepository.create(updatedInvoice)
                    : try await invoicesRepository.update(updatedInvoice)

                let existingItemIDs = Set(try await invoicesRepository.fetchItems(by: savedInvoice.id).map(\.id))
                
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
                        position: Int32(index),
                        serviceDate: item.serviceDate,
                        ndisItemNumber: item.ndisItemNumber,
                        claimType: item.claimType,
                        unit: item.unit,
                        gstCode: item.gstCode
                    )
                    
                    if existingItemIDs.contains(itemWithPosition.id) {
                        _ = try await invoicesRepository.updateItem(itemWithPosition)
                    } else {
                        _ = try await invoicesRepository.addItem(itemWithPosition)
                    }
                }
                
                // Update local invoice reference
                self.invoice = savedInvoice
                await loadInvoiceItems()
                InvoiceChangePublisher.shared.notifyChange(invoiceId: savedInvoice.id)
                
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
                InvoiceChangePublisher.shared.notifyRefreshNeeded()
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
                try await invoicesRepository.updateStatus(id: invoice.id, status: AppConstants.invoiceStatusVoided)
                InvoiceChangePublisher.shared.notifyChange(invoiceId: invoice.id)
            } catch {
                print("❌ [InvoiceEditorViewModel] Error voiding invoice: \(error)")
            }
        }
    }

    func createCreditNote(from amount: Double, notes: String? = nil) {
        guard amount > 0, let clientId = invoice.clientId else { return }
        Task {
            do {
                guard let client = try await clientsRepository.fetch(by: clientId) else {
                    print("❌ [InvoiceEditorViewModel] Unable to create credit note: client not found")
                    return
                }

                // Increase the client's available credit balance.
                let updatedClient = Client(
                    id: client.id,
                    ndisNumber: client.ndisNumber,
                    fullName: client.fullName,
                    status: client.status,
                    email: client.email,
                    notes: client.notes,
                    phone: client.phone,
                    creditAmount: client.creditAmount + amount,
                    isMinor: client.isMinor,
                    hasNdisPlan: client.hasNdisPlan,
                    planManagementType: client.planManagementType,
                    billingAuthority: client.billingAuthority,
                    address: client.address,
                    planManager: client.planManager,
                    payee: client.payee,
                    sendInvoicesToClient: client.sendInvoicesToClient,
                    sendInvoicesToPayee: client.sendInvoicesToPayee,
                    sendInvoicesToPlanManager: client.sendInvoicesToPlanManager
                )
                _ = try await clientsRepository.update(updatedClient)

                let creditNoteNumber = try await invoicesRepository.generateInvoiceNumber()
                let now = Date()
                let creditNote = Invoice(
                    id: UUID(),
                    invoiceNumber: creditNoteNumber,
                    totalAmount: -amount,
                    taxRate: 0.0,
                    creditApplied: 0.0,
                    discount: 0.0,
                    date: now,
                    dueDate: now,
                    issueDate: now,
                    notes: notes,
                    paidDate: now,
                    paymentTerms: "Credit note",
                    status: AppConstants.invoiceStatusReceived,
                    sentDate: now,
                    currencyCode: currencyCode,
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
                    clientId: clientId,
                    businessId: invoice.businessId,
                    payeeId: invoice.payeeId,
                    templateId: invoice.templateId,
                    sessionIds: []
                )

                let createdCreditNote = try await invoicesRepository.create(creditNote)
                let lineItem = InvoiceItem(
                    id: UUID(),
                    invoiceId: createdCreditNote.id,
                    itemDescription: "Credit note for invoice \(invoice.invoiceNumber)",
                    quantity: 1,
                    rate: -amount,
                    position: 0,
                    serviceDate: now
                )
                _ = try await invoicesRepository.addItem(lineItem)
                await fetchSelectedClient()
                InvoiceChangePublisher.shared.notifyRefreshNeeded()

                print("✅ [InvoiceEditorViewModel] Created credit note \(createdCreditNote.invoiceNumber) for \(amount)")
            } catch {
                print("❌ [InvoiceEditorViewModel] Failed to create credit note: \(error)")
            }
        }
    }

    // MARK: - Quick Status Actions
    
    /// Mark the invoice as sent and save
    func markAsSent() {
        Task { @MainActor in
            if let validation = await validateInvoiceTransitionIfNeeded(
                targetStatus: AppConstants.invoiceStatusPending,
                action: .sendInvoice
            ) {
                if validation.isBlocked {
                    applyComplianceMessage(blockerSummary(for: validation), isBlocker: true)
                    return
                }
                if !validation.warnings.isEmpty {
                    applyComplianceMessage(warningSummary(for: validation), isBlocker: false)
                }
            }

            status = AppConstants.invoiceStatusPending
            sentDate = Date()
            saveInvoice { success, _ in
                if success {
                    print("✅ [InvoiceEditorViewModel] Invoice marked as sent")
                }
            }
        }
    }
    
    /// Mark the invoice as paid and save
    func markAsPaid() {
        Task { @MainActor in
            if let validation = await validateInvoiceTransitionIfNeeded(
                targetStatus: AppConstants.invoiceStatusReceived,
                action: .markPaid
            ) {
                if validation.isBlocked {
                    applyComplianceMessage(blockerSummary(for: validation), isBlocker: true)
                    return
                }
                if !validation.warnings.isEmpty {
                    applyComplianceMessage(warningSummary(for: validation), isBlocker: false)
                }
            }

            status = AppConstants.invoiceStatusReceived
            paidDate = Date()
            saveInvoice { success, _ in
                if success {
                    print("✅ [InvoiceEditorViewModel] Invoice marked as paid")
                }
            }
        }
    }
    
    /// Check if invoice can be marked as sent (must not be draft with no client/items)
    var canMarkAsSent: Bool {
        selectedClientId != nil
            && !invoiceItems.isEmpty
            && status != AppConstants.invoiceStatusPending
            && status != AppConstants.invoiceStatusReceived
    }
    
    /// Check if invoice can be marked as paid
    var canMarkAsPaid: Bool {
        selectedClientId != nil
            && !invoiceItems.isEmpty
            && status != AppConstants.invoiceStatusReceived
    }

    // MARK: - Printing and Exporting
    @MainActor
    func exportInvoiceToPDF() {
        Task {
            guard let pdfData = await sharingService.renderPDFData(
                invoice: invoice,
                invoiceItems: invoiceItems
            ) else {
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

    // MARK: - Sharing
    @MainActor
    func generateTemporaryPDFFileURLForSharing() async -> URL? {
        return await sharingService.temporaryPDFURL(
            invoice: invoice,
            invoiceItems: invoiceItems
        )
    }

    func shareBodyText() -> String {
        "Please find attached your invoice \(invoice.invoiceNumber)."
    }

    @MainActor
    func itemProviderForPDFSharing() async -> NSItemProvider? {
        return await sharingService.pdfItemProvider(
            invoice: invoice,
            invoiceItems: invoiceItems
        )
    }

    @MainActor
    func sendInvoiceViaEmail() {
        Task {
            guard let pdfData = await sharingService.renderPDFData(
                invoice: invoice,
                invoiceItems: invoiceItems
            ) else {
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
            let ccRecipients: [(email: String, name: String)] = []

            // Use snapshot data from domain model
            let billToEmail = invoice.billToEmail
            let billToName = invoice.billToName
            let clientEmail = invoice.clientEmail
            let clientName = invoice.clientName
            let payeeEmail = invoice.payeeEmail
            let payeeName = invoice.payeeName
            
            // Determine primary recipient based on billing authority
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
                        if self.status != AppConstants.invoiceStatusPending
                            && self.status != AppConstants.invoiceStatusReceived {
                            if let validation = await self.validateInvoiceTransitionIfNeeded(
                                targetStatus: AppConstants.invoiceStatusPending,
                                action: .sendInvoice
                            ) {
                                if validation.isBlocked {
                                    self.applyComplianceMessage(self.blockerSummary(for: validation), isBlocker: true)
                                    return
                                }
                                if !validation.warnings.isEmpty {
                                    self.applyComplianceMessage(self.warningSummary(for: validation), isBlocker: false)
                                }
                            }
                            try? await self.invoicesRepository.updateStatus(id: self.invoice.id, status: AppConstants.invoiceStatusPending)
                            // Reload invoice to get updated sentDate
                            if let updatedInvoice = try? await self.invoicesRepository.fetch(by: self.invoice.id) {
                                self.invoice = updatedInvoice
                            }
                            InvoiceChangePublisher.shared.notifyChange(invoiceId: self.invoice.id)
                        }
                    }
                }
                self.emailSharingDelegate = delegate
                service.delegate = delegate
                // Include body text and file URL to ensure the attachment is honored across mail clients
                service.perform(withItems: [body as NSString, pdfFileURL as NSURL])
            }
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
            address: invoice.businessAddress?.fullFormattedAddress,
            phone: invoice.businessPhone
        )
    }

    private func validateInvoiceTransitionIfNeeded(
        targetStatus: String,
        action: ComplianceAction
    ) async -> ComplianceValidationResult? {
        guard complianceBlockingEnabled, let complianceValidator else { return nil }
        guard isForwardInvoiceTransition(from: status, to: targetStatus) else { return nil }
        do {
            let result = try await complianceValidator.validateInvoiceTransition(
                invoiceId: invoice.id,
                action: action,
                targetStatus: targetStatus
            )
            let adjustedResult = applyDebugBlockerDowngradeIfNeeded(
                result,
                action: action,
                targetStatus: targetStatus
            )
            logComplianceValidationResult(adjustedResult, action: action, targetStatus: targetStatus)
            return adjustedResult
        } catch {
            complianceLogger.error(
                "validation_failed action=\(action.rawValue, privacy: .public) invoice_id=\(self.invoice.id.uuidString, privacy: .public) target_status=\(targetStatus, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
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

    private func applyComplianceMessage(_ message: String, isBlocker: Bool) {
        complianceStatusMessage = message
        complianceStatusIsBlocker = isBlocker
    }

    private func blockerSummary(for result: ComplianceValidationResult) -> String {
        let messages = result.blockers.prefix(2).map(\.message).joined(separator: " ")
        return "Blocked by compliance (\(result.blockers.count)): \(messages)"
    }

    private func warningSummary(for result: ComplianceValidationResult) -> String {
        let messages = result.warnings.prefix(2).map(\.message).joined(separator: " ")
        return "Compliance warnings (\(result.warnings.count)): \(messages)"
    }

    private var complianceBlockerDowngradeEnabled: Bool {
#if DEBUG
        UserDefaults.standard.bool(forKey: Self.complianceBlockerDowngradeKey)
#else
        false
#endif
    }

    private func applyDebugBlockerDowngradeIfNeeded(
        _ result: ComplianceValidationResult,
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
            "debug_downgrade_enabled action=\(action.rawValue, privacy: .public) invoice_id=\(self.invoice.id.uuidString, privacy: .public) target_status=\(targetStatus, privacy: .public) downgraded_blocker_count=\(result.blockers.count, privacy: .public)"
        )
        return ComplianceValidationResult(
            warnings: result.warnings + downgradedWarnings,
            blockers: []
        )
    }

    private func logComplianceValidationResult(
        _ result: ComplianceValidationResult,
        action: ComplianceAction,
        targetStatus: String
    ) {
        if !result.blockers.isEmpty {
            let ruleIds = result.blockers.map(\.id).joined(separator: ",")
            let issueEntityIds = result.blockers.compactMap(\.entityId).map(\.uuidString).joined(separator: ",")
            complianceLogger.error(
                "block_event action=\(action.rawValue, privacy: .public) invoice_id=\(self.invoice.id.uuidString, privacy: .public) target_status=\(targetStatus, privacy: .public) blocker_count=\(result.blockers.count, privacy: .public) rule_ids=\(ruleIds, privacy: .public) issue_entity_ids=\(issueEntityIds, privacy: .public)"
            )
        }

        if !result.warnings.isEmpty {
            let ruleIds = result.warnings.map(\.id).joined(separator: ",")
            complianceLogger.info(
                "warning_event action=\(action.rawValue, privacy: .public) invoice_id=\(self.invoice.id.uuidString, privacy: .public) target_status=\(targetStatus, privacy: .public) warning_count=\(result.warnings.count, privacy: .public) rule_ids=\(ruleIds, privacy: .public)"
            )
        }
    }

    private func isForwardInvoiceTransition(from current: String, to target: String) -> Bool {
        guard let currentRank = workflowRank(for: current),
              let targetRank = workflowRank(for: target) else {
            return false
        }
        return targetRank > currentRank
    }

    private func workflowRank(for status: String) -> Int? {
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
    /// Print the current invoice using template-based PDF rendering
    func printInvoice() {
        Task { @MainActor in
            guard let pdfData = await sharingService.renderPDFData(
                invoice: invoice,
                invoiceItems: invoiceItems
            ) else {
                print("❌ [InvoiceEditorViewModel] Failed to generate PDF for printing")
                return
            }
            
            // Write PDF to temporary file for printing
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Invoice-\(invoice.invoiceNumber)-print.pdf")
            do {
                try pdfData.write(to: tempURL)
            } catch {
                print("❌ [InvoiceEditorViewModel] Failed to write PDF for printing: \(error)")
                return
            }
            
            // Create PDF document and view for printing
            guard let pdfDocument = PDFDocument(url: tempURL) else {
                print("❌ [InvoiceEditorViewModel] Failed to create PDF document")
                return
            }
            
            let pdfView = PDFView()
            pdfView.document = pdfDocument
            pdfView.autoScales = true
            
            // Print the PDF view
            pdfView.print(with: NSPrintInfo.shared, autoRotate: true)
        }
    }
}
