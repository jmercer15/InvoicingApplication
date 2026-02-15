import Foundation
import Core
import os.log

/// A decorator that enforces data integrity rules for ClientsRepository operations.
public final class ClientsIntegrityDecorator: ClientsRepository, @unchecked Sendable {
    private let wrapped: any ClientsRepository
    private let logger: Logger
    
    public init(wrapped: any ClientsRepository, subsystem: String = "InvoicingApplication") {
        self.wrapped = wrapped
        self.logger = Logger(subsystem: subsystem, category: "ClientsRepository.Integrity")
    }
    
    // MARK: - Validation Helpers
    
    private func validateClient(_ client: Client) throws {
        // Ensure full name is not empty
        guard !client.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.error("Integrity Check Failed: Client \(client.id) has empty name")
            throw RepositoryError.validationFailed(message: "Client name cannot be empty")
        }
        
        // Ensure NDIS number is present (if required by business rule - assuming optional but if present must be valid format?)
        // For now just basic empty check if it's meant to be non-empty
        /* 
        if client.ndisNumber.isEmpty {
             logger.warning("Client \(client.fullName) has empty NDIS number")
        }
        */
    }
    
    // MARK: - ClientsRepository Protocol
    
    public func fetchAll() async throws -> [Client] {
        try await wrapped.fetchAll()
    }
    
    public func fetchActive() async throws -> [Client] {
        try await wrapped.fetchActive()
    }
    
    public func fetch(by id: UUID) async throws -> Client? {
        try await wrapped.fetch(by: id)
    }
    
    public func fetch(by ndisNumber: String) async throws -> Client? {
        try await wrapped.fetch(by: ndisNumber)
    }
    
    public func create(_ client: Client) async throws -> Client {
        try validateClient(client)
        return try await wrapped.create(client)
    }
    
    public func update(_ client: Client) async throws -> Client {
        try validateClient(client)
        return try await wrapped.update(client)
    }
    
    public func delete(id: UUID) async throws {
        try await wrapped.delete(id: id)
    }
    
    public func archive(id: UUID) async throws {
        try await wrapped.archive(id: id)
    }
    
    public func reactivate(id: UUID) async throws {
        try await wrapped.reactivate(id: id)
    }
    
    public func updateStatus(id: UUID, status: String) async throws {
        try await wrapped.updateStatus(id: id, status: status)
    }
    
    public func search(query: String) async throws -> [Client] {
        try await wrapped.search(query: query)
    }
    
    public func fetch(limit: Int, offset: Int) async throws -> [Client] {
        try await wrapped.fetch(limit: limit, offset: offset)
    }
    
    public func count() async throws -> Int {
        try await wrapped.count()
    }
    
    public func countActive() async throws -> Int {
        try await wrapped.countActive()
    }
    
    public func fetch(byPayeeId payeeId: UUID) async throws -> [Client] {
        try await wrapped.fetch(byPayeeId: payeeId)
    }
    
    public func fetch(byPlanManagerId planManagerId: UUID) async throws -> [Client] {
        try await wrapped.fetch(byPlanManagerId: planManagerId)
    }
}
