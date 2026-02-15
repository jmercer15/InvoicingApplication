import Foundation
import SwiftData
import Core

public final class ServiceAgreementRepositorySwiftData: ServiceAgreementRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    private let mapper: ServiceAgreementMapper

    public init(modelContext: ModelContext, mapper: ServiceAgreementMapper = ServiceAgreementMapper()) {
        self.modelContext = modelContext
        self.mapper = mapper
    }

    public func fetch(by id: UUID) async throws -> ServiceAgreement? {
        let predicate = #Predicate<ServiceAgreementEntity> { $0.id == id }
        let descriptor = FetchDescriptor<ServiceAgreementEntity>(predicate: predicate)
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return mapper.mapToDomain(entity)
        }
    }

    public func fetchByClient(_ clientId: UUID, includeArchived: Bool = false) async throws -> [ServiceAgreement] {
        let predicate = #Predicate<ServiceAgreementEntity> { agreement in
            agreement.client?.id == clientId
        }
        let descriptor = FetchDescriptor<ServiceAgreementEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.effectiveFrom, order: .reverse)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            let filtered = includeArchived ? entities : entities.filter { !$0.isArchived }
            return filtered.map { mapper.mapToDomain($0) }
        }
    }

    public func fetchActive(clientId: UUID, on date: Date) async throws -> ServiceAgreement? {
        let all = try await fetchByClient(clientId, includeArchived: false)
        return all.first(where: { agreement in
            agreement.effectiveFrom <= date &&
                (agreement.effectiveTo == nil || agreement.effectiveTo! >= date)
        })
    }

    public func create(_ agreement: ServiceAgreement) async throws -> ServiceAgreement {
        if try await hasOverlap(
            clientId: agreement.clientId,
            effectiveFrom: agreement.effectiveFrom,
            effectiveTo: agreement.effectiveTo,
            excluding: nil
        ) {
            throw RepositoryError.validationFailed(message: "Service agreement dates overlap with an existing agreement.")
        }

        return try await MainActor.run {
            var entity = mapper.mapToEntity(agreement)
            entity.client = try fetchClientEntity(agreement.clientId)
            modelContext.insert(entity)
            try modelContext.save()
            return mapper.mapToDomain(entity)
        }
    }

    public func update(_ agreement: ServiceAgreement) async throws -> ServiceAgreement {
        if try await hasOverlap(
            clientId: agreement.clientId,
            effectiveFrom: agreement.effectiveFrom,
            effectiveTo: agreement.effectiveTo,
            excluding: agreement.id
        ) {
            throw RepositoryError.validationFailed(message: "Service agreement dates overlap with an existing agreement.")
        }

        return try await MainActor.run {
            let predicate = #Predicate<ServiceAgreementEntity> { $0.id == agreement.id }
            let descriptor = FetchDescriptor<ServiceAgreementEntity>(predicate: predicate)
            guard var entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.notFound(id: agreement.id)
            }

            mapper.updateEntity(&entity, from: agreement)
            entity.client = try fetchClientEntity(agreement.clientId)
            try modelContext.save()
            return mapper.mapToDomain(entity)
        }
    }

    public func archive(id: UUID) async throws {
        try await MainActor.run {
            let predicate = #Predicate<ServiceAgreementEntity> { $0.id == id }
            let descriptor = FetchDescriptor<ServiceAgreementEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.notFound(id: id)
            }
            entity.isArchived = true
            try modelContext.save()
        }
    }

    public func delete(id: UUID) async throws {
        try await MainActor.run {
            let predicate = #Predicate<ServiceAgreementEntity> { $0.id == id }
            let descriptor = FetchDescriptor<ServiceAgreementEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.notFound(id: id)
            }
            modelContext.delete(entity)
            try modelContext.save()
        }
    }

    public func hasOverlap(
        clientId: UUID,
        effectiveFrom: Date,
        effectiveTo: Date?,
        excluding agreementId: UUID?
    ) async throws -> Bool {
        let agreements = try await fetchByClient(clientId, includeArchived: false)
            .filter { agreement in
                guard let agreementId else { return true }
                return agreement.id != agreementId
            }

        let end = effectiveTo ?? .distantFuture
        return agreements.contains { agreement in
            let existingStart = agreement.effectiveFrom
            let existingEnd = agreement.effectiveTo ?? .distantFuture
            return effectiveFrom <= existingEnd && existingStart <= end
        }
    }

    private func fetchClientEntity(_ id: UUID) throws -> ClientEntity {
        let predicate = #Predicate<ClientEntity> { $0.id == id }
        let descriptor = FetchDescriptor<ClientEntity>(predicate: predicate)
        guard let client = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound(id: id)
        }
        return client
    }
}
