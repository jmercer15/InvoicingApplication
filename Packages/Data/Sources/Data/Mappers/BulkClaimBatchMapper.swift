import Foundation
import Core

public struct BulkClaimBatchMapper: ModelMapper {
    public typealias DomainModel = BulkClaimBatch
    public typealias PersistenceEntity = BulkClaimBatchEntity

    public init() {}

    public func mapToDomain(_ entity: BulkClaimBatchEntity) -> BulkClaimBatch {
        BulkClaimBatch(
            id: entity.id,
            createdAt: entity.createdAt,
            fromDate: entity.fromDate,
            toDate: entity.toDate,
            status: entity.status,
            includeTravel: entity.includeTravel,
            includeCancellations: entity.includeCancellations,
            claimReferenceStrategy: entity.claimReferenceStrategy,
            exportFileName: entity.exportFileName,
            exportedAt: entity.exportedAt,
            rowCount: Int(entity.rowCount),
            errorCount: Int(entity.errorCount),
            checksumSHA256: entity.checksumSHA256,
            notes: entity.notes
        )
    }

    public func mapToEntity(_ domain: BulkClaimBatch) -> BulkClaimBatchEntity {
        let entity = BulkClaimBatchEntity(id: domain.id)
        updateEntityProperties(entity, from: domain)
        return entity
    }

    public func updateEntity(_ entity: inout BulkClaimBatchEntity, from domain: BulkClaimBatch) {
        updateEntityProperties(entity, from: domain)
    }

    private func updateEntityProperties(_ entity: BulkClaimBatchEntity, from domain: BulkClaimBatch) {
        entity.createdAt = domain.createdAt
        entity.fromDate = domain.fromDate
        entity.toDate = domain.toDate
        entity.status = domain.status
        entity.includeTravel = domain.includeTravel
        entity.includeCancellations = domain.includeCancellations
        entity.claimReferenceStrategy = domain.claimReferenceStrategy
        entity.exportFileName = domain.exportFileName
        entity.exportedAt = domain.exportedAt
        entity.rowCount = Int32(domain.rowCount)
        entity.errorCount = Int32(domain.errorCount)
        entity.checksumSHA256 = domain.checksumSHA256
        entity.notes = domain.notes
    }
}
