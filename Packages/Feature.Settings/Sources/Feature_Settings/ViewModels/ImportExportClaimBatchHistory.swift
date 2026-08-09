import Foundation
import SwiftData
import Core
import PersistenceModels
import DataInterfaces

// MARK: - History UI models

public struct ClaimHistoryClientOption: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let displayName: String

    public init(id: UUID, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

public struct ClaimBatchHistoryRow: Identifiable, Equatable, Hashable, Sendable {
    public let batch: BulkClaimBatchSnapshot
    public let clientIds: [UUID]
    public let clientNames: [String]
    public let lineCount: Int
    public let submittedLineCount: Int
    public let reconciledLineCount: Int
    public let exportHashVerified: Bool?

    public var id: UUID { batch.id }
    public var hasReconciliationData: Bool { submittedLineCount > 0 || reconciledLineCount > 0 }
    public var reconciliationSummary: String {
        "Submitted \(submittedLineCount)/\(lineCount) · Reconciled \(reconciledLineCount)/\(lineCount)"
    }

    public init(
        batch: BulkClaimBatchSnapshot,
        clientIds: [UUID],
        clientNames: [String],
        lineCount: Int,
        submittedLineCount: Int,
        reconciledLineCount: Int,
        exportHashVerified: Bool?
    ) {
        self.batch = batch
        self.clientIds = clientIds
        self.clientNames = clientNames
        self.lineCount = lineCount
        self.submittedLineCount = submittedLineCount
        self.reconciledLineCount = reconciledLineCount
        self.exportHashVerified = exportHashVerified
    }
}

// MARK: - Row building

public enum ImportExportClaimBatchHistory {
    public static func buildRows(
        batches: [BulkClaimBatchSnapshot],
        allLines: [BulkClaimLineSnapshot],
        clientNames: [UUID: String],
        invoiceClientIds: [UUID: UUID],
        exportHashVerifier: any BulkClaimExportHashVerifying
    ) -> [ClaimBatchHistoryRow] {
        guard !batches.isEmpty else { return [] }

        var linesByBatchId: [UUID: [BulkClaimLineSnapshot]] = [:]
        for line in allLines {
            guard let bid = line.batchId else { continue }
            linesByBatchId[bid, default: []].append(line)
        }

        var rows: [ClaimBatchHistoryRow] = []
        rows.reserveCapacity(batches.count)

        for batch in batches {
            let lineSnapshots = linesByBatchId[batch.id] ?? []
            let invoiceIds = Set(lineSnapshots.compactMap { $0.invoiceId })
            var clientIds = Set<UUID>()

            for invoiceId in invoiceIds {
                if let clientId = invoiceClientIds[invoiceId] {
                    clientIds.insert(clientId)
                }
            }

            let sortedClientIds = clientIds.sorted { $0.uuidString < $1.uuidString }
            let clientNamesList = sortedClientIds.map { clientNames[$0] ?? $0.uuidString }
            let hashVerified: Bool?
            if let checksum = batch.checksumSHA256, !checksum.isEmpty {
                hashVerified = exportHashVerifier.verify(snapshots: lineSnapshots, expectedSHA256: checksum)
            } else {
                hashVerified = nil
            }
            var submittedLineCount = 0
            var reconciledLineCount = 0
            for line in lineSnapshots {
                guard let status = line.submissionStatus else { continue }
                let normalized = status.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
                guard !normalized.isEmpty else { continue }
                if normalized != BulkClaimSubmissionStatus.pending.rawValue {
                    submittedLineCount += 1
                }
                if normalized == BulkClaimSubmissionStatus.reconciled.rawValue {
                    reconciledLineCount += 1
                }
            }

            rows.append(
                ClaimBatchHistoryRow(
                    batch: batch,
                    clientIds: sortedClientIds,
                    clientNames: clientNamesList,
                    lineCount: lineSnapshots.count,
                    submittedLineCount: submittedLineCount,
                    reconciledLineCount: reconciledLineCount,
                    exportHashVerified: hashVerified
                )
            )
        }

        return rows
    }
}
