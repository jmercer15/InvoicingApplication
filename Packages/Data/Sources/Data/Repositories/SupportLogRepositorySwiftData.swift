import Foundation
import SwiftData
import Core

public final class SupportLogRepositorySwiftData: SupportLogRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    private let mapper: SupportLogMapper

    public init(modelContext: ModelContext, mapper: SupportLogMapper = SupportLogMapper()) {
        self.modelContext = modelContext
        self.mapper = mapper
    }

    public func fetch(by id: UUID) async throws -> SupportLog? {
        let predicate = #Predicate<SupportLogEntity> { $0.id == id }
        let descriptor = FetchDescriptor<SupportLogEntity>(predicate: predicate)
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return mapper.mapToDomain(entity)
        }
    }

    public func fetchBySession(_ sessionId: UUID) async throws -> [SupportLog] {
        let predicate = #Predicate<SupportLogEntity> { $0.session?.id == sessionId }
        let descriptor = FetchDescriptor<SupportLogEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.deliveredFrom, order: .reverse)]
        )
        return try await MainActor.run {
            try modelContext.fetch(descriptor).map { mapper.mapToDomain($0) }
        }
    }

    public func fetchByClient(_ clientId: UUID, from: Date?, to: Date?) async throws -> [SupportLog] {
        let predicate = #Predicate<SupportLogEntity> { $0.client?.id == clientId }
        let descriptor = FetchDescriptor<SupportLogEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.deliveredFrom, order: .reverse)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            let filtered = entities.filter { entity in
                let lowerOK = from.map { entity.deliveredFrom >= $0 } ?? true
                let upperOK = to.map { entity.deliveredTo <= $0 } ?? true
                return lowerOK && upperOK
            }
            return filtered.map { mapper.mapToDomain($0) }
        }
    }

    public func create(_ log: SupportLog) async throws -> SupportLog {
        try validate(log)
        return try await MainActor.run {
            var entity = mapper.mapToEntity(log)
            entity.client = try fetchClientEntity(log.clientId)
            if let sessionId = log.sessionId {
                entity.session = try fetchSessionEntity(sessionId)
            }
            modelContext.insert(entity)
            try modelContext.save()
            return mapper.mapToDomain(entity)
        }
    }

    public func update(_ log: SupportLog) async throws -> SupportLog {
        try validate(log)
        return try await MainActor.run {
            let predicate = #Predicate<SupportLogEntity> { $0.id == log.id }
            let descriptor = FetchDescriptor<SupportLogEntity>(predicate: predicate)
            guard var entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.notFound(id: log.id)
            }
            mapper.updateEntity(&entity, from: log)
            entity.client = try fetchClientEntity(log.clientId)
            if let sessionId = log.sessionId {
                entity.session = try fetchSessionEntity(sessionId)
            } else {
                entity.session = nil
            }
            try modelContext.save()
            return mapper.mapToDomain(entity)
        }
    }

    public func delete(id: UUID) async throws {
        try await MainActor.run {
            let predicate = #Predicate<SupportLogEntity> { $0.id == id }
            let descriptor = FetchDescriptor<SupportLogEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.notFound(id: id)
            }
            modelContext.delete(entity)
            try modelContext.save()
        }
    }

    private func validate(_ log: SupportLog) throws {
        let requiredFields: [(String, String)] = [
            ("participantName", log.participantName),
            ("participantNdisNumber", log.participantNdisNumber),
            ("supportItemNumber", log.supportItemNumber),
            ("serviceDescription", log.serviceDescription),
            ("location", log.location),
            ("deliveredBy", log.deliveredBy),
            ("attestedBy", log.attestedBy)
        ]

        if requiredFields.contains(where: { $0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            throw RepositoryError.validationFailed(message: "Support log required fields are missing.")
        }

        if log.deliveredTo < log.deliveredFrom {
            throw RepositoryError.validationFailed(message: "Support log end time cannot be before start time.")
        }
        if log.quantityHours <= 0 {
            throw RepositoryError.validationFailed(message: "Support log quantity must be greater than zero.")
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

    private func fetchSessionEntity(_ id: UUID) throws -> SessionEntity {
        let predicate = #Predicate<SessionEntity> { $0.id == id }
        let descriptor = FetchDescriptor<SessionEntity>(predicate: predicate)
        guard let session = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound(id: id)
        }
        return session
    }
}
