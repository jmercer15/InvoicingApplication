import Foundation
import Core
import PersistenceModels
import SwiftData

/// Snapshot-based Data-layer implementation of `ComplianceValidating`, running on a SwiftData `ModelActor`
/// executor so validation work does not share the UI `ModelContext`.
public actor NDISComplianceValidator: ComplianceValidating, ModelActor {
    nonisolated public let modelContainer: ModelContainer
    nonisolated public let modelExecutor: any ModelExecutor

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    }

    // MARK: - ComplianceValidating

    public func validateInvoiceTransition(
        invoiceId: UUID,
        action: ComplianceAction,
        targetStatus: String?
    ) async throws -> ComplianceValidationResult {
        _ = action
        _ = targetStatus

        var warnings: [ComplianceIssue] = []
        var blockers: [ComplianceIssue] = []

        try await validateBusiness(&warnings, &blockers)

        guard let invoice = try fetchInvoice(by: invoiceId) else {
            blockers.append(
                ComplianceIssue(
                    id: "invoice.not_found",
                    severity: .blocker,
                    message: "Invoice not found.",
                    entityID: invoiceId
                )
            )
            return ComplianceValidationResult(warnings: warnings, blockers: blockers)
        }

        let items = try fetchInvoiceItems(invoiceId: invoice.id)
        validateInvoiceItems(items, invoiceId: invoice.id, &warnings, &blockers)

        if action == .sendInvoice || action == .exportInvoice {
            let business = try fetchFirstBusiness()
            applyNDISExportValidation(
                invoice: invoice,
                items: items,
                business: business,
                strict: true,
                warnings: &warnings,
                blockers: &blockers
            )
        }

        let sessions = try await fetchLinkedSessions(invoice: invoice, invoiceItems: items)
        try await validateSessionsAndAgreements(
            sessions: sessions,
            invoiceItems: items,
            warnings: &warnings,
            blockers: &blockers
        )

        return ComplianceValidationResult(warnings: warnings, blockers: blockers)
    }

    public func validateBulkInvoices(
        invoiceIds: [UUID],
        action: ComplianceAction
    ) async throws -> [UUID: ComplianceValidationResult] {
        var results: [UUID: ComplianceValidationResult] = [:]
        results.reserveCapacity(invoiceIds.count)
        for id in invoiceIds {
            results[id] = try await validateInvoiceTransition(invoiceId: id, action: action, targetStatus: nil)
        }
        return results
    }

    public func validateSessionForInvoicing(
        sessionId: UUID
    ) async throws -> ComplianceValidationResult {
        var warnings: [ComplianceIssue] = []
        var blockers: [ComplianceIssue] = []

        try await validateBusiness(&warnings, &blockers)

        guard let session = try fetchSession(byId: sessionId) else {
            blockers.append(
                ComplianceIssue(
                    id: "session.not_found",
                    severity: .blocker,
                    message: "Session not found.",
                    entityID: sessionId
                )
            )
            return ComplianceValidationResult(warnings: warnings, blockers: blockers)
        }

        try await validateSessionAndAgreement(session: session, &warnings, &blockers)

        let logs = try fetchSupportLogsBySession(session.id)
        if logs.isEmpty {
            warnings.append(
                ComplianceIssue(
                    id: "support_log.missing",
                    severity: .warning,
                    message: "No support log entries found for this session.",
                    entityID: session.id
                )
            )
        }

        return ComplianceValidationResult(warnings: warnings, blockers: blockers)
    }

    public nonisolated func validateInvoiceForExport(
        invoice: InvoiceSnapshot,
        items: [InvoiceItemSnapshot],
        business: BusinessSnapshot?,
        strict: Bool
    ) -> ComplianceValidationResult {
        var warnings: [ComplianceIssue] = []
        var blockers: [ComplianceIssue] = []

        validateBusinessSnapshot(business, &warnings, &blockers)

        if items.isEmpty {
            blockers.append(
                ComplianceIssue(
                    id: "invoice.items.empty",
                    severity: .blocker,
                    message: "Invoice has no line items.",
                    entityID: invoice.id
                )
            )
            return ComplianceValidationResult(warnings: warnings, blockers: blockers)
        }

        validateInvoiceItems(items, invoiceId: invoice.id, &warnings, &blockers)
        applyNDISExportValidation(
            invoice: invoice,
            items: items,
            business: business,
            strict: strict,
            warnings: &warnings,
            blockers: &blockers
        )

        return ComplianceValidationResult(warnings: warnings, blockers: blockers)
    }

    // MARK: - Core checks

    private nonisolated func validateBusinessSnapshot(
        _ business: BusinessSnapshot?,
        _ warnings: inout [ComplianceIssue],
        _ blockers: inout [ComplianceIssue]
    ) {
        guard let business else {
            blockers.append(
                ComplianceIssue(
                    id: "business.missing",
                    severity: .blocker,
                    message: "Business details are missing. Configure your business profile before continuing."
                )
            )
            return
        }

        let abnDigits = business.abn.filter(\.isNumber)
        if abnDigits.count != 11 {
            blockers.append(
                ComplianceIssue(
                    id: "business.abn.invalid",
                    severity: .blocker,
                    message: "Business ABN is missing or invalid.",
                    entityID: business.id,
                    field: "abn"
                )
            )
        }

        if business.isRegisteredProvider == false {
            warnings.append(
                ComplianceIssue(
                    id: "business.ndis_provider.not_registered",
                    severity: .warning,
                    message: "Business is not marked as an NDIS registered provider.",
                    entityID: business.id,
                    field: "isRegisteredProvider"
                )
            )
        }
    }

    private nonisolated func applyNDISExportValidation(
        invoice: InvoiceSnapshot,
        items: [InvoiceItemSnapshot],
        business: BusinessSnapshot?,
        strict: Bool,
        warnings: inout [ComplianceIssue],
        blockers: inout [ComplianceIssue]
    ) {
        _ = business

        let ndisNumber = invoice.clientNDISNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if ndisNumber.isEmpty {
            appendExportIssue(
                id: "invoice.participant_ndis.missing",
                message: "Participant NDIS number is missing.",
                entityID: invoice.id,
                field: "clientNDISNumber",
                strict: strict,
                warnings: &warnings,
                blockers: &blockers
            )
        }

        let bankAccountName = invoice.bankAccountName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let bankBSB = invoice.bankBSB?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let bankAccountNumber = invoice.bankAccountNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if bankAccountName.isEmpty || bankBSB.isEmpty || bankAccountNumber.isEmpty {
            appendExportIssue(
                id: "invoice.bank_details.missing",
                message: "Bank details are incomplete. BSB, account name, and account number are required.",
                entityID: invoice.id,
                field: "bankDetails",
                strict: strict,
                warnings: &warnings,
                blockers: &blockers
            )
        }

        for item in items {
            let itemCode = item.ndisItemNumber?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if itemCode.isEmpty {
                appendExportIssue(
                    id: "invoice_item.support_item_code.missing",
                    message: "Line item \"\(item.itemDescription)\" is missing a support item code.",
                    entityID: item.id,
                    field: "ndisItemNumber",
                    strict: strict,
                    warnings: &warnings,
                    blockers: &blockers
                )
            }

            if !Self.hasValidServiceDate(item.serviceDate) {
                appendExportIssue(
                    id: "invoice_item.service_date.missing",
                    message: "Line item \"\(item.itemDescription)\" is missing a service date.",
                    entityID: item.id,
                    field: "serviceDate",
                    strict: strict,
                    warnings: &warnings,
                    blockers: &blockers
                )
            }

            if item.finalRateLimit > 0, item.rate > Decimal(item.finalRateLimit) {
                let message = String(
                    format: "Line item \"%@\" rate $%.2f exceeds PAPL cap $%.2f.",
                    item.itemDescription,
                    NSDecimalNumber(decimal: item.rate).doubleValue,
                    item.finalRateLimit
                )
                appendExportIssue(
                    id: "invoice_item.papl_rate_exceeded",
                    message: message,
                    entityID: item.id,
                    field: "rate",
                    strict: strict,
                    warnings: &warnings,
                    blockers: &blockers
                )
            }
        }
    }

    private nonisolated static func hasValidServiceDate(_ serviceDate: Date) -> Bool {
        Calendar.current.component(.year, from: serviceDate) >= 2000
    }

    private nonisolated func appendExportIssue(
        id: String,
        message: String,
        entityID: UUID?,
        field: String?,
        strict: Bool,
        warnings: inout [ComplianceIssue],
        blockers: inout [ComplianceIssue]
    ) {
        let issue = ComplianceIssue(
            id: id,
            severity: strict ? .blocker : .warning,
            message: message,
            entityID: entityID,
            field: field
        )
        if strict {
            blockers.append(issue)
        } else {
            warnings.append(issue)
        }
    }

    private func validateBusiness(
        _ warnings: inout [ComplianceIssue],
        _ blockers: inout [ComplianceIssue]
    ) async throws {
        guard let business = try fetchFirstBusiness() else {
            blockers.append(
                ComplianceIssue(
                    id: "business.missing",
                    severity: .blocker,
                    message: "Business details are missing. Configure your business profile before continuing."
                )
            )
            return
        }

        let abnDigits = business.abn.filter(\.isNumber)
        if abnDigits.count != 11 {
            blockers.append(
                ComplianceIssue(
                    id: "business.abn.invalid",
                    severity: .blocker,
                    message: "Business ABN is missing or invalid.",
                    entityID: business.id,
                    field: "abn"
                )
            )
        }

        if business.isRegisteredProvider == false {
            warnings.append(
                ComplianceIssue(
                    id: "business.ndis_provider.not_registered",
                    severity: .warning,
                    message: "Business is not marked as an NDIS registered provider.",
                    entityID: business.id,
                    field: "isRegisteredProvider"
                )
            )
        }
    }

    private nonisolated func validateInvoiceItems(
        _ items: [InvoiceItemSnapshot],
        invoiceId: UUID,
        _ warnings: inout [ComplianceIssue],
        _ blockers: inout [ComplianceIssue]
    ) {
        if items.isEmpty {
            blockers.append(
                ComplianceIssue(
                    id: "invoice.items.empty",
                    severity: .blocker,
                    message: "Invoice has no line items.",
                    entityID: invoiceId
                )
            )
            return
        }

        let validGstCodes = Set(GSTCode.allCases.map(\.rawValue))
        for item in items {
            if let gst = item.gstCode, !gst.isEmpty, !validGstCodes.contains(gst) {
                warnings.append(
                    ComplianceIssue(
                        id: "invoice_item.gst.invalid",
                        severity: .warning,
                        message: "Invoice item has an unrecognized GST code (\(gst)).",
                        entityID: item.id,
                        field: "gstCode"
                    )
                )
            }
        }
    }

    private func fetchLinkedSessions(
        invoice: InvoiceSnapshot,
        invoiceItems: [InvoiceItemSnapshot]
    ) async throws -> [SessionSnapshot] {
        var sessions: [SessionSnapshot] = []
        sessions.reserveCapacity(invoice.sessionIds.count)

        if !invoice.sessionIds.isEmpty {
            for id in invoice.sessionIds {
                if let session = try fetchSession(byId: id) {
                    sessions.append(session)
                }
            }
            return sessions
        }

        for item in invoiceItems {
            guard let sessionId = item.sessionId else { continue }
            if let session = try fetchSession(byId: sessionId) {
                sessions.append(session)
            }
        }
        return sessions
    }

    private func validateSessionsAndAgreements(
        sessions: [SessionSnapshot],
        invoiceItems: [InvoiceItemSnapshot],
        warnings: inout [ComplianceIssue],
        blockers: inout [ComplianceIssue]
    ) async throws {
        let claimTypes = Set(invoiceItems.compactMap(\.claimType))

        for session in sessions {
            try await validateSessionAndAgreement(
                session: session,
                claimTypes: claimTypes,
                &warnings,
                &blockers
            )
        }
    }

    private func validateSessionAndAgreement(
        session: SessionSnapshot,
        _ warnings: inout [ComplianceIssue],
        _ blockers: inout [ComplianceIssue]
    ) async throws {
        try await validateSessionAndAgreement(session: session, claimTypes: nil, &warnings, &blockers)
    }

    private func validateSessionAndAgreement(
        session: SessionSnapshot,
        claimTypes: Set<NDISClaimType>?,
        _ warnings: inout [ComplianceIssue],
        _ blockers: inout [ComplianceIssue]
    ) async throws {
        guard let clientId = session.clientId else {
            blockers.append(
                ComplianceIssue(
                    id: "session.client.missing",
                    severity: .blocker,
                    message: "Session is missing a client.",
                    entityID: session.id,
                    field: "clientId"
                )
            )
            return
        }

        let date = session.startTime ?? Date()
        guard let agreement = try fetchActiveServiceAgreement(clientId: clientId, date: date) else {
            blockers.append(
                ComplianceIssue(
                    id: "agreement.missing",
                    severity: .blocker,
                    message: "No active service agreement found for this session date.",
                    entityID: clientId
                )
            )
            return
        }

        if agreement.pricingDisclosureAcceptedAt == nil {
            warnings.append(
                ComplianceIssue(
                    id: "agreement.pricing_disclosure.missing",
                    severity: .warning,
                    message: "Service agreement pricing disclosure acceptance date is missing.",
                    entityID: agreement.id,
                    field: "pricingDisclosureAcceptedAt"
                )
            )
        }

        guard let claimTypes else { return }

        if claimTypes.contains(.telehealth), agreement.allowsTelehealth == false {
            blockers.append(
                ComplianceIssue(
                    id: "agreement.telehealth.disallowed",
                    severity: .blocker,
                    message: "Invoice contains telehealth claims but the active service agreement does not allow telehealth.",
                    entityID: agreement.id
                )
            )
        }

        if claimTypes.contains(.nonFaceToFace), agreement.allowsNonFaceToFace == false {
            blockers.append(
                ComplianceIssue(
                    id: "agreement.non_face_to_face.disallowed",
                    severity: .blocker,
                    message: "Invoice contains non-face-to-face claims but the active service agreement does not allow them.",
                    entityID: agreement.id
                )
            )
        }

        if claimTypes.contains(.providerTravel), agreement.allowsProviderTravel == false {
            blockers.append(
                ComplianceIssue(
                    id: "agreement.provider_travel.disallowed",
                    severity: .blocker,
                    message: "Invoice contains provider travel claims but the active service agreement does not allow provider travel.",
                    entityID: agreement.id
                )
            )
        }
    }

    // MARK: - SwiftData fetch helpers (snapshots)

    private func fetchFirstBusiness() throws -> BusinessSnapshot? {
        let descriptor = FetchDescriptor<Business>()
        return try modelContext.fetch(descriptor).first?.snapshot()
    }

    private func fetchInvoice(by id: UUID) throws -> InvoiceSnapshot? {
        let descriptor = FetchDescriptor<Invoice>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first?.snapshot()
    }

    private func fetchInvoiceItems(invoiceId: UUID) throws -> [InvoiceItemSnapshot] {
        let descriptor = FetchDescriptor<InvoiceItem>(predicate: #Predicate { $0.invoice?.id == invoiceId })
        return try modelContext.fetch(descriptor).map { $0.snapshot() }
    }

    private func fetchSession(byId id: UUID) throws -> SessionSnapshot? {
        let descriptor = FetchDescriptor<Session>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first?.snapshot()
    }

    private func fetchSupportLogsBySession(_ sessionId: UUID) throws -> [SupportLogSnapshot] {
        let descriptor = FetchDescriptor<SupportLog>(predicate: #Predicate { $0.session?.id == sessionId })
        return try modelContext.fetch(descriptor).map { $0.snapshot() }
    }

    private func fetchActiveServiceAgreement(clientId: UUID, date: Date) throws -> ServiceAgreementSnapshot? {
        let descriptor = FetchDescriptor<ServiceAgreement>(
            predicate: #Predicate { $0.client?.id == clientId },
            sortBy: [SortDescriptor(\.effectiveFrom, order: .reverse)]
        )
        let agreements = try modelContext.fetch(descriptor)
        return agreements
            .map { $0.snapshot() }
            .first(where: { snapshot in
                !snapshot.isArchived &&
                snapshot.effectiveFrom <= date &&
                (snapshot.effectiveTo == nil || snapshot.effectiveTo! >= date)
            })
    }
}
