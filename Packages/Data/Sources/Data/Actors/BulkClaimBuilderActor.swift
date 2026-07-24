import Foundation
import Core
import SwiftData

public enum BulkClaimBuilderActorError: LocalizedError, Sendable, Equatable {
    case batchModelNotFound
    case batchNotFound(UUID)
    case invoiceNotFound(UUID)

    public var errorDescription: String? {
        switch self {
        case .batchModelNotFound:
            return "Bulk claim batch not found for the provided model identifier."
        case .batchNotFound(let id):
            return "Bulk claim batch not found for id \(id.uuidString)."
        case .invoiceNotFound(let id):
            return "Invoice not found for id \(id.uuidString)."
        }
    }
}

/// Background SwiftData actor for BPR line generation (heavy fetches stay off the main thread).
public actor BulkClaimBuilderActor: ModelActor {
    nonisolated public let modelContainer: ModelContainer
    nonisolated public let modelExecutor: any ModelExecutor

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    }

    public func buildLines(batchModelID: PersistentIdentifier) throws -> [BulkClaimLineSnapshot] {
        var descriptor = FetchDescriptor<BulkClaimBatch>(
            predicate: #Predicate { $0.persistentModelID == batchModelID }
        )
        descriptor.fetchLimit = 1
        guard let batch = try modelContext.fetch(descriptor).first else {
            throw BulkClaimBuilderActorError.batchModelNotFound
        }
        return try buildLines(for: batch)
    }

    public func buildLines(batchID: UUID) throws -> [BulkClaimLineSnapshot] {
        guard let batch = try modelContext.fetch(
            FetchDescriptor<BulkClaimBatch>(predicate: #Predicate { $0.id == batchID })
        ).first else {
            throw BulkClaimBuilderActorError.batchNotFound(batchID)
        }
        return try buildLines(for: batch)
    }

    public func buildLines(for batch: BulkClaimBatchSnapshot) throws -> [BulkClaimLineSnapshot] {
        let modelBatch = BulkClaimBatch(id: batch.id)
        modelBatch.fromDate = batch.fromDate
        modelBatch.toDate = batch.toDate
        modelBatch.includeTravel = batch.includeTravel
        modelBatch.includeCancellations = batch.includeCancellations
        modelBatch.claimReferenceStrategy = batch.claimReferenceStrategy
        return try buildLines(for: modelBatch)
    }

    public func buildLines(for batch: BulkClaimBatch) throws -> [BulkClaimLineSnapshot] {
        let business = try modelContext.fetch(FetchDescriptor<Business>()).first
        let defaultGST = Self.normalizeGSTCode(business?.defaultGstCode) ?? GSTCode.p2.rawValue
        let registrationNumber = (business?.ndiaOrganisationID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let providerABN = business?.abn

        let fromDate = batch.fromDate
        let toDate = batch.toDate
        let invoiceItems = try modelContext.fetch(
            FetchDescriptor<InvoiceItem>(
                predicate: #Predicate { $0.serviceDate >= fromDate && $0.serviceDate <= toDate }
            )
        )

        var lines: [BulkClaimLineSnapshot] = []
        let invoiceIds = Set(invoiceItems.compactMap { $0.invoice?.id })
        let invoicesById: [UUID: Invoice]
        if invoiceIds.isEmpty {
            invoicesById = [:]
        } else {
            let ids = Array(invoiceIds)
            let snapshots = try modelContext.fetch(
                FetchDescriptor<Invoice>(predicate: #Predicate { ids.contains($0.id) })
            )
            invoicesById = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.id, $0) })
        }
        let invoiceSnapshotsById: [UUID: InvoiceSnapshot] = invoicesById.mapValues { $0.snapshot() }

        let sessionIds = Set(invoiceItems.compactMap { $0.session?.id })
        let sessionsById: [UUID: SessionSnapshot]
        if sessionIds.isEmpty {
            sessionsById = [:]
        } else {
            let ids = Array(sessionIds)
            let snapshots = try modelContext.fetch(
                FetchDescriptor<Session>(predicate: #Predicate { ids.contains($0.id) })
            ).reduce(into: [UUID: Session]()) { dict, session in
                dict[session.id] = session
            }
            let sessionSnapshots = snapshots.reduce(into: [UUID: SessionSnapshot]()) { dict, value in
                dict[value.key] = value.value.snapshot()
            }
            sessionsById = sessionSnapshots
        }

        let supportLogsBySessionId: [UUID: [SupportLog]]
        if sessionIds.isEmpty {
            supportLogsBySessionId = [:]
        } else {
            let from = batch.fromDate
            let to = batch.toDate
            let logs = try modelContext.fetch(
                FetchDescriptor<SupportLog>(predicate: #Predicate { log in
                    log.deliveredFrom >= from && log.deliveredFrom <= to
                })
            ).filter {
                guard let sid = $0.session?.id else { return false }
                return sessionIds.contains(sid)
            }

            var grouped: [UUID: [SupportLog]] = [:]
            for log in logs {
                guard let sid = log.session?.id else { continue }
                grouped[sid, default: []].append(log)
            }
            supportLogsBySessionId = grouped
        }

        let clientIds = Set(invoicesById.values.compactMap(\.clientId))
        let clientsById: [UUID: ClientSnapshot]
        if clientIds.isEmpty {
            clientsById = [:]
        } else {
            let ids = Array(clientIds)
            let clients = try modelContext.fetch(
                FetchDescriptor<Client>(predicate: #Predicate { ids.contains($0.id) })
            )
            clientsById = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0.snapshot()) })
        }

        for item in invoiceItems {
            let item = item.snapshot()
            guard let invoiceId = item.invoiceId else {
                continue
            }
            guard let invoice = invoicesById[invoiceId] else {
                throw BulkClaimBuilderActorError.invoiceNotFound(invoiceId)
            }
            guard let invoiceSnapshot = invoiceSnapshotsById[invoiceId] else {
                throw BulkClaimBuilderActorError.invoiceNotFound(invoiceId)
            }

            let claimTypeCode = Self.mapClaimTypeCode(from: item.claimType?.rawValue)
            if !batch.includeTravel && claimTypeCode == BPRClaimTypeCode.tran.rawValue {
                continue
            }
            if !batch.includeCancellations && claimTypeCode == BPRClaimTypeCode.canc.rawValue {
                continue
            }

            let session: SessionSnapshot? = {
                guard let sessionId = item.sessionId else { return nil }
                return sessionsById[sessionId]
            }()

            let supportLogs: [SupportLogSnapshot] = {
                guard let sessionId = item.sessionId else { return [] }
            return supportLogsBySessionId[sessionId]?.map { $0.snapshot() } ?? []
            }()

            let primaryLog = supportLogs.sorted { $0.deliveredFrom < $1.deliveredFrom }.first

            let client: ClientSnapshot? = {
                guard let clientId = invoice.clientId else { return nil }
                return clientsById[clientId]
            }()

            let ndisNumber: String = {
                if let snapshot = invoice.clientNDISNumber,
                   !snapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return snapshot
                }
                return client?.ndisNumber ?? ""
            }()

            let deliveredFrom = primaryLog?.deliveredFrom ?? session?.startTime ?? item.serviceDate
            let deliveredTo = primaryLog?.deliveredTo ?? session?.endTime ?? item.serviceDate

            let claimReference = Self.makeClaimReference(
                strategy: batch.claimReferenceStrategy,
                invoice: invoiceSnapshot,
                item: item,
                session: session
            )

            let (quantity, hours) = Self.mapQuantityOrHours(from: item)
            let gstCode = Self.normalizeGSTCode(item.gstCode) ?? defaultGST
            let abnOfSupportProvider: String? = Self.isPlanManagedBooking(invoice: invoiceSnapshot, client: client)
                ? Self.normalizeABNForClaim(providerABN)
                : nil

            let line = BulkClaimLineSnapshot(
                id: UUID(),
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
                abnOfSupportProvider: abnOfSupportProvider,
                draftLineId: nil,
                isValid: true,
                validationErrorSummary: nil,
                batchId: batch.id,
                invoiceId: invoice.id,
                invoiceItemId: item.id
            )
            lines.append(line)
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

    private static func mapClaimTypeCode(from claimType: String?) -> String? {
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

    private static func mapQuantityOrHours(from item: InvoiceItemSnapshot) -> (Double?, String?) {
        let unit = (item.unit ?? "").lowercased()
        if unit.contains("hour") || unit == "hr" || unit == "hrs" {
            return (nil, formatHours(item.quantity))
        }
        return (item.quantity, nil)
    }

    private static func formatHours(_ quantity: Double) -> String {
        let totalMinutes = max(Int((quantity * 60).rounded()), 0)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return String(format: "%03d:%02d", hours, minutes)
    }

    private static func normalizeGSTCode(_ code: String?) -> String? {
        guard let code else { return nil }
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizeABNForClaim(_ value: String?) -> String? {
        guard let value else { return nil }
        let digitsOnly = value.filter(\.isNumber)
        return digitsOnly.isEmpty ? nil : digitsOnly
    }

    private static func isPlanManagedBooking(invoice: InvoiceSnapshot, client: ClientSnapshot?) -> Bool {
        if normalizedToken(invoice.billingAuthority?.rawValue) == "plan_manager" {
            return true
        }

        if let planManagementType = normalizedToken(client?.planManagementType),
           planManagementType.contains("plan") {
            return true
        }

        return false
    }

    private static func normalizedToken(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return normalized.isEmpty ? nil : normalized
    }

    private static func makeClaimReference(
        strategy: String,
        invoice: InvoiceSnapshot,
        item: InvoiceItemSnapshot,
        session: SessionSnapshot?
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
