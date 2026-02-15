import Foundation

public protocol ServiceAgreementRepository: Sendable {
    func fetch(by id: UUID) async throws -> ServiceAgreement?
    func fetchByClient(_ clientId: UUID, includeArchived: Bool) async throws -> [ServiceAgreement]
    func fetchActive(clientId: UUID, on date: Date) async throws -> ServiceAgreement?
    func create(_ agreement: ServiceAgreement) async throws -> ServiceAgreement
    func update(_ agreement: ServiceAgreement) async throws -> ServiceAgreement
    func archive(id: UUID) async throws
    func delete(id: UUID) async throws
    func hasOverlap(
        clientId: UUID,
        effectiveFrom: Date,
        effectiveTo: Date?,
        excluding agreementId: UUID?
    ) async throws -> Bool
}

public typealias ServiceAgreementRepositoryProtocol = ServiceAgreementRepository
