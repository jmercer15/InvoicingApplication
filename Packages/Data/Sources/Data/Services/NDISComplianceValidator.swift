import Foundation
import Core

public struct ComplianceIssue: Sendable, Equatable, Hashable {
    public enum Severity: String, Sendable {
        case warning
        case blocker
    }

    public let id: String
    public let severity: Severity
    public let message: String
    public let entityId: UUID?
    public let field: String?

    public init(id: String, severity: Severity, message: String, entityId: UUID? = nil, field: String? = nil) {
        self.id = id
        self.severity = severity
        self.message = message
        self.entityId = entityId
        self.field = field
    }
}

public struct ComplianceValidationResult: Sendable {
    public let warnings: [ComplianceIssue]
    public let blockers: [ComplianceIssue]

    public init(warnings: [ComplianceIssue] = [], blockers: [ComplianceIssue] = []) {
        self.warnings = warnings
        self.blockers = blockers
    }

    public var isBlocked: Bool { !blockers.isEmpty }
}

public enum ComplianceAction: String, Sendable {
    case approveDraft
    case sendInvoice
    case markPaid
    case statusChange
    case bulkSendReady
    case bulkCompletePending
}

@MainActor
public final class NDISComplianceValidator {
    private let businessRepository: BusinessRepository
    private let invoicesRepository: InvoicesRepository
    private let sessionsRepository: SessionsRepository
    private let serviceAgreementRepository: ServiceAgreementRepository
    private let supportLogRepository: SupportLogRepository

    private let validGstCodes = Set(GSTCode.allCases.map(\.rawValue))
    private let validCancellationReasons = Set(CancellationReasonCode.allCases.map(\.rawValue))

    public init(
        businessRepository: BusinessRepository,
        invoicesRepository: InvoicesRepository,
        sessionsRepository: SessionsRepository,
        serviceAgreementRepository: ServiceAgreementRepository,
        supportLogRepository: SupportLogRepository
    ) {
        self.businessRepository = businessRepository
        self.invoicesRepository = invoicesRepository
        self.sessionsRepository = sessionsRepository
        self.serviceAgreementRepository = serviceAgreementRepository
        self.supportLogRepository = supportLogRepository
    }

    public func validateInvoiceTransition(
        invoiceId: UUID,
        action: ComplianceAction,
        targetStatus: String? = nil
    ) async throws -> ComplianceValidationResult {
        _ = action
        _ = targetStatus

        var warnings: [ComplianceIssue] = []
        var blockers: [ComplianceIssue] = []

        guard let invoice = try await invoicesRepository.fetch(by: invoiceId) else {
            return ComplianceValidationResult(
                blockers: [
                    ComplianceIssue(id: "INV-404", severity: .blocker, message: "Invoice not found.", entityId: invoiceId)
                ]
            )
        }

        if let business = try await businessRepository.fetchFirst() {
            validateBusiness(business, warnings: &warnings, blockers: &blockers)
        } else {
            blockers.append(
                ComplianceIssue(
                    id: "BUS-GST-001",
                    severity: .blocker,
                    message: "Business profile is missing. Configure company settings before transition.",
                    entityId: invoiceId
                )
            )
        }

        let items = try await invoicesRepository.fetchItems(by: invoice.id)
        validateInvoiceItems(items, warnings: &warnings)

        let sessions = try await fetchLinkedSessions(for: invoice)
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
        for id in invoiceIds {
            results[id] = try await validateInvoiceTransition(invoiceId: id, action: action)
        }
        return results
    }

    public func validateSessionForInvoicing(sessionId: UUID) async throws -> ComplianceValidationResult {
        var blockers: [ComplianceIssue] = []
        guard let session = try await sessionsRepository.fetch(byId: sessionId) else {
            return ComplianceValidationResult(
                blockers: [ComplianceIssue(id: "SES-404", severity: .blocker, message: "Session not found.", entityId: sessionId)]
            )
        }

        let logs = try await supportLogRepository.fetchBySession(session.id)
        if logs.isEmpty {
            blockers.append(
                ComplianceIssue(
                    id: "LOG-REQ-001",
                    severity: .blocker,
                    message: "Support log is required before invoicing this session.",
                    entityId: session.id
                )
            )
        }
        return ComplianceValidationResult(blockers: blockers)
    }

    private func validateBusiness(_ business: Business, warnings: inout [ComplianceIssue], blockers: inout [ComplianceIssue]) {
        let gst = business.defaultGstCode.uppercased()
        if !validGstCodes.contains(gst) {
            blockers.append(
                ComplianceIssue(
                    id: "BUS-GST-001",
                    severity: .blocker,
                    message: "Default GST code must be one of P1, P2, or P5.",
                    field: "defaultGstCode"
                )
            )
        }

        if business.isRegisteredProvider {
            let orgId = (business.ndiaOrganisationID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if orgId.isEmpty || orgId.count > 30 || !CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: orgId)) {
                blockers.append(
                    ComplianceIssue(
                        id: "BUS-ORG-001",
                        severity: .blocker,
                        message: "NDIA Organisation ID is required for registered providers and must be numeric (1-30 digits).",
                        field: "ndiaOrganisationID"
                    )
                )
            }
        }

        if business.ndiaOrganisationID?.contains(" ") == true {
            warnings.append(
                ComplianceIssue(
                    id: "BUS-ORG-WS",
                    severity: .warning,
                    message: "NDIA Organisation ID contains whitespace and should be normalized.",
                    field: "ndiaOrganisationID"
                )
            )
        }
    }

    private func validateInvoiceItems(_ items: [InvoiceItem], warnings: inout [ComplianceIssue]) {
        for item in items {
            let code = item.gstCode?.uppercased()
            if code == nil || code?.isEmpty == true {
                warnings.append(
                    ComplianceIssue(
                        id: "GST-LINE-001",
                        severity: .warning,
                        message: "Invoice line item is missing GST code; business default will be used.",
                        entityId: item.id,
                        field: "gstCode"
                    )
                )
            }
        }
    }

    private func fetchLinkedSessions(for invoice: Invoice) async throws -> [Session] {
        if !invoice.sessionIds.isEmpty {
            var sessions: [Session] = []
            for id in invoice.sessionIds {
                if let session = try await sessionsRepository.fetch(byId: id) {
                    sessions.append(session)
                }
            }
            return sessions
        }

        let items = try await invoicesRepository.fetchItems(by: invoice.id)
        var sessions: [Session] = []
        for item in items {
            if let sessionId = item.sessionId, let session = try await sessionsRepository.fetch(byId: sessionId) {
                sessions.append(session)
            }
        }
        return Array(Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) }).values)
    }

    private func validateSessionsAndAgreements(
        sessions: [Session],
        invoiceItems: [InvoiceItem],
        warnings: inout [ComplianceIssue],
        blockers: inout [ComplianceIssue]
    ) async throws {
        let claimTypes = Set(invoiceItems.compactMap(\.claimType))

        if claimTypes.contains(NDISClaimType.providerTravel.rawValue) {
            warnings.append(
                ComplianceIssue(
                    id: "TRAVEL-MMM-001",
                    severity: .warning,
                    message: "Provider travel claim exists. Ensure MMM zone source is resolved for final claim export."
                )
            )
        }

        for session in sessions {
            let logs = try await supportLogRepository.fetchBySession(session.id)
            if logs.isEmpty {
                blockers.append(
                    ComplianceIssue(
                        id: "LOG-REQ-001",
                        severity: .blocker,
                        message: "Support log missing for linked session \(session.title).",
                        entityId: session.id
                    )
                )
                continue
            }

            for log in logs where log.signatureMethod == SignatureMethod.attestation.rawValue && (log.signedBy == nil || log.signedBy?.isEmpty == true) {
                warnings.append(
                    ComplianceIssue(
                        id: "LOG-SIGN-001",
                        severity: .warning,
                        message: "Support log uses attestation but has no participant signature.",
                        entityId: log.id
                    )
                )
            }

            guard let clientId = session.clientId else { continue }
            let date = session.startTime ?? Date()
            guard let agreement = try await serviceAgreementRepository.fetchActive(clientId: clientId, on: date) else {
                blockers.append(
                    ComplianceIssue(
                        id: "AGR-ACT-001",
                        severity: .blocker,
                        message: "No active service agreement exists for session \(session.title).",
                        entityId: session.id
                    )
                )
                continue
            }

            if claimTypes.contains(NDISClaimType.telehealth.rawValue) && !agreement.allowsTelehealth {
                blockers.append(
                    ComplianceIssue(
                        id: "AGR-AUTH-THLT",
                        severity: .blocker,
                        message: "Telehealth claim is not authorized by service agreement.",
                        entityId: session.id
                    )
                )
            }

            if claimTypes.contains(NDISClaimType.nonFaceToFace.rawValue) && !agreement.allowsNonFaceToFace {
                blockers.append(
                    ComplianceIssue(
                        id: "AGR-AUTH-NF2F",
                        severity: .blocker,
                        message: "Non face-to-face claim is not authorized by service agreement.",
                        entityId: session.id
                    )
                )
            }

            if claimTypes.contains(NDISClaimType.providerTravel.rawValue) && !agreement.allowsProviderTravel {
                blockers.append(
                    ComplianceIssue(
                        id: "AGR-AUTH-TRAN",
                        severity: .blocker,
                        message: "Provider travel claim is not authorized by service agreement.",
                        entityId: session.id
                    )
                )
            }

            if claimTypes.contains(NDISClaimType.cancellation.rawValue) {
                let policy = agreement.cancellationPolicyType.trimmingCharacters(in: .whitespacesAndNewlines)
                if policy.isEmpty {
                    blockers.append(
                        ComplianceIssue(
                            id: "AGR-AUTH-CANC",
                            severity: .blocker,
                            message: "Cancellation claim requires a cancellation policy in service agreement.",
                            entityId: session.id
                        )
                    )
                }

                let reasons = logs.compactMap(\.cancellationReasonCode)
                if reasons.isEmpty || reasons.contains(where: { !validCancellationReasons.contains($0.uppercased()) }) {
                    blockers.append(
                        ComplianceIssue(
                            id: "CANC-REASON-001",
                            severity: .blocker,
                            message: "Cancellation claim requires a valid cancellation reason code (NSDH, NSDF, NSDT, NSDO).",
                            entityId: session.id
                        )
                    )
                }
            }
        }
    }
}
