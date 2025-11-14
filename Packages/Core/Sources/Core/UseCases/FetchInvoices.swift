import Foundation

/// Use case for fetching invoices
public struct FetchInvoices: Sendable {
    private let repository: InvoicesRepository
    
    public init(repository: InvoicesRepository) {
        self.repository = repository
    }
    
    /// Fetch all invoices
    public func callAsFunction() async throws -> [Invoice] {
        try await repository.fetchAll()
    }
    
    /// Fetch invoices by client ID
    public func callAsFunction(by clientId: UUID) async throws -> [Invoice] {
        try await repository.fetch(byClientId: clientId)
    }
    
    /// Fetch invoices by status
    public func callAsFunction(by status: String) async throws -> [Invoice] {
        try await repository.fetch(by: status)
    }
    
    /// Fetch invoices by billing status
    public func callAsFunction(by billingStatus: BillingStatus) async throws -> [Invoice] {
        try await repository.fetch(by: billingStatus)
    }
    
    /// Fetch a single invoice by ID
    public func callAsFunction(by id: UUID) async throws -> Invoice? {
        try await repository.fetch(by: id)
    }
    
    /// Fetch invoice by invoice number
    public func callAsFunction(by invoiceNumber: String) async throws -> Invoice? {
        try await repository.fetch(by: invoiceNumber)
    }
    
    /// Search invoices by query
    public func callAsFunction(search query: String) async throws -> [Invoice] {
        try await repository.search(query: query)
    }
    
    /// Fetch invoices with pagination
    public func callAsFunction(limit: Int, offset: Int) async throws -> [Invoice] {
        try await repository.fetch(limit: limit, offset: offset)
    }
}
