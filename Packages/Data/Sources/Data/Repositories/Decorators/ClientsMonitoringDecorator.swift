import Foundation
import Core
import os.log

/// A protocol-based decorator that wraps ClientsRepository to add performance monitoring.
public final class ClientsMonitoringDecorator: ClientsRepository, @unchecked Sendable {
    private let wrapped: any ClientsRepository
    private let logger: Logger
    
    public init(wrapped: any ClientsRepository, subsystem: String = "InvoicingApplication") {
        self.wrapped = wrapped
        self.logger = Logger(subsystem: subsystem, category: "ClientsRepository.Performance")
    }
    
    private func measure<T>(_ operation: String, _ block: () async throws -> T) async rethrows -> T {
        let start = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = (CFAbsoluteTimeGetCurrent() - start) * 1000
            logger.info("[\(operation)] completed in \(duration, format: .fixed(precision: 2))ms")
        }
        return try await block()
    }
    
    // MARK: - ClientsRepository Protocol
    
    public func fetchAll() async throws -> [Client] {
        try await measure("fetchAll") { try await wrapped.fetchAll() }
    }
    
    public func fetchActive() async throws -> [Client] {
        try await measure("fetchActive") { try await wrapped.fetchActive() }
    }
    
    public func fetch(by id: UUID) async throws -> Client? {
        try await measure("fetch(byId)") { try await wrapped.fetch(by: id) }
    }
    
    public func fetch(by ndisNumber: String) async throws -> Client? {
        try await measure("fetch(byNDIS)") { try await wrapped.fetch(by: ndisNumber) }
    }
    
    public func create(_ client: Client) async throws -> Client {
        try await measure("create") { try await wrapped.create(client) }
    }
    
    public func update(_ client: Client) async throws -> Client {
        try await measure("update") { try await wrapped.update(client) }
    }
    
    public func delete(id: UUID) async throws {
        try await measure("delete") { try await wrapped.delete(id: id) }
    }
    
    public func archive(id: UUID) async throws {
        try await measure("archive") { try await wrapped.archive(id: id) }
    }
    
    public func reactivate(id: UUID) async throws {
        try await measure("reactivate") { try await wrapped.reactivate(id: id) }
    }
    
    public func updateStatus(id: UUID, status: String) async throws {
        try await measure("updateStatus") { try await wrapped.updateStatus(id: id, status: status) }
    }
    
    public func search(query: String) async throws -> [Client] {
        try await measure("search") { try await wrapped.search(query: query) }
    }
    
    public func fetch(limit: Int, offset: Int) async throws -> [Client] {
        try await measure("fetch(paginated)") { try await wrapped.fetch(limit: limit, offset: offset) }
    }
    
    public func count() async throws -> Int {
        try await measure("count") { try await wrapped.count() }
    }
    
    public func countActive() async throws -> Int {
        try await measure("countActive") { try await wrapped.countActive() }
    }
    
    public func fetch(byPayeeId payeeId: UUID) async throws -> [Client] {
        try await measure("fetch(byPayeeId)") { try await wrapped.fetch(byPayeeId: payeeId) }
    }
    
    public func fetch(byPlanManagerId planManagerId: UUID) async throws -> [Client] {
        try await measure("fetch(byPlanManagerId)") { try await wrapped.fetch(byPlanManagerId: planManagerId) }
    }
}
