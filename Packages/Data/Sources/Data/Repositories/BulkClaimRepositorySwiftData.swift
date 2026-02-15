import Foundation
import SwiftData
import Core

public final class BulkClaimRepositorySwiftData: BulkClaimRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    private let batchMapper: BulkClaimBatchMapper
    private let lineMapper: BulkClaimLineMapper

    public init(
        modelContext: ModelContext,
        batchMapper: BulkClaimBatchMapper = BulkClaimBatchMapper(),
        lineMapper: BulkClaimLineMapper = BulkClaimLineMapper()
    ) {
        self.modelContext = modelContext
        self.batchMapper = batchMapper
        self.lineMapper = lineMapper
    }

    public func createBatch(_ batch: BulkClaimBatch) async throws -> BulkClaimBatch {
        try await MainActor.run {
            let entity = batchMapper.mapToEntity(batch)
            modelContext.insert(entity)
            try modelContext.save()
            return batchMapper.mapToDomain(entity)
        }
    }

    public func fetchBatches() async throws -> [BulkClaimBatch] {
        let descriptor = FetchDescriptor<BulkClaimBatchEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try await MainActor.run {
            try modelContext.fetch(descriptor).map { batchMapper.mapToDomain($0) }
        }
    }

    public func fetchBatch(by id: UUID) async throws -> BulkClaimBatch? {
        let predicate = #Predicate<BulkClaimBatchEntity> { $0.id == id }
        let descriptor = FetchDescriptor<BulkClaimBatchEntity>(predicate: predicate)
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return batchMapper.mapToDomain(entity)
        }
    }

    public func fetchLines(batchId: UUID) async throws -> [BulkClaimLine] {
        let predicate = #Predicate<BulkClaimLineEntity> { $0.batch?.id == batchId }
        let descriptor = FetchDescriptor<BulkClaimLineEntity>(predicate: predicate)
        return try await MainActor.run {
            try modelContext.fetch(descriptor).map { lineMapper.mapToDomain($0) }
        }
    }

    public func replaceLines(batchId: UUID, lines: [BulkClaimLine]) async throws {
        try await MainActor.run {
            let batchEntity = try fetchBatchEntity(batchId)

            let existingPredicate = #Predicate<BulkClaimLineEntity> { $0.batch?.id == batchId }
            let existingDescriptor = FetchDescriptor<BulkClaimLineEntity>(predicate: existingPredicate)
            let existingLines = try modelContext.fetch(existingDescriptor)
            for existing in existingLines {
                modelContext.delete(existing)
            }

            for line in lines {
                let entity = lineMapper.mapToEntity(line)
                entity.batch = batchEntity

                if let invoiceId = line.invoiceId {
                    entity.invoice = try fetchInvoiceEntity(invoiceId)
                }
                if let invoiceItemId = line.invoiceItemId {
                    entity.invoiceItem = try fetchInvoiceItemEntity(invoiceItemId)
                }

                modelContext.insert(entity)
            }

            let errorCount = lines.filter { !$0.isValid }.count
            batchEntity.rowCount = Int32(lines.count)
            batchEntity.errorCount = Int32(errorCount)
            if lines.isEmpty {
                batchEntity.status = BulkClaimBatchStatus.draft.rawValue
            } else {
                batchEntity.status = errorCount == 0 ? BulkClaimBatchStatus.validated.rawValue : BulkClaimBatchStatus.failed.rawValue
            }
            try modelContext.save()
        }
    }

    public func updateBatchLineReconciliation(
        batchId: UUID,
        submissionStatus: BulkClaimSubmissionStatus,
        submissionRef: String?,
        reconciliationNotes: String?,
        reconciledAt: Date?
    ) async throws -> Int {
        let normalizedSubmissionRef = submissionRef?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNotes = reconciliationNotes?.trimmingCharacters(in: .whitespacesAndNewlines)

        return try await MainActor.run {
            _ = try fetchBatchEntity(batchId)
            let predicate = #Predicate<BulkClaimLineEntity> { $0.batch?.id == batchId }
            let descriptor = FetchDescriptor<BulkClaimLineEntity>(predicate: predicate)
            let lines = try modelContext.fetch(descriptor)

            for line in lines {
                line.submissionStatus = submissionStatus.rawValue
                line.submissionRef = (normalizedSubmissionRef?.isEmpty == false) ? normalizedSubmissionRef : nil
                line.reconciliationNotes = (normalizedNotes?.isEmpty == false) ? normalizedNotes : nil
                line.reconciledAt = reconciledAt
            }

            if !lines.isEmpty {
                try modelContext.save()
            }
            return lines.count
        }
    }

    public func updateBatchStatus(id: UUID, status: BulkClaimBatchStatus, errorCount: Int) async throws {
        try await MainActor.run {
            let batch = try fetchBatchEntity(id)
            batch.status = status.rawValue
            batch.errorCount = Int32(errorCount)
            try modelContext.save()
        }
    }

    public func markExported(id: UUID, fileName: String, checksumSHA256: String, rowCount: Int) async throws {
        try await MainActor.run {
            let batch = try fetchBatchEntity(id)
            batch.status = BulkClaimBatchStatus.exported.rawValue
            batch.exportFileName = fileName
            batch.checksumSHA256 = checksumSHA256
            batch.exportedAt = Date()
            batch.rowCount = Int32(rowCount)
            try modelContext.save()
        }
    }

    public func deleteBatch(id: UUID) async throws {
        try await MainActor.run {
            let batch = try fetchBatchEntity(id)
            modelContext.delete(batch)
            try modelContext.save()
        }
    }

    private func fetchBatchEntity(_ id: UUID) throws -> BulkClaimBatchEntity {
        let predicate = #Predicate<BulkClaimBatchEntity> { $0.id == id }
        let descriptor = FetchDescriptor<BulkClaimBatchEntity>(predicate: predicate)
        guard let entity = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound(id: id)
        }
        return entity
    }

    private func fetchInvoiceEntity(_ id: UUID) throws -> InvoiceEntity {
        let predicate = #Predicate<InvoiceEntity> { $0.id == id }
        let descriptor = FetchDescriptor<InvoiceEntity>(predicate: predicate)
        guard let entity = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound(id: id)
        }
        return entity
    }

    private func fetchInvoiceItemEntity(_ id: UUID) throws -> InvoiceItemEntity {
        let predicate = #Predicate<InvoiceItemEntity> { $0.id == id }
        let descriptor = FetchDescriptor<InvoiceItemEntity>(predicate: predicate)
        guard let entity = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound(id: id)
        }
        return entity
    }
}
