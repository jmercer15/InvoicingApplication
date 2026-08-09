import Core
import PersistenceModels
import Foundation
import SwiftData

enum InvoiceModelError: LocalizedError, Equatable {
    case invoiceNotFound
    case revisionConflict
    case invalidDraft
    case persistenceUnavailable

    var errorDescription: String? {
        switch self {
        case .invoiceNotFound:
            "The invoice no longer exists."
        case .revisionConflict:
            "This invoice changed in another window. Your draft was not overwritten."
        case .invalidDraft:
            "The invoice draft contains validation errors."
        case .persistenceUnavailable:
            "Invoice persistence is unavailable in this workspace."
        }
    }
}

/// Persistence adapter for invoice editor. Uses app-owned Core models and container;
/// editor-specific types never enter SwiftData schema.
@ModelActor
actor InvoiceModelActor {
    struct UpdateResult {
        let validation: InvoiceValidation.Result
        let savedSnapshot: InvoiceSnapshot?

        var isValid: Bool { validation.isValid }
        var errors: [String] { validation.errors }
    }

    func invoiceCount() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<Invoice>())
    }

    func fetchInvoice(id: UUID) throws -> InvoiceSnapshot? {
        guard let invoice = try fetchInvoiceModel(id: id) else { return nil }
        return InvoiceSnapshot(coreInvoice: invoice)
    }

    func fetchClientOptions() throws -> [InvoiceClientOption] {
        var descriptor = FetchDescriptor<Client>(
            sortBy: [SortDescriptor(\Client.fullName, order: .forward)]
        )
        descriptor.relationshipKeyPathsForPrefetching = [\.address, \.payee, \.planManager]
        return try modelContext.fetch(descriptor).map(InvoiceClientOption.init)
    }

    func createInvoice(
        defaults: InvoiceCreationDefaults,
        templateDefaults: InvoiceTemplateDefaults
    ) throws -> UUID {
        let number = defaults.autoGeneratesInvoiceNumbers
            ? InvoiceNumberGenerator.nextNumber(existingNumbers: try existingNumbers())
            : ""
        let invoice = Invoice(invoiceNumber: number)
        invoice.issueDate = .now
        invoice.date = invoice.issueDate
        invoice.dueDate = Calendar.current.date(
            byAdding: .day,
            value: defaults.paymentTermsDays,
            to: invoice.issueDate
        )
        invoice.taxRate = Decimal(defaults.taxRate)
        invoice.paymentTerms = defaults.paymentTermsText.nilIfEmpty
        invoice.notes = defaults.notes.nilIfEmpty
        invoice.effectiveStatus = .reviewDraft
        modelContext.insert(invoice)

        let item = InvoiceItem(itemDescription: "")
        item.position = 0
        item.quantity = 1
        item.taxRate = Decimal(defaults.taxRate)
        item.invoice = invoice
        modelContext.insert(item)
        invoice.items = [item]
        invoice.invoiceEditorStateData = try InvoiceDocumentConfigurationEnvelope(
            shared: defaults.editorConfiguration,
            paperSize: templateDefaults.paperSize,
            pageOrientation: templateDefaults.pageOrientation,
            template: templateDefaults.configuration
        ).encoded()

        try saveChangesOrRollback()
        return invoice.id
    }

    func createInvoice(from sourceDraft: InvoiceDraft) throws -> UUID {
        guard InvoiceValidation.validate(draft: sourceDraft).isValid else {
            throw InvoiceModelError.invalidDraft
        }

        var draft = sourceDraft
        draft.lineItems = sourceDraft.lineItems.enumerated().map { index, item in
            item.duplicated(sortOrder: index)
        }
        let number = InvoiceNumberGenerator.nextNumber(
            existingNumbers: try existingNumbers(),
            issueDate: draft.issueDate
        )
        draft.invoiceNumber = number
        let invoice = Invoice(invoiceNumber: number)
        modelContext.insert(invoice)
        try apply(draft, to: invoice)
        syncLineItems(invoice: invoice, snapshots: draft.lineItems)
        try saveChangesOrRollback()
        return invoice.id
    }

    func duplicateInvoice(id: UUID) throws -> UUID {
        guard let source = try fetchInvoiceModel(id: id) else {
            throw InvoiceModelError.invoiceNotFound
        }

        var draft = InvoiceDraft(InvoiceSnapshot(coreInvoice: source))
        let issueDate = Date.now
        draft.title = "\(draft.title) (Copy)"
        draft.status = .draft
        draft.issueDate = issueDate
        draft.dueDate = Calendar.current.date(byAdding: .day, value: 30, to: issueDate) ?? issueDate
        draft.lineItems = draft.lineItems.enumerated().map { index, item in
            item.duplicated(sortOrder: index)
        }

        let number = InvoiceNumberGenerator.nextNumber(existingNumbers: try existingNumbers())
        draft.invoiceNumber = number
        let copy = Invoice(invoiceNumber: number)
        modelContext.insert(copy)
        try apply(draft, to: copy)
        syncLineItems(invoice: copy, snapshots: draft.lineItems)
        try saveChangesOrRollback()
        return copy.id
    }

    func deleteInvoice(id: UUID, expectedRevision: Int) throws {
        guard let invoice = try fetchInvoiceModel(id: id) else {
            throw InvoiceModelError.invoiceNotFound
        }
        guard invoice.invoiceEditorRevision == expectedRevision else {
            throw InvoiceModelError.revisionConflict
        }
        modelContext.delete(invoice)
        try saveChangesOrRollback()
    }

    func updateInvoice(
        id: UUID,
        expectedRevision: Int,
        draft: InvoiceDraft
    ) throws -> UpdateResult {
        guard let invoice = try fetchInvoiceModel(id: id) else {
            throw InvoiceModelError.invoiceNotFound
        }

        let validation = InvoiceValidation.validate(draft: draft)
        guard validation.isValid else {
            return UpdateResult(validation: validation, savedSnapshot: nil)
        }
        if try invoiceNumberExists(draft.invoiceNumber, excluding: id) {
            return UpdateResult(
                validation: InvoiceValidation.Result(
                    isValid: false,
                    errors: ["Invoice number must be unique."]
                ),
                savedSnapshot: nil
            )
        }
        guard invoice.invoiceEditorRevision == expectedRevision else {
            throw InvoiceModelError.revisionConflict
        }

        try apply(draft, to: invoice)
        syncLineItems(invoice: invoice, snapshots: draft.lineItems)
        invoice.markContentChanged()
        try saveChangesOrRollback()
        return UpdateResult(
            validation: validation,
            savedSnapshot: InvoiceSnapshot(coreInvoice: invoice)
        )
    }

    func saveChangesOrRollback() throws {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func existingNumbers() throws -> [String] {
        try modelContext.fetch(FetchDescriptor<Invoice>()).map(\.invoiceNumber)
    }

    private func invoiceNumberExists(_ number: String, excluding id: UUID) throws -> Bool {
        let normalized = number.trimmingCharacters(in: .whitespacesAndNewlines)
        return try modelContext.fetch(FetchDescriptor<Invoice>()).contains { invoice in
            invoice.id != id && invoice.invoiceNumber.caseInsensitiveCompare(normalized) == .orderedSame
        }
    }

    private func fetchInvoiceModel(id: UUID) throws -> Invoice? {
        var descriptor = FetchDescriptor<Invoice>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        descriptor.relationshipKeyPathsForPrefetching = [\.items]
        return try modelContext.fetch(descriptor).first
    }

    private func fetchClientModel(id: UUID?) throws -> Client? {
        guard let id else { return nil }
        var descriptor = FetchDescriptor<Client>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    private func apply(_ draft: InvoiceDraft, to invoice: Invoice) throws {
        invoice.client = try fetchClientModel(id: draft.clientID)
        invoice.payee = draft.billing.authority == Core.BillingAuthority.parentGuardian.rawValue
            ? invoice.client?.payee
            : nil
        invoice.invoiceNumber = draft.invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        invoice.date = draft.issueDate
        invoice.issueDate = draft.issueDate
        invoice.dueDate = draft.dueDate
        let previousStatus = invoice.effectiveStatus
        let nextStatus = draft.status.coreStatus
        invoice.effectiveStatus = nextStatus
        if previousStatus != nextStatus {
            applyStatusDates(for: nextStatus, to: invoice)
        }
        invoice.currencyCode = InvoiceCurrencyCode.normalizedOrDefault(draft.currencyCode)
        invoice.taxRate = draft.defaultTaxRate
        invoice.paymentTerms = draft.paymentTerms.nilIfEmpty
        invoice.notes = draft.notes.nilIfEmpty
        invoice.discount = draft.adjustments.discountPercent
        invoice.creditApplied = draft.adjustments.creditApplied

        invoice.businessName = draft.seller.name.nilIfEmpty
        invoice.businessAddressSnapshot = addressSnapshot(draft.seller.address)
        invoice.businessEmail = draft.seller.email.nilIfEmpty
        invoice.businessPhone = draft.seller.phone.nilIfEmpty
        invoice.businessABN = draft.seller.taxID.nilIfEmpty

        invoice.billingAuthority = InvoiceBillingAuthorityResolution.resolve(
            rawValue: draft.billing.authority,
            billsParticipantDirectly: draft.billing.billsParticipantDirectly
        )
        invoice.billToName = draft.billing.recipient.name.nilIfEmpty
        invoice.billToAddressSnapshot = addressSnapshot(draft.billing.recipient.address)
        invoice.billToEmail = draft.billing.recipient.email.nilIfEmpty

        invoice.clientName = draft.client.name.nilIfEmpty
        invoice.clientAddressSnapshot = addressSnapshot(draft.client.address)
        invoice.clientEmail = draft.client.email.nilIfEmpty
        invoice.clientPhone = draft.client.phone.nilIfEmpty
        invoice.clientNDISNumber = draft.client.taxID.nilIfEmpty

        invoice.bankName = draft.payment.bankName.nilIfEmpty
        invoice.bankAccountName = draft.payment.accountName.nilIfEmpty
        invoice.bankBSB = draft.payment.bsb.nilIfEmpty
        invoice.bankAccountNumber = draft.payment.accountNumber.nilIfEmpty

        let totals = InvoiceCalculations.invoiceTotals(
            lineItems: draft.lineItems.map(\.calculationInput),
            discountAmount: draft.adjustments.discountAmount,
            discountPercent: draft.adjustments.discountPercent,
            creditApplied: draft.adjustments.creditApplied
        )
        invoice.totalAmount = totals.grandTotal
        invoice.invoiceEditorStateData = try InvoiceDocumentConfigurationEnvelope(
            title: draft.title,
            billParticipantDirectly: draft.billing.billsParticipantDirectly,
            billToPhone: draft.billing.recipient.phone,
            discountAmount: draft.adjustments.discountAmount,
            showsTaxSummary: draft.showsTaxSummary,
            paperSize: draft.paperSize,
            pageOrientation: draft.pageOrientation,
            template: draft.template
        ).encoded()
    }

    private func syncLineItems(invoice: Invoice, snapshots: [InvoiceLineItemSnapshot]) {
        var existing: [UUID: InvoiceItem] = [:]
        for item in invoice.items ?? [] {
            if existing[item.id] == nil {
                existing[item.id] = item
            } else {
                modelContext.delete(item)
            }
        }

        var retained = Set<UUID>()
        var ordered: [InvoiceItem] = []
        for (index, snapshot) in snapshots.enumerated() {
            let item = existing[snapshot.id] ?? InvoiceItem(
                id: snapshot.id,
                itemDescription: snapshot.itemDescription
            )
            item.position = Int32(index)
            item.itemDescription = snapshot.itemDescription
            item.serviceDate = snapshot.serviceDate
            item.ndisItemNumber = snapshot.itemCode.nilIfEmpty
            item.quantity = snapshot.quantity
            item.unit = snapshot.unit.nilIfEmpty
            item.rate = snapshot.unitPrice
            item.taxRate = snapshot.taxRate
            item.gstCode = snapshot.gstCode.nilIfEmpty
            item.invoice = invoice
            // Preserve NDIS lineage when the editor snapshot carries it (create, update, duplicate).
            if let claimType = snapshot.claimType {
                item.claimType = claimType
            }
            if let sessionID = snapshot.sessionID,
               let session = fetchSessionModel(id: sessionID) {
                item.session = session
            }
            if let clientServiceID = snapshot.clientServiceID,
               let clientService = fetchClientServiceModel(id: clientServiceID) {
                item.clientService = clientService
            }
            if existing[snapshot.id] == nil { modelContext.insert(item) }
            retained.insert(snapshot.id)
            ordered.append(item)
        }

        for item in invoice.items ?? [] where !retained.contains(item.id) {
            modelContext.delete(item)
        }
        invoice.items = ordered
    }

    private func fetchSessionModel(id: UUID) -> Session? {
        var descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func fetchClientServiceModel(id: UUID) -> ClientService? {
        var descriptor = FetchDescriptor<ClientService>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    private func applyStatusDates(for status: Core.InvoiceStatus, to invoice: Invoice) {
        switch status {
        case .reviewDraft:
            invoice.sentDate = nil
            invoice.paidDate = nil
        case .readyToSend:
            invoice.paidDate = nil
        case .pending:
            invoice.sentDate = invoice.sentDate ?? .now
            invoice.paidDate = nil
        case .received:
            invoice.sentDate = invoice.sentDate ?? .now
            invoice.paidDate = invoice.paidDate ?? .now
        case .overdue, .cancelled, .voided:
            break
        }
    }

    private func addressSnapshot(_ rawValue: String) -> Core.AddressSnapshot? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        return Core.AddressSnapshot(
            id: UUID(), country: "", postcode: "", state: "", streetName: "",
            streetNumber: "", city: "", suburb: "", unitNumber: "", poBox: "",
            fullAddressText: value, latitude: 0, longitude: 0
        )
    }
}

private extension Decimal {
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}

private extension String {
    var nilIfEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
