import Foundation

public protocol SupportLogRepository: Sendable {
    func fetch(by id: UUID) async throws -> SupportLog?
    func fetchBySession(_ sessionId: UUID) async throws -> [SupportLog]
    func fetchByClient(_ clientId: UUID, from: Date?, to: Date?) async throws -> [SupportLog]
    func create(_ log: SupportLog) async throws -> SupportLog
    func update(_ log: SupportLog) async throws -> SupportLog
    func delete(id: UUID) async throws
}

public typealias SupportLogRepositoryProtocol = SupportLogRepository
