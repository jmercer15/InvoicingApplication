import Core
import Foundation
import SwiftData

/// Builds BulkClaim snapshots from selected billable drafts (NDIA-managed).
/// Output is snapshot-only so callers can persist via `ModelContext` in their own transaction scope.
@MainActor
public struct ClaimBatchBuilderService: Sendable {
    private let modelContainer: ModelContainer

    public init(
        modelContext: ModelContext
    ) {
        self.modelContainer = modelContext.container
    }

    /// Builds a batch and lines from the given drafts. Caller persists resulting entities via `ModelContext`.
    public func buildBatch(
        from drafts: [BillableDraftSnapshot],
        fromDate: Date,
        toDate: Date,
        claimReferenceStrategy: String
    ) async throws -> (batch: BulkClaimBatchSnapshot, lines: [BulkClaimLineSnapshot]) {
        let modelContext = ModelContext(modelContainer)
        let business = try modelContext.fetch(FetchDescriptor<Business>()).first
        let registrationNumber = (business?.ndiaOrganisationID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let abn = business?.abn

        let clientIds = Set(drafts.map(\.clientId))
        let clientsById: [UUID: ClientSnapshot]
        if clientIds.isEmpty {
            clientsById = [:]
        } else {
            let ids = Array(clientIds)
            let clientSnapshots = try modelContext.fetch(
                FetchDescriptor<Client>(predicate: #Predicate { ids.contains($0.id) })
            ).map { $0.snapshot() }
            clientsById = Dictionary(uniqueKeysWithValues: clientSnapshots.map { ($0.id, $0) })
        }

        let draftIds = drafts.map(\.id)
        let claimableLinesByDraftId: [UUID: [ClaimableLineSnapshot]]
        if draftIds.isEmpty {
            claimableLinesByDraftId = [:]
        } else {
            let lines = try modelContext.fetch(
                FetchDescriptor<ClaimableLine>(predicate: #Predicate { draftIds.contains($0.draftId) })
            ).map { $0.snapshot() }

            var grouped: [UUID: [ClaimableLineSnapshot]] = [:]
            for line in lines {
                grouped[line.draftId, default: []].append(line)
            }
            claimableLinesByDraftId = grouped
        }

        var allLines: [BulkClaimLineSnapshot] = []
        let batchId = UUID()
        let now = Date()

        for draft in drafts {
            let client = clientsById[draft.clientId]
            let ndisNumber = client?.ndisNumber ?? ""
            let planType = (client?.planManagementType ?? "").lowercased()
            let isNDIAManaged = planType.contains("ndia") || planType.contains("agency")
            let abnOfSupportProvider: String? = isNDIAManaged ? (abn.flatMap { normalizeABN($0) }) : nil

            let claimableLines = claimableLinesByDraftId[draft.id] ?? []
            for line in claimableLines {
                let claimRef = line.claimReference ?? "\(draft.sessionId)-\(line.id.uuidString.prefix(8))"
                let bulkLine = BulkClaimLineSnapshot(
                    id: UUID(),
                    registrationNumber: registrationNumber,
                    ndisNumber: ndisNumber,
                    supportsDeliveredFrom: line.serviceFrom,
                    supportsDeliveredTo: line.serviceTo,
                    supportNumber: line.supportItemNumber,
                    claimReference: claimRef,
                    quantity: line.quantityDecimal,
                    hours: line.hoursHHHMM,
                    unitPrice: line.unitPrice,
                    gstCode: line.gstCode,
                    claimTypeCode: mapClaimTypeCode(line.claimType),
                    cancellationReason: line.cancellationReason,
                    abnOfSupportProvider: abnOfSupportProvider,
                    draftLineId: line.id,
                    batchId: batchId
                )
                allLines.append(bulkLine)
            }
        }

        let batch = BulkClaimBatchSnapshot(
            id: batchId,
            createdAt: now,
            fromDate: fromDate,
            toDate: toDate,
            status: BulkClaimBatchStatus.draft.rawValue,
            includeTravel: true,
            includeCancellations: true,
            claimReferenceStrategy: claimReferenceStrategy,
            exportFileName: nil,
            exportedAt: nil,
            submittedAt: nil,
            rowCount: Int32(allLines.count),
            errorCount: 0,
            checksumSHA256: nil,
            notes: nil
        )
        return (batch, allLines.sorted { $0.supportsDeliveredFrom < $1.supportsDeliveredFrom })
    }

    /// Builds a batch and lines from persisted draft identifiers.
    public func buildBatch(
        fromDraftIDs draftIDs: [UUID],
        fromDate: Date,
        toDate: Date,
        claimReferenceStrategy: String
    ) async throws -> (batch: BulkClaimBatchSnapshot, lines: [BulkClaimLineSnapshot]) {
        guard !draftIDs.isEmpty else {
            return try await buildBatch(
                from: [],
                fromDate: fromDate,
                toDate: toDate,
                claimReferenceStrategy: claimReferenceStrategy
            )
        }

        let modelContext = ModelContext(modelContainer)
        let ids = draftIDs
        let drafts = try modelContext.fetch(
            FetchDescriptor<BillableDraft>(predicate: #Predicate { ids.contains($0.id) })
        ).map { $0.snapshot() }

        return try await buildBatch(
            from: drafts,
            fromDate: fromDate,
            toDate: toDate,
            claimReferenceStrategy: claimReferenceStrategy
        )
    }

    private func mapClaimTypeCode(_ claimType: String) -> String? {
        switch claimType {
        case "ProviderTravel", "ProviderTravelLabour": return BPRClaimTypeCode.tran.rawValue
        case "NonFaceToFace": return BPRClaimTypeCode.nf2f.rawValue
        case "Telehealth": return BPRClaimTypeCode.thlt.rawValue
        case "Cancellation": return BPRClaimTypeCode.canc.rawValue
        case "NDIAReport": return BPRClaimTypeCode.repw.rawValue
        case "IrregularSILSupport": return BPRClaimTypeCode.irss.rawValue
        default: return nil
        }
    }
    private func normalizeABN(_ value: String?) -> String? {
        guard let value else { return nil }
        let digits = value.filter(\.isNumber)
        return digits.count == 11 ? digits : nil
    }
}
