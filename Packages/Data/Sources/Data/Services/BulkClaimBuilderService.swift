import Foundation
import Core

@MainActor
public final class BulkClaimBuilderService {
    private let invoicesRepository: InvoicesRepository
    private let sessionsRepository: SessionsRepository
    private let businessRepository: BusinessRepository
    private let clientsRepository: ClientsRepository
    private let serviceAgreementRepository: ServiceAgreementRepository
    private let supportLogRepository: SupportLogRepository

    public init(
        invoicesRepository: InvoicesRepository,
        sessionsRepository: SessionsRepository,
        businessRepository: BusinessRepository,
        clientsRepository: ClientsRepository,
        serviceAgreementRepository: ServiceAgreementRepository,
        supportLogRepository: SupportLogRepository
    ) {
        self.invoicesRepository = invoicesRepository
        self.sessionsRepository = sessionsRepository
        self.businessRepository = businessRepository
        self.clientsRepository = clientsRepository
        self.serviceAgreementRepository = serviceAgreementRepository
        self.supportLogRepository = supportLogRepository
    }

    public func buildLines(for batch: BulkClaimBatch) async throws -> [BulkClaimLine] {
        let business = try await businessRepository.fetchFirst()
        let defaultGST = normalizeGSTCode(business?.defaultGstCode) ?? GSTCode.p2.rawValue
        let registrationNumber = (business?.ndiaOrganisationID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let providerABN = business?.abn?.trimmingCharacters(in: .whitespacesAndNewlines)

        let invoices = try await invoicesRepository.fetchAll()

        var lines: [BulkClaimLine] = []
        var sessionsCache: [UUID: Session] = [:]
        var supportLogCache: [UUID: [SupportLog]] = [:]
        var clientCache: [UUID: Client] = [:]

        for invoice in invoices {
            let items = try await invoicesRepository.fetchItems(by: invoice.id)
            for item in items {
                if item.serviceDate < batch.fromDate || item.serviceDate > batch.toDate {
                    continue
                }

                let claimTypeCode = mapClaimTypeCode(from: item.claimType)
                if !batch.includeTravel && claimTypeCode == BPRClaimTypeCode.tran.rawValue {
                    continue
                }
                if !batch.includeCancellations && claimTypeCode == BPRClaimTypeCode.canc.rawValue {
                    continue
                }

                let session: Session? = try await {
                    guard let sessionId = item.sessionId else { return nil }
                    if let cached = sessionsCache[sessionId] { return cached }
                    let fetched = try await sessionsRepository.fetch(byId: sessionId)
                    if let fetched { sessionsCache[sessionId] = fetched }
                    return fetched
                }()

                let supportLogs: [SupportLog] = try await {
                    guard let sessionId = item.sessionId else { return [] }
                    if let cached = supportLogCache[sessionId] { return cached }
                    let fetched = try await supportLogRepository.fetchBySession(sessionId)
                    supportLogCache[sessionId] = fetched
                    return fetched
                }()

                let primaryLog = supportLogs.sorted { $0.deliveredFrom < $1.deliveredFrom }.first

                let ndisNumber: String = try await {
                    if let snapshot = invoice.clientNDISNumber, !snapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return snapshot
                    }
                    guard let clientId = invoice.clientId else { return "" }
                    if let cached = clientCache[clientId] { return cached.ndisNumber }
                    guard let client = try await clientsRepository.fetch(by: clientId) else { return "" }
                    clientCache[clientId] = client
                    return client.ndisNumber
                }()

                let deliveredFrom = primaryLog?.deliveredFrom ?? session?.startTime ?? item.serviceDate
                let deliveredTo = primaryLog?.deliveredTo ?? session?.endTime ?? item.serviceDate

                // Touch active service agreement resolution for context-aware builds.
                if let clientId = session?.clientId {
                    _ = try await serviceAgreementRepository.fetchActive(clientId: clientId, on: deliveredFrom)
                }

                let claimReference = makeClaimReference(
                    strategy: batch.claimReferenceStrategy,
                    invoice: invoice,
                    item: item,
                    session: session
                )

                let (quantity, hours) = mapQuantityOrHours(from: item)
                let gstCode = normalizeGSTCode(item.gstCode) ?? defaultGST

                let line = BulkClaimLine(
                    id: UUID(),
                    batchId: batch.id,
                    registrationNumber: registrationNumber,
                    ndisNumber: ndisNumber,
                    supportsDeliveredFrom: deliveredFrom,
                    supportsDeliveredTo: deliveredTo,
                    supportNumber: item.ndisItemNumber ?? "",
                    claimReference: claimReference,
                    quantity: quantity,
                    hours: hours,
                    unitPrice: item.rate,
                    gstCode: gstCode,
                    authorisedBy: primaryLog?.attestedBy,
                    participantApproved: primaryLog?.signedBy == nil ? nil : "Y",
                    inKindFundingProgram: nil,
                    claimTypeCode: claimTypeCode,
                    cancellationReason: claimTypeCode == BPRClaimTypeCode.canc.rawValue ? primaryLog?.cancellationReasonCode : nil,
                    abnOfSupportProvider: providerABN,
                    invoiceId: invoice.id,
                    invoiceItemId: item.id,
                    isValid: true,
                    validationErrorSummary: nil
                )
                lines.append(line)
            }
        }

        return lines.sorted { lhs, rhs in
            if lhs.supportsDeliveredFrom != rhs.supportsDeliveredFrom {
                return lhs.supportsDeliveredFrom < rhs.supportsDeliveredFrom
            }
            if lhs.ndisNumber != rhs.ndisNumber {
                return lhs.ndisNumber < rhs.ndisNumber
            }
            if lhs.supportNumber != rhs.supportNumber {
                return lhs.supportNumber < rhs.supportNumber
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private func mapClaimTypeCode(from claimType: String?) -> String? {
        guard let claimType else { return nil }
        switch claimType {
        case NDISClaimType.direct.rawValue:
            return nil
        case let value where value.hasPrefix(NDISClaimType.providerTravel.rawValue):
            return BPRClaimTypeCode.tran.rawValue
        case NDISClaimType.nonFaceToFace.rawValue:
            return BPRClaimTypeCode.nf2f.rawValue
        case NDISClaimType.telehealth.rawValue:
            return BPRClaimTypeCode.thlt.rawValue
        case NDISClaimType.cancellation.rawValue:
            return BPRClaimTypeCode.canc.rawValue
        case NDISClaimType.ndiaReport.rawValue:
            return BPRClaimTypeCode.repw.rawValue
        case NDISClaimType.irregularSILSupport.rawValue:
            return BPRClaimTypeCode.irss.rawValue
        default:
            return nil
        }
    }

    private func mapQuantityOrHours(from item: InvoiceItem) -> (Double?, String?) {
        let unit = (item.unit ?? "").lowercased()
        if unit.contains("hour") || unit == "hr" || unit == "hrs" {
            return (nil, formatHours(item.quantity))
        }
        return (item.quantity, nil)
    }

    private func formatHours(_ quantity: Double) -> String {
        let totalMinutes = max(Int((quantity * 60).rounded()), 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%03d:%02d", hours, minutes)
    }

    private func normalizeGSTCode(_ code: String?) -> String? {
        guard let code else { return nil }
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return normalized.isEmpty ? nil : normalized
    }

    private func makeClaimReference(
        strategy: String,
        invoice: Invoice,
        item: InvoiceItem,
        session: Session?
    ) -> String? {
        switch strategy {
        case "invoice_number":
            return invoice.invoiceNumber
        case "invoice_item_id":
            return item.id.uuidString
        case "session_id":
            return session?.id.uuidString
        default:
            return nil
        }
    }
}
